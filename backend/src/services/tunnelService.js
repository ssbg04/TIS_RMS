'use strict';

const { spawn, execSync } = require('child_process');
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
let tunnelState = 'stopped'; // 'stopped', 'starting', 'connected', 'error', 'no_internet'
let retryCount = 0;

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
        path.join(__dirname, '..', '..', '..', 'bin', binaryName),
        path.join(__dirname, '..', '..', 'bin', binaryName),
        path.join(__dirname, '..', 'bin', binaryName),
        path.join(process.cwd(), 'bin', binaryName),
        path.join(process.cwd(), '..', 'bin', binaryName),
    ];

    for (const cand of candidatePaths) {
        if (fs.existsSync(cand)) {
            setExecutable(cand);
            return path.resolve(cand);
        }
    }

    try {
        const cmd = isWindows ? 'where.exe cloudflared' : 'which cloudflared';
        const out = execSync(cmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] });
        const first = out.trim().split(/\r?\n/)[0];
        if (first && fs.existsSync(first)) {
            setExecutable(first);
            return first;
        }
    } catch (_) {}

    return null;
}

/**
 * Fast check for internet connectivity.
 * Uses DNS lookup to Cloudflare/Google DNS followed by a quick HTTPS ping if needed.
 */
function checkInternet(timeoutMs = 4000) {
    return new Promise((resolve) => {
        const timer = setTimeout(() => {
            resolve(false);
        }, timeoutMs);

        // Try DNS resolution
        dns.lookup('cloudflare.com', (err) => {
            if (!err) {
                clearTimeout(timer);
                resolve(true);
                return;
            }

            // Fallback DNS
            dns.lookup('1.1.1.1', (err2) => {
                if (!err2) {
                    clearTimeout(timer);
                    resolve(true);
                    return;
                }

                // Fallback HTTPS request to 1.1.1.1
                const req = https.get('https://1.1.1.1', { timeout: 2500 }, (res) => {
                    clearTimeout(timer);
                    res.destroy();
                    resolve(true);
                });

                req.on('error', () => {
                    clearTimeout(timer);
                    resolve(false);
                });

                req.on('timeout', () => {
                    req.destroy();
                    clearTimeout(timer);
                    resolve(false);
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

    const DEFAULT_TOKEN = 'eyJhIjoiZWRhMWQ4ZTc1MzNjMjBiMDcyNmM0ZGU1OWE5YTMxYzgiLCJ0IjoiZjJhOGYyYmMtMWE1YS00MmNmLWJjZTUtZWMzYzAxNzY4M2IyIiwicyI6Ik9EUXpZMkUyT0RNdE0yVmxNaTAwTjJVMUxXRmlZVFl0TkRKak1HSmpOR0l4WTJReSJ9';
    const token = process.env.CLOUDFLARE_TUNNEL_TOKEN || DEFAULT_TOKEN;
    const port = process.env.PORT || 18484;

    const args = token
        ? ['tunnel', '--protocol', 'http2', 'run', '--token', token]
        : ['tunnel', '--protocol', 'http2', '--url', `http://localhost:${port}`];

    console.log(`[Tunnel] Launching Cloudflare tunnel: "${binPath}" ${token ? 'tunnel --protocol http2 run --token [CONFIGURED]' : args.join(' ')}`);
    tunnelState = 'starting';

    try {
        tunnelProcess = spawn(binPath, args, {
            windowsHide: true,
            stdio: ['ignore', 'pipe', 'pipe']
        });

        const pid = tunnelProcess.pid;
        console.log(`[Tunnel] Process started (PID: ${pid})`);

        tunnelProcess.stdout.on('data', (data) => {
            const str = data.toString();
            lastLogMessage = str.trim().split('\n').pop() || lastLogMessage;
            if (str.includes('Registered tunnel connection') || str.includes('Connection') && str.includes('registered')) {
                tunnelState = 'connected';
                console.log(`[Tunnel] Status: Connected to Cloudflare edge network.`);
            }
        });

        tunnelProcess.stderr.on('data', (data) => {
            const str = data.toString();
            lastLogMessage = str.trim().split('\n').pop() || lastLogMessage;
            if (str.includes('Registered tunnel connection') || str.includes('Connection') && str.includes('registered')) {
                tunnelState = 'connected';
                console.log(`[Tunnel] Status: Connected to Cloudflare edge network.`);
            } else if (str.includes('INF') || str.includes('WRN') || str.includes('ERR')) {
                // Cloudflare logs mostly to stderr
                if (str.includes('error') || str.includes('ERR')) {
                    console.warn(`[Tunnel] Notice: ${str.trim()}`);
                }
            }
        });

        tunnelProcess.on('error', (err) => {
            console.error('[Tunnel] Process spawn error:', err.message);
            tunnelState = 'error';
            lastLogMessage = err.message;
            tunnelProcess = null;
            isStarting = false;
        });

        tunnelProcess.on('exit', (code, signal) => {
            console.log(`[Tunnel] Process exited (Code: ${code}, Signal: ${signal})`);
            tunnelProcess = null;
            isStarting = false;
            if (tunnelState !== 'no_internet') {
                tunnelState = 'stopped';
            }
        });

        // Mark as connected after a short period if still alive
        setTimeout(() => {
            if (tunnelProcess && tunnelState === 'starting') {
                tunnelState = 'connected';
            }
        }, 5000);

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
 * Stops the Cloudflare Tunnel child process.
 */
function stopTunnel() {
    if (!tunnelProcess) return;
    try {
        console.log(`[Tunnel] Stopping tunnel process (PID: ${tunnelProcess.pid})...`);
        const pid = tunnelProcess.pid;
        if (process.platform === 'win32') {
            try {
                execSync(`taskkill /pid ${pid} /T /F`, { stdio: 'ignore' });
            } catch (_) {
                try { tunnelProcess.kill('SIGTERM'); } catch (__) {}
            }
        } else {
            tunnelProcess.kill('SIGTERM');
        }
    } catch (err) {
        console.warn('[Tunnel] Error stopping tunnel:', err.message);
    } finally {
        tunnelProcess = null;
        tunnelState = 'stopped';
    }
}

/**
 * Periodic check loop: checks internet and maintains tunnel state.
 */
async function checkAndMaintainTunnel() {
    const isEnabled = process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false';
    if (!isEnabled) {
        if (tunnelProcess) stopTunnel();
        tunnelState = 'disabled';
        return;
    }

    const hasInternet = await checkInternet();
    lastInternetCheck = hasInternet;
    lastCheckedTime = new Date().toISOString();

    if (hasInternet) {
        if (!tunnelProcess && !isStarting) {
            console.log('[Tunnel] Internet connection detected. Activating auto tunnel...');
            await startTunnel();
        }
    } else {
        if (tunnelProcess) {
            console.warn('[Tunnel] Internet connection lost. Suspending tunnel until internet is restored...');
            tunnelState = 'no_internet';
            stopTunnel();
        } else {
            tunnelState = 'no_internet';
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
    
    // Initial check immediately
    checkAndMaintainTunnel();

    // Periodic check interval (default: 15 seconds)
    const intervalMs = parseInt(process.env.CLOUDFLARE_TUNNEL_CHECK_INTERVAL, 10) || 15000;
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
        lastChecked: lastCheckedTime,
        lastLog: lastLogMessage
    };
}

module.exports = {
    startAutoTunnel,
    startTunnel,
    stopTunnel,
    getTunnelStatus,
    checkInternet,
    getCloudflaredPath
};
