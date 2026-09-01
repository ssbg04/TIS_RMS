'use strict';

const { spawn, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const dns = require('dns');
const http = require('http');
const https = require('https');

// ─── Constants ────────────────────────────────────────────────────────────────
const INTERNET_TIMEOUT_MS         = 5_000;
const INTERNET_CHECK_INTERVAL_MS  = 15_000;
const ORIGIN_CHECK_INTERVAL_MS    = 20_000;
const ORIGIN_HOST                 = '127.0.0.1';
const ORIGIN_PORT                 = parseInt(process.env.PORT || '18484', 10);
const TUNNEL_CONNECT_TIMEOUT_MS   = 90_000;  // Warn if no connection registered after this

// ─── Service State ────────────────────────────────────────────────────────────
let tunnelProcess            = null;
let isStarting               = false;

/**
 * Separate health dimensions — never collapse these into one flag.
 *
 * tunnelState: overall reported status (used by getTunnelStatus/API)
 *   'stopped' | 'starting' | 'connected' | 'degraded' | 'error' | 'no_internet' | 'disabled'
 *
 * cloudflaredRunning: true iff the child process is alive right now.
 * tunnelConnected:    true iff cloudflared has logged an actual connection registration.
 * originHealthy:      true iff http://127.0.0.1:<port>/ returned HTTP 200.
 * publicEndpointStatus: last HTTP status from the public Cloudflare URL (diagnostic only).
 */
let tunnelState              = 'stopped';
let cloudflaredRunning       = false;
let tunnelConnected          = false;
let originHealthy            = false;
let publicEndpointStatus     = null;

let detectedTunnelHostname   = null;
let lastInternetCheck        = false;
let lastLogMessage           = '';
let internetTimer            = null;
let originHealthTimer        = null;
let connectTimeoutTimer      = null;
let signalHandlersRegistered = false;

// ─── Helpers ──────────────────────────────────────────────────────────────────

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
 * Finds the cloudflared executable across common workspace and system locations.
 * Respects CLOUDFLARED_PATH env var for custom installations.
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

// ─── Internet Check ───────────────────────────────────────────────────────────

/**
 * Checks whether an internet connection is available via DNS + HTTPS probe.
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

// ─── Origin Health Check ──────────────────────────────────────────────────────

/**
 * Checks whether the local Node.js origin is reachable on 127.0.0.1.
 * Uses IPv4 loopback explicitly to avoid Windows localhost/IPv6 ambiguity.
 * This is NOT the same as the public Cloudflare endpoint check.
 *
 * @returns {Promise<boolean>}
 */
function checkOriginHealth() {
    return new Promise((resolve) => {
        let done = false;
        const finish = (ok) => {
            if (!done) {
                done = true;
                resolve(ok);
            }
        };

        const req = http.request(
            {
                hostname: ORIGIN_HOST,   // always 127.0.0.1, never 'localhost'
                port: ORIGIN_PORT,
                path: '/',
                method: 'GET',
                timeout: 3000,
                family: 4,               // force IPv4
            },
            (res) => {
                res.resume();            // drain body
                finish(res.statusCode >= 200 && res.statusCode < 500);
            }
        );

        req.on('timeout', () => {
            req.destroy();
            finish(false);
        });
        req.on('error', () => finish(false));
        req.end();
    });
}

/**
 * Runs a periodic origin health check and updates state/logs accordingly.
 */
async function runOriginHealthCheck() {
    const wasHealthy = originHealthy;
    originHealthy = await checkOriginHealth();

    if (originHealthy && !wasHealthy) {
        console.log(`[Tunnel] Origin healthy — http://${ORIGIN_HOST}:${ORIGIN_PORT}/ is reachable.`);
    } else if (!originHealthy && wasHealthy) {
        console.warn(`[Tunnel] Origin unreachable — http://${ORIGIN_HOST}:${ORIGIN_PORT}/ is NOT responding.`);
        console.warn('[Tunnel] Diagnostic: if cloudflared is returning 502, this is likely the root cause.');
    }
}

// ─── Cloudflared Output Parser ────────────────────────────────────────────────

/**
 * Parses cloudflared log lines to update connection status and extract hostnames.
 * The connection state is determined by ACTUAL cloudflared output, not by inference.
 *
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

        // 2. Actual connection registration detection.
        //    These are cloudflared's real "we have an established tunnel" log lines.
        //    We do NOT infer connection from process uptime.
        const isRegisteredConnection =
            text.includes('Registered tunnel connection') ||
            (text.includes('Connection') && text.includes('registered')) ||
            text.includes('Registered new connection');

        // These indicate cloudflared is trying to connect but hasn't confirmed yet
        const isConnectingIndicator =
            text.includes('Tunnel connection curve preferences') ||
            text.includes('protocol=quic') ||
            text.includes('protocol=http2') ||
            text.includes('Connecting to Cloudflare') ||
            text.includes('Trying to connect');

        if (isRegisteredConnection) {
            if (!tunnelConnected) {
                tunnelConnected = true;
                tunnelState = 'connected';
                // Cancel the connection timeout warning timer since we connected
                if (connectTimeoutTimer) {
                    clearTimeout(connectTimeoutTimer);
                    connectTimeoutTimer = null;
                }
                console.log('[Tunnel] Tunnel connection registered — cloudflared is connected to Cloudflare edge.');
            }
        } else if (isConnectingIndicator && tunnelState === 'starting') {
            console.log('[Tunnel] Tunnel connection in progress (cloudflared is negotiating)...');
        }

        // 3. Disconnection / reconnection events
        if (text.includes('Unregistered tunnel connection') ||
            text.includes('Lost connection to the Cloudflare edge') ||
            text.includes('Retrying connection')) {
            if (tunnelConnected) {
                tunnelConnected = false;
                if (tunnelState === 'connected') tunnelState = 'starting';
                console.warn('[Tunnel] Tunnel connection lost — cloudflared is reconnecting...');
            }
        }

        // 4. Auth / fatal error detection
        if (text.includes('Invalid token') || text.includes('failed to authenticate') ||
            text.includes('Authentication error') || text.includes('Unauthorized')) {
            console.error('[Tunnel] Cloudflare authentication failed. Verify CLOUDFLARE_TUNNEL_TOKEN in .env.');
            tunnelState = 'error';
        }

        // 5. Log 502-related messages from cloudflared itself as diagnostic info
        //    but DO NOT trigger a restart from these
        if (text.includes('502') || text.includes('Bad Gateway') ||
            text.includes('unable to reach the origin') || text.includes('error="dial tcp')) {
            console.warn('[Tunnel] cloudflared reported an origin-reach error (possible 502 source).');
            console.warn(`[Tunnel]   cloudflared message: ${text.substring(0, 200)}`);
            console.warn(`[Tunnel]   Origin health: ${originHealthy ? 'healthy' : 'UNREACHABLE'}`);
            console.warn(`[Tunnel]   cloudflared process: ${cloudflaredRunning ? 'running' : 'not running'}`);
        }
    }
}

// ─── Tunnel Lifecycle ─────────────────────────────────────────────────────────

/**
 * Launches cloudflared using only the configured tunnel token.
 * Guards against duplicate processes — will not spawn if one is already running.
 */
async function startTunnel() {
    // Strict duplicate guard: never start a second cloudflared for the same tunnel
    if (tunnelProcess !== null || isStarting) {
        console.log('[Tunnel] Skipping start — cloudflared is already running or starting.');
        return;
    }

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
        lastLogMessage = 'CLOUDFLARE_TUNNEL_TOKEN is required but not set. Add it to backend/.env.';
        console.error(`[Tunnel] ${lastLogMessage}`);
        isStarting = false;
        return;
    }

    // Log a masked token reference (first 6 chars only) so the log proves a token was found
    // without exposing the full value.
    const maskedToken = token.substring(0, 6) + '...';
    console.log(`[Tunnel] Starting cloudflared... (token prefix: ${maskedToken})`);
    console.log(`[Tunnel] Binary: ${binPath}`);

    tunnelState = 'starting';
    tunnelConnected = false;

    const args = ['tunnel', '--no-autoupdate', 'run', '--token', token];

    try {
        const proc = spawn(binPath, args, {
            windowsHide: true,
            stdio: ['ignore', 'pipe', 'pipe'],
            env: { ...process.env, NO_AUTOUPDATE: 'true' },
            // detached: false (default) — child dies with parent on Windows
        });

        tunnelProcess = proc;
        cloudflaredRunning = true;
        isStarting = false;
        console.log(`[Tunnel] cloudflared process started (PID: ${proc.pid})`);

        proc.stdout.on('data', handleProcessOutput);
        proc.stderr.on('data', handleProcessOutput);

        proc.on('error', (err) => {
            console.error('[Tunnel] cloudflared process error:', err.message);
            tunnelState = 'error';
            lastLogMessage = err.message;
            if (tunnelProcess === proc) {
                tunnelProcess = null;
                cloudflaredRunning = false;
                tunnelConnected = false;
            }
            isStarting = false;
            clearConnectTimeoutTimer();
        });

        proc.on('exit', (code, signal) => {
            const reason = signal ? `signal=${signal}` : `code=${code}`;
            console.log(`[Tunnel] cloudflared process exited (${reason})`);
            console.log('[Tunnel] Restarting cloudflared because the process exited (next internet check cycle).');

            if (tunnelProcess === proc) {
                tunnelProcess = null;
                cloudflaredRunning = false;
                tunnelConnected = false;
            }
            isStarting = false;
            if (tunnelState !== 'disabled') {
                tunnelState = 'stopped';
            }
            clearConnectTimeoutTimer();
        });

        // ── Connection timeout warning ──────────────────────────────────────
        // If cloudflared has been running for TUNNEL_CONNECT_TIMEOUT_MS without
        // registering a tunnel connection, report 'degraded'. We do NOT kill or
        // restart the process — cloudflared may still be retrying legitimately.
        clearConnectTimeoutTimer();
        connectTimeoutTimer = setTimeout(() => {
            connectTimeoutTimer = null;
            if (tunnelProcess === proc && !tunnelConnected) {
                tunnelState = 'degraded';
                console.warn(`[Tunnel] No tunnel connection registered after ${TUNNEL_CONNECT_TIMEOUT_MS / 1000}s.`);
                console.warn('[Tunnel] Tunnel state: degraded. cloudflared is still running — it may still connect.');
                console.warn(`[Tunnel] Diagnostics:`);
                console.warn(`[Tunnel]   Origin health:      ${originHealthy ? 'healthy' : 'UNREACHABLE'}`);
                console.warn(`[Tunnel]   cloudflared PID:    ${proc.pid}`);
                console.warn(`[Tunnel]   Tunnel connected:   false`);
                console.warn('[Tunnel] Check that CLOUDFLARE_TUNNEL_TOKEN is valid and not revoked.');
            }
        }, TUNNEL_CONNECT_TIMEOUT_MS);

    } catch (err) {
        console.error('[Tunnel] Failed to spawn cloudflared:', err.message);
        tunnelState = 'error';
        lastLogMessage = err.message;
        tunnelProcess = null;
        cloudflaredRunning = false;
        isStarting = false;
        clearConnectTimeoutTimer();
    }
}

