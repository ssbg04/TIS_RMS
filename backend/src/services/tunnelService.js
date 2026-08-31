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

const dnsPromises = dns.promises;
const publicResolver = new dnsPromises.Resolver();
publicResolver.setServers(['1.1.1.1', '1.0.0.1', '8.8.8.8', '8.8.4.4']);

let consecutiveFailures = 0;
const MAX_CONSECUTIVE_FAILURES = 4; // 4 * 15s = 60s of sustained outage before killing

/**
 * Checks if cloudflared is already running as an external process (e.g. start_tunnel.bat).
 */
function isCloudflaredAlreadyRunning() {
    if (process.platform !== 'win32') return false;
    try {
        const out = execSync('tasklist /FI "IMAGENAME eq cloudflared.exe" /NH', {
            encoding: 'utf8',
            stdio: ['pipe', 'pipe', 'ignore']
        });
        return out.toLowerCase().includes('cloudflared.exe');
    } catch (_) {
        return false;
    }
}

/**
 * Robust, multi-tiered internet check.
 * Uses Direct Public DNS (bypassing local router/LAN DNS), OS DNS, and HTTP/HTTPS ping in parallel.
 */
async function checkInternet(timeoutMs = 4500) {
    const checks = [
        // 1. Direct Public DNS query bypassing local LAN router DNS
        publicResolver.resolve('cloudflare.com').then(() => true).catch(() => false),
        
        // 2. OS default DNS query
        new Promise((resolve) => {
            dns.lookup('cloudflare.com', (err) => resolve(!err));
        }),

        // 3. Direct HTTPS request to Cloudflare 1.1.1.1
        new Promise((resolve) => {
            const req = https.get('https://1.1.1.1', { timeout: 3500 }, (res) => {
                res.destroy();
                resolve(true);
            });
            req.on('error', () => resolve(false));
            req.on('timeout', () => { req.destroy(); resolve(false); });
        }),

        // 4. HTTP request to Google 204 connectivity endpoint
        new Promise((resolve) => {
            const http = require('http');
            const req = http.get('http://clients3.google.com/generate_204', { timeout: 3500 }, (res) => {
                res.destroy();
                resolve(res.statusCode === 204 || res.statusCode === 200);
            });
            req.on('error', () => resolve(false));
            req.on('timeout', () => { req.destroy(); resolve(false); });
        })
    ];

    try {
        const results = await Promise.all(checks);
        return results.some((r) => r === true);
    } catch (_) {
        return false;
    }
}

/**
 * Starts the Cloudflare Tunnel child process.
 */
async function startTunnel() {
    if (tunnelProcess || isStarting) return;

    // Check if cloudflared is already active externally (e.g. from start_tunnel.bat)
    if (isCloudflaredAlreadyRunning()) {
        tunnelState = 'connected';
        lastLogMessage = 'External cloudflared process detected and running.';
        console.log('[Tunnel] External cloudflared process detected. Attached to active tunnel.');
        return;
    }

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
    const token = rawToken.replace(/[\r\n\s'"=]/g, '').trim(); // Strip any hidden CR/LF, spaces, or quotes
    const port = process.env.PORT || 18484;

    const args = token
        ? ['tunnel', '--protocol', 'auto', 'run', '--token', token]
        : ['tunnel', '--protocol', 'auto', '--url', `http://localhost:${port}`];

    console.log(`[Tunnel] Launching Cloudflare tunnel: "${binPath}" ${token ? 'tunnel --protocol auto run --token [CONFIGURED]' : args.join(' ')}`);
    tunnelState = 'starting';

    try {
        tunnelProcess = spawn(binPath, args, {
            windowsHide: true,
            stdio: ['ignore', 'pipe', 'pipe'],
            env: { ...process.env, NO_AUTOUPDATE: 'true', TUNNEL_METRICS: 'localhost:0' }
        });

        const pid = tunnelProcess.pid;
        console.log(`[Tunnel] Process started (PID: ${pid})`);

        tunnelProcess.stdout.on('data', (data) => {
            const str = data.toString();
            lastLogMessage = str.trim().split('\n').pop() || lastLogMessage;
            if (str.includes('Registered tunnel connection') || (str.includes('Connection') && str.includes('registered'))) {
                tunnelState = 'connected';
                console.log(`[Tunnel] Status: Connected to Cloudflare edge network.`);
            }
        });

        tunnelProcess.stderr.on('data', (data) => {
            const str = data.toString();
            lastLogMessage = str.trim().split('\n').pop() || lastLogMessage;
            if (str.includes('Registered tunnel connection') || (str.includes('Connection') && str.includes('registered'))) {
                tunnelState = 'connected';
                console.log(`[Tunnel] Status: Connected to Cloudflare edge network.`);
            } else if (str.includes('INF') || str.includes('WRN') || str.includes('ERR')) {
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

    // If an external cloudflared process is already running, preserve connected state
    if (!tunnelProcess && isCloudflaredAlreadyRunning()) {
        tunnelState = 'connected';
        lastLogMessage = 'External cloudflared process detected and active.';
        lastInternetCheck = true;
        lastCheckedTime = new Date().toISOString();
        return;
    }

    const hasInternet = await checkInternet();
    lastInternetCheck = hasInternet;
    lastCheckedTime = new Date().toISOString();

    if (hasInternet) {
        consecutiveFailures = 0;
        if (!tunnelProcess && !isStarting) {
            console.log('[Tunnel] Internet connection detected. Activating auto tunnel...');
            await startTunnel();
        }
    } else {
        consecutiveFailures++;
        if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
            if (tunnelProcess) {
                console.warn('[Tunnel] Sustained internet outage (>60s). Suspending tunnel until internet is restored...');
                tunnelState = 'no_internet';
                stopTunnel();
            } else {
                tunnelState = 'no_internet';
            }
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
