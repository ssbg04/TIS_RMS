const express = require('express');
const router = express.Router();
const settingsController = require('../controllers/settingsController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

router.get('/', authenticateToken, authorizeRoles('admin'), settingsController.getSettings);
router.put('/', authenticateToken, authorizeRoles('admin'), settingsController.updateSettings);

module.exports = router;