function clearConnectTimeoutTimer() {
    if (connectTimeoutTimer) {
        clearTimeout(connectTimeoutTimer);
        connectTimeoutTimer = null;
    }
}

/**
 * Stops the cloudflared process cleanly.
 * On Windows, uses taskkill /T /F to also terminate any child processes.
 */
function stopTunnel() {
    clearConnectTimeoutTimer();

    if (!tunnelProcess) {
        cloudflaredRunning = false;
        tunnelConnected = false;
        return;
    }

    const proc = tunnelProcess;
    tunnelProcess = null;
    cloudflaredRunning = false;
    tunnelConnected = false;
    tunnelState = 'stopped';

    try {
        console.log(`[Tunnel] Stopping cloudflared process (PID: ${proc.pid})...`);
        if (process.platform === 'win32') {
            spawnSync('taskkill', ['/pid', String(proc.pid), '/T', '/F'], {
                windowsHide: true,
                stdio: 'ignore'
            });
        } else {
            proc.kill('SIGTERM');
        }
    } catch (err) {
        console.warn('[Tunnel] Error while stopping cloudflared process:', err.message);
    }
}

// ─── Auto-Start / Internet Watch ─────────────────────────────────────────────

/**
 * Checks internet and auto-starts the tunnel if needed.
 * This is called on startup and periodically.
 *
 * Key invariant: restart cloudflared ONLY when the process is not running.
 * A public HTTP 502 alone is never a reason to call this.
 */
