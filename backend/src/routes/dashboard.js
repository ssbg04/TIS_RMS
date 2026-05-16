const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/dashboardController');
const { authenticateToken } = require('../middleware/auth');

router.get('/stats', authenticateToken, dashboardController.getStats);
router.get('/pending-tasks', authenticateToken, dashboardController.getPendingTasks);

module.exports = router;
