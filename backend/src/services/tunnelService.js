'use strict';

const { spawn, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const dns = require('dns');
const https = require('https');

// ─── Constants ────────────────────────────────────────────────────────────────
const INTERNET_TIMEOUT_MS        = 5_000;
const INTERNET_CHECK_INTERVAL_MS = 15_000;
const INFERRED_CONNECT_MS        = 5_000;

// ─── Service State ────────────────────────────────────────────────────────────
let tunnelProcess            = null;
let isStarting               = false;
let tunnelState              = 'stopped'; // 'stopped' | 'starting' | 'connected' | 'error' | 'no_internet' | 'disabled'
let detectedTunnelHostname   = null;
let lastInternetCheck        = false;
let lastLogMessage           = '';
let internetTimer            = null;
let inferredConnectTimer     = null;
let signalHandlersRegistered = false;

/**
 * Extracts a hostname from a URL string if valid.
 * @param {string} urlStr
 * @returns {string|null}
 */
function extractHostname(urlStr) {
    if (!urlStr || typeof urlStr !== 'string') return null;
    try {
        const parsed = new URL(urlStr.startsWith('http') ? urlStr : `https://${urlStr}`);
        return parsed.hostname || null;
    } catch (_) {
        return null;
    }
}

/**
 * Returns the effective tunnel hostname (detected from logs, or configured via env).
 * @returns {string|null}
 */
function getEffectiveHostname() {
    if (detectedTunnelHostname) return detectedTunnelHostname;
    if (process.env.CLOUDFLARE_TUNNEL_HOSTNAME) {
        return process.env.CLOUDFLARE_TUNNEL_HOSTNAME.trim();
    }
    const envPublicUrl = process.env.PUBLIC_URL || process.env.APP_URL || process.env.CLOUDFLARE_TUNNEL_PUBLIC_URL;
    if (envPublicUrl) {
        return extractHostname(envPublicUrl);
    }
    return null;
}

/**
 * Finds the cloudflared executable path across common workspace and system locations.
 * @returns {string|null}
 */
function getCloudflaredPath() {
    const isWindows = process.platform === 'win32';
    const binaryName = isWindows ? 'cloudflared.exe' : 'cloudflared';

    const setExecutablePermission = (filePath) => {
        if (!isWindows) {
            try { fs.chmodSync(filePath, 0o755); } catch (_) {}
        }
    };

    if (process.env.CLOUDFLARED_PATH && fs.existsSync(process.env.CLOUDFLARED_PATH)) {
        setExecutablePermission(process.env.CLOUDFLARED_PATH);
        return process.env.CLOUDFLARED_PATH;
    }

    const candidatePaths = [
        path.join(__dirname, '..', '..', 'bin', binaryName),
        path.join(__dirname, '..', 'bin', binaryName),
        path.join(process.cwd(), 'bin', binaryName),
        path.join(process.cwd(), '..', 'bin', binaryName),
        path.join(__dirname, '..', '..', '..', 'bin', binaryName),
    ];

    for (const cand of candidatePaths) {
        if (fs.existsSync(cand)) {
            setExecutablePermission(cand);
            return path.resolve(cand);
        }
    }

    return null;
}

/**
 * Checks whether an internet connection is available.
 * @param {number} timeoutMs
 * @returns {Promise<boolean>}
 */
function checkInternet(timeoutMs = INTERNET_TIMEOUT_MS) {
    return new Promise((resolve) => {
        let isDone = false;
        let activeHttpsReq = null;

        const finish = (result) => {
            if (!isDone) {
                isDone = true;
                clearTimeout(timeoutId);
                if (activeHttpsReq && !activeHttpsReq.destroyed) {
                    try { activeHttpsReq.destroy(); } catch (_) {}
                }
                resolve(result);
            }
        };

        const timeoutId = setTimeout(() => finish(false), timeoutMs);

        // Parallel DNS hostname checks
        const domains = ['cloudflare.com', 'one.one.one.one', 'google.com', 'dns.google'];
        domains.forEach((domain) => {
            dns.lookup(domain, (err) => {
                if (!err) finish(true);
            });
        });

        // Fast HTTPS fallback
        try {
            activeHttpsReq = https.get('https://1.1.1.1', { timeout: 3000 }, (res) => {
                res.destroy();
                finish(true);
            });
            activeHttpsReq.on('error', () => {});
            activeHttpsReq.on('timeout', () => {
                try { activeHttpsReq.destroy(); } catch (_) {}
            });
        } catch (_) {}
    });
}

/**
 * Parses cloudflared log lines to update connection status and extract hostnames.
 * @param {string} rawChunk
 */
function handleProcessOutput(rawChunk) {
    const lines = rawChunk.toString().split(/\r?\n/);
    for (const line of lines) {
        const text = line.trim();
        if (!text) continue;

        lastLogMessage = text;

        // 1. Hostname detection from JSON logs or plaintext output
        const jsonHostMatch = text.match(/"hostname":\s*"([^"]+)"/);
        if (jsonHostMatch?.[1]) {
            detectedTunnelHostname = jsonHostMatch[1];
        } else {
            const urlMatch = text.match(/https:\/\/([a-zA-Z0-9-]+\.(?:trycloudflare\.com|cfargotunnel\.com))/);
            if (urlMatch?.[1]) {
                detectedTunnelHostname = urlMatch[1];
            }
        }

        // 2. Connection confirmation detection
        const isConnectedLog =
            text.includes('Registered tunnel connection') ||
            (text.includes('Connection') && text.includes('registered')) ||
            text.includes('Tunnel connection curve preferences') ||
            text.includes('protocol=quic') ||
            text.includes('protocol=http2');

        if (isConnectedLog && tunnelState !== 'connected') {
            tunnelState = 'connected';
            console.log('[Tunnel] ✔ Connected to Cloudflare edge network.');
        }

        // 3. Auth error detection
        if (text.includes('Invalid token') || text.includes('failed to authenticate')) {
            console.error('[Tunnel] ✖ Cloudflare authentication failed. Verify CLOUDFLARE_TUNNEL_TOKEN.');
            tunnelState = 'error';
        }
    }
}

