const express = require('express');
const router  = express.Router();
const { authenticateToken } = require('../middleware/auth');
const {
    heartbeat,
    logout,
    getConnectedUsers,
    getServerStatus,
} = require('../controllers/connectedUsersController');

// POST /api/server/heartbeat  — upsert caller into connected-users list
router.post('/heartbeat',        authenticateToken, heartbeat);

// POST /api/server/logout      — remove caller from connected-users list
router.post('/logout',           authenticateToken, logout);

// GET  /api/server/connected-users — list all currently connected users
router.get('/connected-users',   authenticateToken, getConnectedUsers);

// GET  /api/server/status          — cpu%, mem, uptime, user count
router.get('/status',            authenticateToken, getServerStatus);

module.exports = router;
