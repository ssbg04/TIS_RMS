'use strict';

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const dns = require('dns');
const https = require('https');

// ─── State ─────────────────────────────────────────────────────────────────
let tunnelProcess      = null;
let isStarting         = false;
let monitorTimer       = null;
let signalHandlersSet  = false;

let lastInternetCheck        = false;
let lastCheckedTime          = null;
let lastLogMessage           = '';
let tunnelState              = 'stopped'; // 'stopped'|'starting'|'connected'|'error'|'no_internet'|'disabled'
let consecutiveInternetFails = 0;
let detectedTunnelHostname   = null;

// Backoff config
const BACKOFF_MIN_MS = 5_000;   // 5 s initial wait after a crash
const BACKOFF_MAX_MS = 120_000; // 2 min cap
let   crashCount     = 0;
let   restartTimer   = null;

/**
 * Finds the cloudflared executable path.
 */
function getCloudflaredPath() {
    const isWindows = process.platform === 'win32';

    const setExecutable = (filePath) => {
        if (!isWindows) {
            try { fs.chmodSync(filePath, 0o755); } catch (_) {}
        }
    };

    if (process.env.CLOUDFLARED_PATH && fs.existsSync(process.env.CLOUDFLARED_PATH)) {
        setExecutable(process.env.CLOUDFLARED_PATH);
        return process.env.CLOUDFLARED_PATH;
    }

    const binaryName = isWindows ? 'cloudflared.exe' : 'cloudflared';

    const candidatePaths = [
        path.join(__dirname, '..', '..', 'bin', binaryName),
        path.join(__dirname, '..', 'bin', binaryName),
        path.join(process.cwd(), 'bin', binaryName),
        path.join(process.cwd(), '..', 'bin', binaryName),
        path.join(__dirname, '..', '..', '..', 'bin', binaryName),
    ];

    for (const cand of candidatePaths) {
        if (fs.existsSync(cand)) {
            setExecutable(cand);
            return path.resolve(cand);
        }
    }

    return null;
}

/** Robust internet check — parallel DNS + HTTPS fallback, resolves on first success. */
function checkInternet(timeoutMs = 6000) {
    return new Promise((resolve) => {
        let resolved = false;
        const done = (val) => {
            if (!resolved) {
                resolved = true;
                clearTimeout(globalTimer);
                resolve(val);
            }
        };
        const globalTimer = setTimeout(() => done(false), timeoutMs);
        // Parallel DNS lookups
        dns.lookup('cloudflare.com',  (e) => { if (!e) done(true); });
        dns.lookup('8.8.8.8',         (e) => { if (!e) done(true); });
        dns.lookup('one.one.one.one',  (e) => { if (!e) done(true); });
        // HTTPS fallback
        try {
            const req = https.get('https://1.1.1.1', { timeout: 4000 }, (res) => { res.destroy(); done(true); });
            req.on('error', () => {});
            req.on('timeout', () => { req.destroy(); });
        } catch (_) {}
    });
}

/** Returns exponential backoff delay for the next restart attempt. */
function getBackoffMs() {
    return Math.min(BACKOFF_MIN_MS * Math.pow(2, Math.max(0, crashCount - 1)), BACKOFF_MAX_MS);
}

/**
 * Schedules the next startTunnel() call with exponential backoff.
 * Safe to call multiple times — only one pending restart is ever queued.
 */
function scheduleRestart() {
    if (restartTimer) return;
    const isEnabled = process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false';
    if (!isEnabled) return;

    const delay = getBackoffMs();
    console.log(`[Tunnel] Will retry in ${(delay / 1000).toFixed(0)} s (crash #${crashCount})...`);
    restartTimer = setTimeout(async () => {
        restartTimer = null;
        if (tunnelState === 'disabled' || tunnelState === 'no_internet') return;
        if (tunnelProcess || isStarting) return;
        const hasInternet = await checkInternet();
        if (hasInternet) {
            await startTunnel();
        } else {
            console.warn('[Tunnel] No internet at restart time — will retry on next monitor tick');
            tunnelState = 'no_internet';
        }
    }, delay);
}

/**
 * Launches the cloudflared child process with crash detection and supervised restart.
 */