/**
 * Launches cloudflared using only the configured tunnel token.
 */
async function startTunnel() {
    if (tunnelProcess || isStarting) return;
    isStarting = true;

    const binPath = getCloudflaredPath();
    if (!binPath) {
        tunnelState = 'error';
        lastLogMessage = 'cloudflared executable not found in bin/ or PATH';
        console.warn(`[Tunnel] ${lastLogMessage}`);
        isStarting = false;
        return;
    }

    const rawToken = process.env.CLOUDFLARE_TUNNEL_TOKEN || '';
    const token = rawToken.replace(/[\r\n\s'"=]/g, '').trim();

    if (!token) {
        tunnelState = 'error';
        lastLogMessage = 'CLOUDFLARE_TUNNEL_TOKEN is required but not configured.';
        console.warn(`[Tunnel] ${lastLogMessage}`);
        isStarting = false;
        return;
    }

    const args = ['tunnel', '--no-autoupdate', 'run', '--token', token];

    console.log('[Tunnel] Launching Cloudflare Tunnel with configured token...');
    tunnelState = 'starting';

    try {
        const proc = spawn(binPath, args, {
            windowsHide: true,
            stdio: ['ignore', 'pipe', 'pipe'],
            env: { ...process.env, NO_AUTOUPDATE: 'true' }
        });

        tunnelProcess = proc;
        isStarting = false;
        console.log(`[Tunnel] Process started (PID: ${proc.pid})`);

        proc.stdout.on('data', handleProcessOutput);
        proc.stderr.on('data', handleProcessOutput);

        proc.on('error', (err) => {
            console.error('[Tunnel] Process error:', err.message);
            tunnelState = 'error';
            lastLogMessage = err.message;
            if (tunnelProcess === proc) tunnelProcess = null;
            isStarting = false;
        });

        proc.on('exit', (code, signal) => {
            console.log(`[Tunnel] Process exited (Code: ${code}, Signal: ${signal})`);
            if (tunnelProcess === proc) tunnelProcess = null;
            isStarting = false;
            if (inferredConnectTimer) {
                clearTimeout(inferredConnectTimer);
                inferredConnectTimer = null;
            }
            if (tunnelState !== 'disabled') {
                tunnelState = 'stopped';
            }
        });

        // Infer connected state if process remains active
        if (inferredConnectTimer) clearTimeout(inferredConnectTimer);
        inferredConnectTimer = setTimeout(() => {
            if (tunnelProcess === proc && tunnelState === 'starting') {
                tunnelState = 'connected';
                console.log('[Tunnel] ✔ Connected (inferred: process healthy).');
            }
        }, INFERRED_CONNECT_MS);

    } catch (err) {
        console.error('[Tunnel] Failed to spawn cloudflared:', err.message);
        tunnelState = 'error';
        lastLogMessage = err.message;
        tunnelProcess = null;
        isStarting = false;
    }
}

/**
 * Stops the cloudflared process cleanly.
 */
function stopTunnel() {
    if (inferredConnectTimer) {
        clearTimeout(inferredConnectTimer);
        inferredConnectTimer = null;
    }
    if (!tunnelProcess) return;

    const proc = tunnelProcess;
    tunnelProcess = null;
    tunnelState = 'stopped';

    try {
        console.log(`[Tunnel] Stopping tunnel process (PID: ${proc.pid})...`);
        if (process.platform === 'win32') {
            spawnSync('taskkill', ['/pid', String(proc.pid), '/T', '/F'], {
                windowsHide: true,
                stdio: 'ignore'
            });
        } else {
            proc.kill('SIGTERM');
        }
    } catch (err) {
        console.warn('[Tunnel] Error while stopping process:', err.message);
    }
}

/**
 * Checks internet connection and auto-starts the tunnel when available.
 */
async function checkAndAutoStart() {
    const isEnabled = process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false';
    if (!isEnabled) {
        if (tunnelProcess) stopTunnel();
        tunnelState = 'disabled';
        return;
    }

    // If tunnel is already running or launching, do nothing
    if (tunnelProcess || isStarting) return;

    const hasInternet = await checkInternet();
    lastInternetCheck = hasInternet;

    if (hasInternet) {
        console.log('[Tunnel] Internet available — starting Cloudflare Tunnel...');
        await startTunnel();
    } else {
        if (tunnelState !== 'no_internet') {
            console.log('[Tunnel] No internet connection — waiting for internet to start tunnel...');
            tunnelState = 'no_internet';
        }
    }
}

/**
 * Initializes the tunnel on server startup with internet-aware auto start.
 */
function startAutoTunnel() {
    const isEnabled = process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false';
    if (!isEnabled) {
        console.log('[Tunnel] Cloudflare Tunnel is disabled (CLOUDFLARE_TUNNEL_ENABLED=false)');
        tunnelState = 'disabled';
        return;
    }

    console.log('[Tunnel] Initializing Cloudflare Tunnel service (auto-start on internet availability)...');
    checkAndAutoStart();

    // Check periodically so if the server started offline, it automatically starts once internet is up
    if (internetTimer) clearInterval(internetTimer);
    internetTimer = setInterval(checkAndAutoStart, INTERNET_CHECK_INTERVAL_MS);

    if (!signalHandlersRegistered) {
        signalHandlersRegistered = true;
        const cleanExit = () => {
            if (internetTimer) {
                clearInterval(internetTimer);
                internetTimer = null;
            }
            stopTunnel();
        };

        process.on('exit', cleanExit);
        process.on('SIGINT', () => { cleanExit(); process.exit(0); });
        process.on('SIGTERM', () => { cleanExit(); process.exit(0); });
        process.on('SIGUSR2', () => { cleanExit(); process.kill(process.pid, 'SIGUSR2'); });
        process.on('beforeExit', cleanExit);
    }
}

/**
 * Returns current tunnel status and diagnostics.
 * @returns {object}
 */
function getTunnelStatus() {
    const binPath = getCloudflaredPath();
    const hostname = getEffectiveHostname();
    const token = (process.env.CLOUDFLARE_TUNNEL_TOKEN || '').trim();

    return {
        enabled:        process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false',
        hasExecutable:  !!binPath,
        executablePath: binPath,
        hasToken:       !!token,
        hasInternet:    lastInternetCheck,
        isRunning:      !!tunnelProcess,
        pid:            tunnelProcess ? tunnelProcess.pid : null,
        status:         tunnelState,
        hostname:       hostname,
        publicUrl:      hostname ? `https://${hostname}` : null,
        lastLog:        lastLogMessage,
    };
}

/**
 * Returns detected public tunnel URL (if active and discovered)
 * @returns {string|null}
 */
function getDetectedTunnelUrl() {
    if (tunnelState === 'connected') {
        const hostname = getEffectiveHostname();
        if (hostname) {
            return `https://${hostname}`;
        }
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
