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

// Admin-initiated Email Password Reset (Web Form & Completion)
router.get('/reset-password-web', authController.resetPasswordWebPage);
router.post('/complete-password-reset', authController.completePasswordReset);

router.post('/verify-password', authenticateToken, authController.verifyPassword);

// Self-Service Account Deletion via Email Confirmation Link
router.post('/request-delete-account', authenticateToken, authController.requestAccountDeletion);
router.get('/confirm-delete-account-web', authController.confirmDeleteAccountWebPage);
router.post('/confirm-delete-account', authController.confirmDeleteAccount);

// Self-Service Account Deactivation (immediate, 2-step client confirmation)
router.post('/self-deactivate', authenticateToken, authController.selfDeactivateAccount);

// Session management (logged-in devices)
router.get('/sessions', authenticateToken, authController.getSessions);
router.delete('/sessions', authenticateToken, authController.revokeAllOtherSessions);
router.delete('/sessions/:id', authenticateToken, authController.revokeSession);

// Logout (stamps logout_at + removes session)
router.post('/logout', authenticateToken, authController.logout);

// Login/logout history (admin only)
router.get('/login-logs', authenticateToken, authorizeRoles('admin'), authController.getLoginLogs);

module.exports = router;

