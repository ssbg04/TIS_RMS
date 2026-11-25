const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');
const { loginRateLimiter } = require('../middleware/loginRateLimiter');

router.post('/login', loginRateLimiter, authController.login);
// Machine-to-Machine Service Token for Server Manager
router.post('/service-token', authController.getServiceToken);
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

// Biometric Authentication (Token-based)
router.post('/biometric/register', authenticateToken, authController.registerBiometricToken);
router.post('/biometric/login', authController.loginWithBiometricToken);
router.post('/biometric/disable', authenticateToken, authController.disableBiometricToken);

// Logout (stamps logout_at + removes session)
router.post('/logout', authenticateToken, authController.logout);

// Login/logout history (admin only)
router.get('/login-logs', authenticateToken, authorizeRoles('admin'), authController.getLoginLogs);

// Two-Factor Authentication (2FA: TOTP & Email OTP + Backup Codes)
router.post('/2fa/verify-login', authController.verifyTwoFactorLogin);
router.post('/2fa/resend-login-otp', authController.resendTwoFactorLoginOtp);
router.get('/2fa/status', authenticateToken, authController.getTwoFactorStatus);
router.post('/2fa/totp/setup', authenticateToken, authController.setupTotp);
router.post('/2fa/totp/confirm', authenticateToken, authController.confirmTotp);
router.post('/2fa/email/setup', authenticateToken, authController.setupEmailTwoFactor);
router.post('/2fa/email/confirm', authenticateToken, authController.confirmEmailTwoFactor);
router.post('/2fa/backup-codes/regenerate', authenticateToken, authController.regenerateBackupCodes);
router.post('/2fa/disable', authenticateToken, authController.disableTwoFactor);

module.exports = router;

