'use strict';

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const dns = require('dns');
const https = require('https');

let tunnelProcess = null;
let isStarting = false;
let monitorTimer = null;
let lastInternetCheck = false;
let lastCheckedTime = null;
let lastLogMessage = '';
let tunnelState = 'stopped'; // 'stopped', 'starting', 'connected', 'error', 'no_internet', 'disabled'
let consecutiveFailures = 0;
let detectedTunnelHostname = null;

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

/**
 * Robust check for internet connectivity.
 * Tests multiple DNS endpoints and falls back to HTTPS.
 */
function checkInternet(timeoutMs = 5000) {
    return new Promise((resolve) => {
        let isResolved = false;
        const done = (val) => {
            if (!isResolved) {
                isResolved = true;
                clearTimeout(timer);
                resolve(val);
            }
        };

        const timer = setTimeout(() => done(false), timeoutMs);

        // Try DNS resolution on multiple reliable hosts in parallel
        dns.lookup('cloudflare.com', (err1) => {
            if (!err1) return done(true);

            dns.lookup('1.1.1.1', (err2) => {
                if (!err2) return done(true);

                // Fallback HTTPS request
                const req = https.get('https://1.1.1.1', { timeout: 3000 }, (res) => {
                    res.destroy();
                    done(true);
                });

                req.on('error', () => done(false));
                req.on('timeout', () => {
                    req.destroy();
                    done(false);
                });
            });
        });
    });
}

/**
 * Starts the Cloudflare Tunnel child process.
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
    const token = rawToken.replace(/[\r\n\s'"=]/g, '').trim();
    const port = process.env.PORT || 18484;

    // Use default auto-negotiated protocol (QUIC with HTTP/2 fallback) and --no-autoupdate
    const args = token
        ? ['tunnel', '--no-autoupdate', 'run', '--token', token]
        : ['tunnel', '--no-autoupdate', '--url', `http://localhost:${port}`];

    console.log(`[Tunnel] Launching Cloudflare tunnel: "${binPath}" ${token ? 'tunnel --no-autoupdate run --token [CONFIGURED]' : args.join(' ')}`);
    tunnelState = 'starting';

    try {
        tunnelProcess = spawn(binPath, args, {
            windowsHide: true,
            stdio: ['ignore', 'pipe', 'pipe'],
            env: { ...process.env, NO_AUTOUPDATE: 'true' }
        });

        const pid = tunnelProcess.pid;
        console.log(`[Tunnel] Process started (PID: ${pid})`);

        const handleLogStream = (data) => {
            const str = data.toString();
            const lines = str.trim().split('\n');
            for (const line of lines) {
                const trimmed = line.trim();
                if (!trimmed) continue;
                lastLogMessage = trimmed;

                // Extract configured hostname if present in ingress logs
                const hostMatch = trimmed.match(/"hostname":\s*"([^"]+)"/);
                if (hostMatch && hostMatch[1]) {
                    detectedTunnelHostname = hostMatch[1];
                }

                if (trimmed.includes('Registered tunnel connection') || 
                    (trimmed.includes('Connection') && trimmed.includes('registered')) ||
                    trimmed.includes('Tunnel connection curve preferences')) {
                    tunnelState = 'connected';
                    consecutiveFailures = 0;
                }
            }
        };

        tunnelProcess.stdout.on('data', handleLogStream);
        tunnelProcess.stderr.on('data', handleLogStream);

        tunnelProcess.on('error', (err) => {
            console.error('[Tunnel] Process error:', err.message);
            tunnelState = 'error';
            lastLogMessage = err.message;
            tunnelProcess = null;
            isStarting = false;
        });

        tunnelProcess.on('exit', (code, signal) => {
            console.log(`[Tunnel] Process exited (Code: ${code}, Signal: ${signal})`);
            tunnelProcess = null;
            isStarting = false;
            if (tunnelState !== 'no_internet' && tunnelState !== 'disabled') {
                tunnelState = 'stopped';
            }
        });

        // If still alive after 4 seconds, mark as connected
        setTimeout(() => {
            if (tunnelProcess && tunnelState === 'starting') {
                tunnelState = 'connected';
                consecutiveFailures = 0;
            }
        }, 4000);

    } catch (err) {
        console.error('[Tunnel] Failed to start tunnel process:', err.message);
        tunnelState = 'error';
        lastLogMessage = err.message;
        tunnelProcess = null;
    } finally {
        isStarting = false;
    }
}

/**
 * Stops the Cloudflare Tunnel child process cleanly and non-blockingly.
 */
