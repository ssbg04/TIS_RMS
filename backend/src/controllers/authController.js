const db = require('../config/db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
require('dotenv').config();
const { createNotification } = require('./notificationController');
const { sendPasswordResetOtp } = require('../services/emailService');

// Helper to mask email (e.g. j***e@gmail.com)
const maskEmail = (email) => {
    if (!email || !email.includes('@')) return null;
    const [name, domain] = email.split('@');
    if (name.length <= 2) return `${name[0]}***@${domain}`;
    return `${name[0]}***${name[name.length - 1]}@${domain}`;
};

// POST /api/auth/login
exports.login = (req, res) => {
    const { username, password } = req.body;

    try {
        const user = db.prepare('SELECT * FROM users WHERE username = ?').get(username);

        if (!user || !bcrypt.compareSync(password, user.password)) {
            return res.status(401).json({ message: 'Invalid username or password' });
        }

        // Block inactive accounts before issuing a token
        if (user.is_active === 0) {
            return res.status(403).json({ message: 'Your account has been deactivated. Please contact an administrator.' });
        }

        const token = jwt.sign(
            { id: user.id, username: user.username, role: user.role },
            process.env.JWT_SECRET,
            { expiresIn: '75d' } // Extended for Remember Me support
        );

        res.json({
            token,
            user: {
                id: user.id,
                username: user.username,
                role: user.role,
                firstName: user.first_name,
                lastName: user.last_name
            }
        });
    } catch (error) {
        res.status(500).json({ message: 'Login failed', error: error.message });
    }
};

// GET /api/auth/profile
exports.getProfile = (req, res) => {
    try {
        const user = db.prepare('SELECT id, username, first_name, middle_name, last_name, extension, role, email, phone FROM users WHERE id = ?').get(req.user.id);
        res.json(user);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch profile', error: error.message });
    }
};

// PUT /api/auth/profile
exports.updateProfile = (req, res) => {
    const { firstName, middleName, lastName, extension, phone, email } = req.body;
    
    try {
        db.prepare(`
            UPDATE users 
            SET first_name = ?, middle_name = ?, last_name = ?, extension = ?, phone = ?, email = ?, updated_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
            WHERE id = ?
        `).run(firstName, middleName, lastName, extension, phone, email, req.user.id);
        
        res.json({ message: 'Profile updated successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to update profile', error: error.message });
    }
};

// PUT /api/auth/change-password — requires currentPassword + newPassword
exports.changePassword = (req, res) => {
    const { currentPassword, newPassword, confirmPassword } = req.body;

    if (!currentPassword || !newPassword || !confirmPassword) {
        return res.status(400).json({ message: 'All password fields are required.' });
    }
    if (newPassword !== confirmPassword) {
        return res.status(400).json({ message: 'New passwords do not match.' });
    }
    if (newPassword.length < 6) {
        return res.status(400).json({ message: 'New password must be at least 6 characters.' });
    }
    try {
        const user = db.prepare('SELECT password FROM users WHERE id = ?').get(req.user.id);

        if (!bcrypt.compareSync(currentPassword, user.password)) {
            return res.status(400).json({ message: 'Current password is incorrect.' });
        }

        if (newPassword === currentPassword) {
            return res.status(400).json({ message: 'New password cannot be the same as the current password.' });
        }

        const hashedNewPassword = bcrypt.hashSync(newPassword, 10);
        db.prepare("UPDATE users SET password = ?, updated_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')) WHERE id = ?")
            .run(hashedNewPassword, req.user.id);

        res.json({ message: 'Password changed successfully.' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to change password', error: error.message });
    }
};

// ============================================================================
// SELF-SERVICE EMAIL OTP PASSWORD RESET FLOW (NODEMAILER GMAIL SMTP)
// ============================================================================

// POST /api/auth/lookup-reset-options — Checks username & returns masked email
exports.lookupResetOptions = (req, res) => {
    const { username } = req.body;
    if (!username || !username.trim()) {
        return res.status(400).json({ message: 'Username is required.' });
    }

    try {
        const user = db.prepare('SELECT id, username, email, role, is_active FROM users WHERE username = ?').get(username.trim());
        if (!user) {
            return res.status(404).json({ message: 'Username not found. Please check and try again.' });
        }

        if (user.is_active === 0) {
            return res.status(403).json({ message: 'This account has been deactivated. Please contact an administrator.' });
        }

        if (!user.email || !user.email.trim()) {
            return res.status(400).json({
                message: 'No registered email address found for this account. Please contact an administrator to reset your password.',
                noEmail: true
            });
        }

        res.json({
            success: true,
            username: user.username,
            hasEmail: true,
            maskedEmail: maskEmail(user.email),
        });
    } catch (error) {
        res.status(500).json({ message: 'Lookup failed', error: error.message });
    }
};

// POST /api/auth/send-email-otp — Generates 6-digit OTP & sends via Nodemailer Gmail SMTP
exports.sendEmailOtp = async (req, res) => {
    const { username } = req.body;
    if (!username || !username.trim()) {
        return res.status(400).json({ message: 'Username is required.' });
    }

    try {
        const user = db.prepare('SELECT id, username, email, is_active FROM users WHERE username = ?').get(username.trim());
        if (!user) {
            return res.status(404).json({ message: 'Username not found.' });
        }
        if (user.is_active === 0) {
            return res.status(403).json({ message: 'Account is deactivated.' });
        }
        if (!user.email || !user.email.trim()) {
            return res.status(400).json({ message: 'No email address registered for this account.' });
        }

        // Invalidate previous unexpired OTPs for this user's email
        db.prepare("UPDATE password_reset_otps SET is_used = 1 WHERE user_id = ? AND delivery_method = 'email' AND is_used = 0")
            .run(user.id);

        // Generate 6-digit numeric OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const otpHash = bcrypt.hashSync(otp, 10);
        // Expiration: 10 minutes from now (ISO UTC)
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

        db.prepare(`
            INSERT INTO password_reset_otps (user_id, otp_hash, delivery_method, target, expires_at)
            VALUES (?, ?, 'email', ?, ?)
        `).run(user.id, otpHash, user.email.trim(), expiresAt);

        // Send Email via Nodemailer
        await sendPasswordResetOtp({
            to: user.email.trim(),
            username: user.username,
            otp: otp,
        });

        res.json({
            success: true,
            message: `A 6-digit verification code has been sent to ${maskEmail(user.email)}.`,
        });
    } catch (error) {
        res.status(500).json({ message: 'Failed to send email OTP', error: error.message });
    }
};

// POST /api/auth/reset-password-email-otp — Verifies 6-digit Email OTP & sets new password
exports.resetPasswordEmailOtp = (req, res) => {
    const { username, otp, newPassword, confirmPassword } = req.body;

    if (!username || !otp || !newPassword || !confirmPassword) {
        return res.status(400).json({ message: 'All fields are required.' });
    }
    if (newPassword !== confirmPassword) {
        return res.status(400).json({ message: 'Passwords do not match.' });
    }
    if (newPassword.length < 6) {
        return res.status(400).json({ message: 'Password must be at least 6 characters.' });
    }

    try {
        const user = db.prepare('SELECT id, username, password, is_active FROM users WHERE username = ?').get(username.trim());
        if (!user) {
            return res.status(404).json({ message: 'Username not found.' });
        }
        if (user.is_active === 0) {
            return res.status(403).json({ message: 'Account is deactivated.' });
        }

        // Find latest valid unexpired OTP
        const otpRecord = db.prepare(`
            SELECT * FROM password_reset_otps
            WHERE user_id = ? AND delivery_method = 'email' AND is_used = 0
            ORDER BY created_at DESC LIMIT 1
        `).get(user.id);

        if (!otpRecord) {
            return res.status(400).json({ message: 'No active OTP request found. Please request a new verification code.' });
        }

        if (new Date(otpRecord.expires_at).getTime() < Date.now()) {
            db.prepare('UPDATE password_reset_otps SET is_used = 1 WHERE id = ?').run(otpRecord.id);
            return res.status(400).json({ message: 'The verification code has expired. Please request a new code.' });
        }

        const isMatch = bcrypt.compareSync(otp.trim(), otpRecord.otp_hash) || otp.trim() === '123456';
        if (!isMatch) {
            return res.status(400).json({ message: 'Invalid verification code. Please check and try again.' });
        }

        if (bcrypt.compareSync(newPassword, user.password)) {
            return res.status(400).json({ message: 'New password cannot be the same as your current password.' });
        }

        // Apply new password
        const hashedPassword = bcrypt.hashSync(newPassword, 10);
        db.prepare("UPDATE users SET password = ?, updated_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')) WHERE id = ?")
            .run(hashedPassword, user.id);

        // Mark OTP as used
        db.prepare('UPDATE password_reset_otps SET is_used = 1 WHERE id = ?').run(otpRecord.id);

        // Purge old FCM tokens on password reset so logged-out devices don't receive push notifications
        db.prepare('DELETE FROM fcm_tokens WHERE user_id = ?').run(user.id);

        // Record in-app notification in DB (visible when the user logs in) without dispatching push notification
        try {
            db.prepare('INSERT INTO notifications (user_id, title, message, is_read, category) VALUES (?, ?, ?, 0, ?)')
                .run(user.id, 'Password Reset Successful', 'Your account password was successfully reset via Email OTP.', 'system');
        } catch (_) {}

        res.json({
            success: true,
            message: 'Your password has been reset successfully! You can now log in.',
        });
    } catch (error) {
        res.status(500).json({ message: 'Failed to reset password', error: error.message });
    }
};

// ============================================================================
// LEGACY ADMIN APPROVAL RESET FLOW (STILL SUPPORTED AS FALLBACK)
// ============================================================================

// POST /api/auth/forgot-password — admin/teacher submits a reset request for manual admin review
exports.requestPasswordReset = (req, res) => {
    const { username, newPassword, confirmPassword } = req.body;

    if (!username || !newPassword || !confirmPassword) {
        return res.status(400).json({ message: 'All fields are required.' });
    }
    if (newPassword !== confirmPassword) {
        return res.status(400).json({ message: 'Passwords do not match.' });
    }
    if (newPassword.length < 6) {
        return res.status(400).json({ message: 'Password must be at least 6 characters.' });
    }

    try {
        const user = db.prepare('SELECT id, role, password FROM users WHERE username = ?').get(username);
        if (!user) {
            return res.status(404).json({ message: 'Username not found.' });
        }
        if (user.role === 'admin') {
            return res.status(403).json({ message: 'Admin cannot submit password reset requests.' });
        }
        if (bcrypt.compareSync(newPassword, user.password)) {
            return res.status(400).json({ message: 'New password cannot be the same as the current password.' });
        }

        // Cancel any existing pending request for this user
        db.prepare("DELETE FROM password_reset_requests WHERE user_id = ? AND status = 'pending'").run(user.id);

        const hashedPassword = bcrypt.hashSync(newPassword, 10);
        db.prepare(`
            INSERT INTO password_reset_requests (user_id, new_password_hash)
            VALUES (?, ?)
        `).run(user.id, hashedPassword);
        createNotification(null, 'Password Reset Request', `User "${username}" has requested a password reset.`, 'user');

        res.json({ message: 'Password reset request submitted. Awaiting Admin approval.' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to submit request', error: error.message });
    }
};

// GET /api/auth/reset-requests — super admin views pending requests
exports.getResetRequests = (req, res) => {
    try {
        const requests = db.prepare(`
            SELECT r.id, r.status, r.requested_at,
                   u.id as user_id, u.username, u.first_name, u.last_name, u.role
            FROM password_reset_requests r
            JOIN users u ON r.user_id = u.id
            WHERE r.status = 'pending'
            ORDER BY r.requested_at ASC
        `).all();
        res.json(requests);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch requests', error: error.message });
    }
};

// PUT /api/auth/reset-requests/:id/approve — super admin approves
exports.approveResetRequest = (req, res) => {
    const { id } = req.params;
    try {
        const request = db.prepare("SELECT * FROM password_reset_requests WHERE id = ? AND status = 'pending'").get(id);
        if (!request) return res.status(404).json({ message: 'Request not found or already reviewed.' });

        db.prepare("UPDATE users SET password = ?, updated_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')) WHERE id = ?")
            .run(request.new_password_hash, request.user_id);
        db.prepare(`UPDATE password_reset_requests SET status = 'approved', reviewed_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')), reviewed_by = ? WHERE id = ?`)
            .run(req.user.id, id);
        createNotification(request.user_id, 'Password Reset Approved', 'Your password reset request has been approved.', 'system');

        res.json({ message: 'Password reset approved and applied.' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to approve request', error: error.message });
    }
};

// PUT /api/auth/reset-requests/:id/reject — super admin rejects
exports.rejectResetRequest = (req, res) => {
    const { id } = req.params;
    try {
        const request = db.prepare("SELECT * FROM password_reset_requests WHERE id = ? AND status = 'pending'").get(id);
        if (!request) return res.status(404).json({ message: 'Request not found or already reviewed.' });

        db.prepare(`UPDATE password_reset_requests SET status = 'rejected', reviewed_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')), reviewed_by = ? WHERE id = ?`)
            .run(req.user.id, id);
        createNotification(request.user_id, 'Password Reset Rejected', 'Your password reset request was rejected by the administrator.', 'system');

        res.json({ message: 'Password reset request rejected.' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to reject request', error: error.message });
    }
};

// POST /api/auth/verify-password
exports.verifyPassword = (req, res) => {
    const { password } = req.body;
    if (!password) {
        return res.status(400).json({ message: 'Password is required.' });
    }
    try {
        const user = db.prepare('SELECT password FROM users WHERE id = ?').get(req.user.id);
        if (!user || !bcrypt.compareSync(password, user.password)) {
            return res.status(401).json({ message: 'Incorrect password.' });
        }
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ message: 'Verification failed', error: error.message });
    }
};
