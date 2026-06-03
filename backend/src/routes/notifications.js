const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');
const { authenticateToken } = require('../middleware/auth');

router.get('/', authenticateToken, notificationController.getNotifications);
router.put('/mark-all-read', authenticateToken, notificationController.markAllRead);
router.put('/:id/read', authenticateToken, notificationController.markRead);
router.delete('/clear', authenticateToken, notificationController.clearNotifications);

module.exports = router;