function stopTunnel() {
    if (!tunnelProcess) return;
    const proc = tunnelProcess;
    tunnelProcess = null;
    tunnelState = 'stopped';

    try {
        console.log(`[Tunnel] Stopping tunnel process (PID: ${proc.pid})...`);
        if (process.platform === 'win32') {
            // Asynchronous non-blocking taskkill
            const killer = spawn('taskkill', ['/pid', String(proc.pid), '/T', '/F'], {
                windowsHide: true,
                stdio: 'ignore'
            });
            killer.on('error', () => {
                try { proc.kill('SIGTERM'); } catch (_) {}
            });
        } else {
            proc.kill('SIGTERM');
        }
    } catch (err) {
        console.warn('[Tunnel] Error stopping tunnel:', err.message);
    }
}

/**
 * Periodic check loop: checks internet and maintains tunnel state resiliently.
 */
async function checkAndMaintainTunnel() {
    const isEnabled = process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false';
    if (!isEnabled) {
        if (tunnelProcess) stopTunnel();
        tunnelState = 'disabled';
        return;
    }

    const hasInternet = await checkInternet(5000);
    lastInternetCheck = hasInternet;
    lastCheckedTime = new Date().toISOString();

    if (hasInternet) {
        consecutiveFailures = 0;
        if (!tunnelProcess && !isStarting) {
            console.log('[Tunnel] Internet connection available. Starting Cloudflare tunnel...');
            await startTunnel();
        }
    } else {
        consecutiveFailures++;
        console.warn(`[Tunnel] Internet check failed (${consecutiveFailures}/3)`);

        // Only suspend tunnel after 3 consecutive failures (approx 90s)
        if (consecutiveFailures >= 3 && tunnelProcess) {
            console.warn('[Tunnel] Persistent internet loss. Suspending tunnel...');
            tunnelState = 'no_internet';
            stopTunnel();
        }
    }
}

/**
 * Initializes auto tunnel activation on server startup.
 */
function startAutoTunnel() {
    const isEnabled = process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false';
    if (!isEnabled) {
        console.log('[Tunnel] Auto tunnel is disabled via CLOUDFLARE_TUNNEL_ENABLED=false');
        tunnelState = 'disabled';
        return;
    }

    console.log('[Tunnel] Initializing Auto Cloudflare Tunnel Service...');
    
    // Initial check after a short server startup delay
    setTimeout(checkAndMaintainTunnel, 2000);

    // Periodic check interval (default: 30 seconds to prevent aggressive CPU/DNS churn)
    const intervalMs = parseInt(process.env.CLOUDFLARE_TUNNEL_CHECK_INTERVAL, 10) || 30000;
    if (monitorTimer) clearInterval(monitorTimer);
    monitorTimer = setInterval(checkAndMaintainTunnel, intervalMs);

    // Ensure clean shutdown on parent process exit
    const cleanExit = () => {
        if (monitorTimer) clearInterval(monitorTimer);
        stopTunnel();
    };

    process.on('exit', cleanExit);
    process.on('SIGINT', () => { cleanExit(); process.exit(0); });
    process.on('SIGTERM', () => { cleanExit(); process.exit(0); });
    process.on('beforeExit', cleanExit);
}

/**
 * Returns current tunnel status.
 */
function getTunnelStatus() {
    const binPath = getCloudflaredPath();
    return {
        enabled: process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false',
        hasExecutable: !!binPath,
        executablePath: binPath,
        hasInternet: lastInternetCheck,
        isRunning: !!tunnelProcess,
        pid: tunnelProcess ? tunnelProcess.pid : null,
        status: tunnelState,
        hostname: detectedTunnelHostname,
        publicUrl: detectedTunnelHostname ? `https://${detectedTunnelHostname}` : null,
        lastChecked: lastCheckedTime,
        lastLog: lastLogMessage
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