async function startTunnel() {
    if (tunnelProcess || isStarting) return;
    isStarting = true;

    const binPath = getCloudflaredPath();
    if (!binPath) {
        tunnelState = 'error';
        lastLogMessage = 'cloudflared binary not found in bin directory or PATH';
        console.warn(`[Tunnel] ${lastLogMessage}`);
        isStarting = false;
        return;
    }

    const DEFAULT_TOKEN = 'eyJhIjoiZWRhMWQ4ZTc1MzNjMjBiMDcyNmM0ZGU1OWE5YTMxYzgiLCJ0IjoiZjJhOGYyYmMtMWE1YS00MmNmLWJjZTUtZWMzYzAxNzY4M2IyIiwicyI6Ik5EbGtOMkZpTldNdFpEYzVNUzAwTUdFMUxXSTFNalV0WW1RNVl6VXlaV1EzTVRWaiJ9';
    const rawToken = process.env.CLOUDFLARE_TUNNEL_TOKEN || DEFAULT_TOKEN;
    const token    = rawToken.replace(/[\r\n\s'"=]/g, '').trim();

    const args = token
        ? ['tunnel', '--no-autoupdate', 'run', '--token', token]
        : ['tunnel', '--no-autoupdate', '--url', `http://localhost:${process.env.PORT || 18484}`];

    console.log(`[Tunnel] Launching cloudflared (crash #${crashCount})...`);
    tunnelState = 'starting';
    const startedAt = Date.now();

    try {
        const proc = spawn(binPath, args, {
            windowsHide: true,
            stdio: ['ignore', 'pipe', 'pipe'],
            env: { ...process.env, NO_AUTOUPDATE: 'true' }
        });
        tunnelProcess = proc;
        isStarting    = false;
        console.log(`[Tunnel] Process started (PID: ${proc.pid})`);

        const handleLog = (data) => {
            for (const line of data.toString().split('\n')) {
                const t = line.trim();
                if (!t) continue;
                lastLogMessage = t;
                const hostMatch = t.match(/"hostname":\s*"([^"]+)"/);
                if (hostMatch?.[1]) detectedTunnelHostname = hostMatch[1];

                const isConn =
                    t.includes('Registered tunnel connection') ||
                    (t.includes('Connection') && t.includes('registered')) ||
                    t.includes('Tunnel connection curve preferences') ||
                    t.includes('protocol=quic') ||
                    t.includes('protocol=http2');

                if (isConn && tunnelState !== 'connected') {
                    tunnelState = 'connected';
                    crashCount  = 0;  // healthy → reset backoff
                    console.log('[Tunnel] ✔ Connected to Cloudflare edge network.');
                }
                if (t.includes('Invalid token') || t.includes('failed to authenticate')) {
                    console.error('[Tunnel] ✖ Auth failure — check CLOUDFLARE_TUNNEL_TOKEN');
                    tunnelState = 'error';
                }
            }
        };
        proc.stdout.on('data', handleLog);
        proc.stderr.on('data', handleLog);

        proc.on('error', (err) => {
            console.error('[Tunnel] Process error:', err.message);
            tunnelState   = 'error';
            lastLogMessage = err.message;
            if (tunnelProcess === proc) tunnelProcess = null;
            isStarting    = false;
            crashCount++;
            scheduleRestart();
        });

        proc.on('exit', (code, signal) => {
            console.log(`[Tunnel] Process exited (Code: ${code}, Signal: ${signal})`);
            if (tunnelProcess === proc) tunnelProcess = null;
            isStarting = false;

            // Detect crash: process lived < 30 s
            const uptimeMs = Date.now() - startedAt;
            if (uptimeMs < 30_000) {
                crashCount++;
                console.warn(`[Tunnel] Crash detected (uptime ${(uptimeMs / 1000).toFixed(1)} s, crash #${crashCount})`);
            } else {
                crashCount = 0;  // lived long enough → reset
            }

            if (tunnelState === 'disabled' || tunnelState === 'no_internet') return;
            tunnelState = 'stopped';
            scheduleRestart();
        });

        // Infer connected if still alive after 5 s with no explicit log confirmation
        setTimeout(() => {
            if (tunnelProcess === proc && tunnelState === 'starting') {
                tunnelState = 'connected';
                crashCount  = 0;
                console.log('[Tunnel] ✔ Connected (inferred — process alive after 5 s).');
            }
        }, 5000);

    } catch (err) {
        console.error('[Tunnel] Failed to spawn process:', err.message);
        tunnelState   = 'error';
        lastLogMessage = err.message;
        tunnelProcess = null;
        isStarting    = false;
        crashCount++;
        scheduleRestart();
    }
}

/** Kills the cloudflared child process cleanly and clears any pending restart timer. */
function stopTunnel() {
    if (restartTimer) { clearTimeout(restartTimer); restartTimer = null; }
    if (!tunnelProcess) return;
    const proc = tunnelProcess;
    tunnelProcess = null;
    tunnelState   = 'stopped';
    try {
        console.log(`[Tunnel] Stopping tunnel process (PID: ${proc.pid})...`);
        if (process.platform === 'win32') {
            const killer = spawn('taskkill', ['/pid', String(proc.pid), '/T', '/F'], {
                windowsHide: true, stdio: 'ignore'
            });
            killer.on('error', () => { try { proc.kill('SIGTERM'); } catch (_) {} });
        } else {
            proc.kill('SIGTERM');
        }
    } catch (err) {
        console.warn('[Tunnel] Error stopping tunnel:', err.message);
    }
}

/** Internet watchdog — restarts tunnel if net comes back, suspends after persistent outage. */
async function checkAndMaintainTunnel() {
    const isEnabled = process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false';
    if (!isEnabled) {
        if (tunnelProcess) stopTunnel();
        tunnelState = 'disabled';
        return;
    }

    const hasInternet = await checkInternet(6000);
    lastInternetCheck = hasInternet;
    lastCheckedTime   = new Date().toISOString();

    if (hasInternet) {
        consecutiveInternetFails = 0;
        // Only start if nothing is running or pending
        if (!tunnelProcess && !isStarting && !restartTimer) {
            if (tunnelState === 'no_internet') crashCount = 0; // reset backoff after net recovery
            console.log('[Tunnel] Internet available — starting tunnel...');
            await startTunnel();
        }
    } else {
        consecutiveInternetFails++;
        console.warn(`[Tunnel] Internet check failed (${consecutiveInternetFails}/3)`);
        if (consecutiveInternetFails >= 3 && tunnelProcess) {
            console.warn('[Tunnel] Persistent internet loss — suspending tunnel');
            tunnelState = 'no_internet';
            stopTunnel();
        }
    }
}

/** Initializes the supervised tunnel service on server startup. */
function startAutoTunnel() {
    const isEnabled = process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false';
    if (!isEnabled) {
        console.log('[Tunnel] Auto tunnel disabled (CLOUDFLARE_TUNNEL_ENABLED=false)');
        tunnelState = 'disabled';
        return;
    }

    console.log('[Tunnel] Initializing supervised Cloudflare Tunnel service...');
    checkAndMaintainTunnel();

    const intervalMs = parseInt(process.env.CLOUDFLARE_TUNNEL_CHECK_INTERVAL, 10) || 30_000;
    if (monitorTimer) clearInterval(monitorTimer);
    monitorTimer = setInterval(checkAndMaintainTunnel, intervalMs);

    // Register signal handlers exactly once to avoid duplicate-listener warnings
    if (!signalHandlersSet) {
        signalHandlersSet = true;
        const cleanExit = () => {
            if (monitorTimer)  { clearInterval(monitorTimer); monitorTimer = null; }
            if (restartTimer)  { clearTimeout(restartTimer);  restartTimer = null; }
            stopTunnel();
        };
        process.on('exit',       cleanExit);
        process.on('SIGINT',  () => { cleanExit(); process.exit(0); });
        process.on('SIGTERM', () => { cleanExit(); process.exit(0); });
        process.on('beforeExit',  cleanExit);
    }
}

/** Returns current tunnel status including crash diagnostics. */
function getTunnelStatus() {
    const binPath = getCloudflaredPath();
    return {
        enabled:        process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false',
        hasExecutable:  !!binPath,
        executablePath: binPath,
        hasInternet:    lastInternetCheck,
        isRunning:      !!tunnelProcess,
        pid:            tunnelProcess ? tunnelProcess.pid : null,
        status:         tunnelState,
        hostname:       detectedTunnelHostname,
        publicUrl:      detectedTunnelHostname ? `https://${detectedTunnelHostname}` : null,
        lastChecked:    lastCheckedTime,
        lastLog:        lastLogMessage,
        crashCount,
        nextRetryMs:    restartTimer ? getBackoffMs() : null,
    };
}

/**
 * Returns detected public tunnel URL (if active and discovered)
 */
function getDetectedTunnelUrl() {
    if (tunnelState === 'connected' && detectedTunnelHostname) {
        return `https://${detectedTunnelHostname}`;
    }
    return null;
}

module.exports = {
    startAutoTunnel,
    startTunnel,
    stopTunnel,
    getTunnelStatus,
    getDetectedTunnelUrl,
    checkInternet,
    getCloudflaredPath
};