async function checkAndAutoStart() {
    const isEnabled = process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false';
    if (!isEnabled) {
        if (tunnelProcess) stopTunnel();
        tunnelState = 'disabled';
        return;
    }

    // If tunnel is already running or launching, do nothing.
    // A 502 from the public endpoint is NOT a trigger to restart.
    if (tunnelProcess !== null || isStarting) return;

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

// ─── Public API ───────────────────────────────────────────────────────────────

/**
 * Initializes the tunnel service on server startup.
 * - Immediately attempts to start if internet is available.
 * - Polls every INTERNET_CHECK_INTERVAL_MS to auto-recover if internet was down.
 * - Polls every ORIGIN_CHECK_INTERVAL_MS to check origin health (diagnostic).
 * - Registers process-exit signal handlers for clean shutdown.
 */
function startAutoTunnel() {
    const isEnabled = process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false';
    if (!isEnabled) {
        console.log('[Tunnel] Cloudflare Tunnel is disabled (CLOUDFLARE_TUNNEL_ENABLED=false)');
        tunnelState = 'disabled';
        return;
    }

    console.log('[Tunnel] Initializing Cloudflare Tunnel service...');

    // Immediate attempt
    checkAndAutoStart();

    // Run an initial origin check shortly after startup
    setTimeout(runOriginHealthCheck, 3_000);

    // Periodic internet/restart check (only restarts if process is dead)
    if (internetTimer) clearInterval(internetTimer);
    internetTimer = setInterval(checkAndAutoStart, INTERNET_CHECK_INTERVAL_MS);

    // Periodic origin health check (diagnostic, never triggers restart)
    if (originHealthTimer) clearInterval(originHealthTimer);
    originHealthTimer = setInterval(runOriginHealthCheck, ORIGIN_CHECK_INTERVAL_MS);

    if (!signalHandlersRegistered) {
        signalHandlersRegistered = true;

        const cleanExit = () => {
            if (internetTimer) { clearInterval(internetTimer); internetTimer = null; }
            if (originHealthTimer) { clearInterval(originHealthTimer); originHealthTimer = null; }
            stopTunnel();
        };

        process.on('exit', cleanExit);
        process.on('SIGINT',   () => { cleanExit(); process.exit(0); });
        process.on('SIGTERM',  () => { cleanExit(); process.exit(0); });
        process.on('SIGUSR2',  () => { cleanExit(); process.kill(process.pid, 'SIGUSR2'); });
        process.on('beforeExit', cleanExit);
    }
}

/**
 * Returns current tunnel status and diagnostics.
 * All four health dimensions are included for observability.
 *
 * NOTE: publicEndpointStatus is not polled automatically to avoid hammering the
 * Cloudflare edge. It is updated only if an external caller checks the public URL.
 *
 * @returns {object}
 */
function getTunnelStatus() {
    const binPath = getCloudflaredPath();
    const hostname = getEffectiveHostname();
    const tokenConfigured = !!(process.env.CLOUDFLARE_TUNNEL_TOKEN || '').trim();

    return {
        // Configuration
        enabled:            process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false',
        hasExecutable:      !!binPath,
        executablePath:     binPath,
        hasToken:           tokenConfigured,

        // Connectivity
        hasInternet:        lastInternetCheck,

        // Health dimensions (separate, not collapsed)
        cloudflaredRunning: cloudflaredRunning,
        tunnelConnected:    tunnelConnected,
        originHealthy:      originHealthy,
        publicEndpointStatus: publicEndpointStatus,

        // Process
        pid:                tunnelProcess ? tunnelProcess.pid : null,

        // Overall state
        status:             tunnelState,

        // Hostname / URL
        hostname:           hostname,
        publicUrl:          hostname ? `https://${hostname}` : null,

        // Last log line (for diagnostics)
        lastLog:            lastLogMessage,
    };
}

/**
 * Returns detected public tunnel URL only when the tunnel is genuinely connected.
 * Returns null if cloudflared has not registered a connection.
 *
 * @returns {string|null}
 */
function getDetectedTunnelUrl() {
    if (tunnelConnected && tunnelState === 'connected') {
        const hostname = getEffectiveHostname();
        if (hostname) return `https://${hostname}`;
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
    checkOriginHealth,
    getCloudflaredPath,
};
