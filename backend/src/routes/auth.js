const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

router.post('/login', authController.login);
router.get('/profile', authenticateToken, authController.getProfile);
router.put('/profile', authenticateToken, authController.updateProfile);
router.put('/change-password', authenticateToken, authController.changePassword);
router.post('/forgot-password', authController.requestPasswordReset); // Public — no token needed
router.get('/reset-requests', authenticateToken, authorizeRoles('admin'), authController.getResetRequests);
router.put('/reset-requests/:id/approve', authenticateToken, authorizeRoles('admin'), authController.approveResetRequest);
router.put('/reset-requests/:id/reject', authenticateToken, authorizeRoles('admin'), authController.rejectResetRequest);
router.post('/verify-password', authenticateToken, authController.verifyPassword);

module.exports = router;

