const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

router.post('/login', authController.login);
router.get('/profile', authenticateToken, authController.getProfile);
router.put('/profile', authenticateToken, authController.updateProfile);
router.put('/change-password', authenticateToken, authController.changePassword);

// Self-Service Password Reset via Email OTP
router.post('/lookup-reset-options', authController.lookupResetOptions);
router.post('/send-email-otp', authController.sendEmailOtp);
router.post('/reset-password-email-otp', authController.resetPasswordEmailOtp);

router.post('/verify-password', authenticateToken, authController.verifyPassword);

module.exports = router;
