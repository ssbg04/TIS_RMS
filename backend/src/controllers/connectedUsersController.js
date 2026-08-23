const os = require('os');

// ─────────────────────────────────────────────────────────────────────────────
// In-memory connected-users store
// Key: username (string)
// Value: { username, role, platform, ip, loginTime, lastSeen }
// ─────────────────────────────────────────────────────────────────────────────
const connectedUsers = new Map();
const SERVER_START_TIME = Date.now();

// Evict users whose lastSeen is older than 3 minutes (3 × heartbeat interval)
const EVICT_MS = 3 * 60 * 1000;

function evictStale() {
    const now = Date.now();
    for (const [key, user] of connectedUsers) {
        if (now - new Date(user.lastSeen).getTime() > EVICT_MS) {
            connectedUsers.delete(key);
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/server/heartbeat
// Body: { username, role, platform, ip }
// Upserts the user into the in-memory store.
// ─────────────────────────────────────────────────────────────────────────────
exports.heartbeat = (req, res) => {
    evictStale();
    const { username, role, platform, ip } = req.body;

    if (!username) {
        return res.status(400).json({ message: 'username is required.' });
    }

    const now = new Date().toISOString();
    const existing = connectedUsers.get(username);

    connectedUsers.set(username, {
        username,
        role: role || existing?.role || 'unknown',
        platform: platform || existing?.platform || 'unknown',
        ip: ip || existing?.ip || null,
        loginTime: existing?.loginTime || now,
        lastSeen: now,
    });

    res.json({ ok: true });
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/server/logout
// Body: { username }
// Removes the user from the in-memory store.
// ─────────────────────────────────────────────────────────────────────────────
exports.logout = (req, res) => {
    const { username } = req.body;
    if (username) connectedUsers.delete(username);
    res.json({ ok: true });
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/server/connected-users
// Returns the current list of connected users (stale entries evicted first).
// ─────────────────────────────────────────────────────────────────────────────
exports.getConnectedUsers = (req, res) => {
    evictStale();
    res.json(Array.from(connectedUsers.values()));
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/server/status
// Returns CPU %, memory usage, uptime, and connected user count.
// ─────────────────────────────────────────────────────────────────────────────

/** Computes an instantaneous CPU usage percentage by sampling os.cpus() twice. */
function getCpuPercent() {
    return new Promise((resolve) => {
        const cpusBefore = os.cpus();

        setTimeout(() => {
            const cpusAfter = os.cpus();
            let totalIdle = 0;
            let totalTick = 0;

            for (let i = 0; i < cpusBefore.length; i++) {
                const before = cpusBefore[i].times;
                const after  = cpusAfter[i].times;

                const idleDiff  = after.idle - before.idle;
                const totalDiff = Object.values(after).reduce((a, v) => a + v, 0)
                                - Object.values(before).reduce((a, v) => a + v, 0);

                totalIdle += idleDiff;
                totalTick += totalDiff;
            }

            const percent = totalTick === 0
                ? 0
                : parseFloat(((1 - totalIdle / totalTick) * 100).toFixed(1));
            resolve(percent);
        }, 200); // 200 ms sample window
    });
}

exports.getServerStatus = async (req, res) => {
    evictStale();
    try {
        const cpuPercent = await getCpuPercent();
        const memTotalMB = Math.round(os.totalmem() / 1024 / 1024);
        const memUsedMB  = Math.round((os.totalmem() - os.freemem()) / 1024 / 1024);
        const uptimeSec  = Math.round((Date.now() - SERVER_START_TIME) / 1000);

        let tunnelStatus = null;
        try {
            const { getTunnelStatus } = require('../services/tunnelService');
            tunnelStatus = getTunnelStatus();
        } catch (_) {}

        res.json({
            uptime: uptimeSec,
            cpuPercent,
            memUsedMB,
            memTotalMB,
            connectedUserCount: connectedUsers.size,
            tunnel: tunnelStatus,
        });
    } catch (err) {
        res.status(500).json({ message: 'Failed to get server status.', error: err.message });
    }
};
