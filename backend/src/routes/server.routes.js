const express = require('express');
const router  = express.Router();
const { authenticateToken, authorizeRoles } = require('../middleware/auth');
const {
    heartbeat,
    logout,
    getConnectedUsers,
    getServerStatus,
} = require('../controllers/connectedUsersController');
const {
    setupAdmin,
    requestAdminResetOtp,
    verifyAdminResetOtp,
} = require('../controllers/serverAdminController');

// POST /api/server/heartbeat  — upsert caller into connected-users list
router.post('/heartbeat',        authenticateToken, heartbeat);

// POST /api/server/logout      — remove caller from connected-users list
router.post('/logout',           authenticateToken, logout);

// GET  /api/server/connected-users — list all currently connected users
router.get('/connected-users',   authenticateToken, getConnectedUsers);

// GET  /api/server/status          — cpu%, mem, uptime, user count
router.get('/status',            authenticateToken, getServerStatus);

// POST /api/server/tunnel/toggle — Toggle Cloudflare external network exposure
router.post('/tunnel/toggle', authenticateToken, authorizeRoles('admin'), async (req, res) => {
    try {
        const { enabled } = req.body;
        if (typeof enabled !== 'boolean') {
            return res.status(400).json({ message: 'Field "enabled" (boolean) is required.' });
        }
        const { setTunnelEnabled } = require('../services/tunnelService');
        const status = await setTunnelEnabled(enabled);
        res.json({
            ok: true,
            message: enabled ? 'Cloudflare Tunnel enabled.' : 'Cloudflare Tunnel disabled.',
            tunnel: status
        });
    } catch (err) {
        console.error('[Tunnel] Toggle error:', err);
        res.status(500).json({ message: 'Failed to toggle tunnel.', error: err.message });
    }
});

// GET  /api/server/tunnel/status — Fetch current Cloudflare tunnel status
router.get('/tunnel/status', authenticateToken, (req, res) => {
    try {
        const { getTunnelStatus } = require('../services/tunnelService');
        res.json({ ok: true, tunnel: getTunnelStatus() });
    } catch (err) {
        res.status(500).json({ message: 'Failed to get tunnel status.', error: err.message });
    }
});

// Server Manager Admin Setup & Password Retrieval (Protected by M2M Service Key)
router.post('/admin/setup',              setupAdmin);
router.post('/admin/request-reset-otp',  requestAdminResetOtp);
router.post('/admin/verify-reset-otp',   verifyAdminResetOtp);

module.exports = router;

