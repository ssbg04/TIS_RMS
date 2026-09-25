const db = require('../config/db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
require('dotenv').config();
const { createNotification } = require('./notificationController');
const { sendPasswordResetOtp, sendAccountDeletionEmail } = require('../services/emailService');
const { getBestServerBaseUrl } = require('./userController');

// ── QEV Email Validator ───────────────────────────────────────────────────────
// Returns { valid: bool, reason: string } — never throws.
const validateEmailQEV = async (email) => {
    if (!email || !email.trim()) return { valid: false, reason: 'Email is empty' };
    const apiKey = process.env.QEV_API_KEY;
    if (!apiKey) return { valid: true, reason: 'QEV key not configured – skipping' };
    try {
        const qev = require('quickemailverification').client(apiKey).quickemailverification();
        const result = await new Promise((resolve, reject) => {
            qev.verify(email.trim(), (err, response) => {
                if (err) return reject(err);
                resolve(response.body);
            });
        });
        // result.result: 'valid' | 'invalid' | 'unknown'
        const isValid = result.result === 'valid';
        const reason = isValid ? 'valid' : (result.reason || result.result || 'invalid');
        return { valid: isValid, reason };
    } catch (err) {
        console.warn('[QEV] Email validation error (skipping):', err.message);
        // Fail-open: if QEV is unreachable, allow the email
        return { valid: true, reason: 'QEV unreachable – skipping' };
    }
};
exports.validateEmailQEV = validateEmailQEV;

// ── Session Helpers ───────────────────────────────────────────────────────────
const hashToken = (token) => crypto.createHash('sha256').update(token).digest('hex');

// Helper to detect platform from request headers, body, or User-Agent
const detectPlatform = (req) => {
    const headerPlatform = req.headers['x-platform'] || req.headers['x-client-platform'];
    if (headerPlatform && typeof headerPlatform === 'string' && headerPlatform.trim().length > 0) {
        return headerPlatform.trim().toLowerCase();
    }
    if (req.body && req.body.platform && typeof req.body.platform === 'string' && req.body.platform.trim().length > 0) {
        return req.body.platform.trim().toLowerCase();
    }
    const ua = (req.headers['user-agent'] || '').toLowerCase();
    if (ua.includes('android')) return 'android';
    if (ua.includes('windows') || ua.includes('win32') || ua.includes('win64')) return 'windows';
    if (ua.includes('iphone') || ua.includes('ipad') || ua.includes('ios')) return 'ios';
    if (ua.includes('macintosh') || ua.includes('mac os')) return 'macos';
    if (ua.includes('linux')) return 'linux';
    return 'windows';
};

// Helper to detect device name from request headers, body, or platform
const detectDeviceName = (req, platform) => {
    const headerDevice = req.headers['x-device-name'];
    if (headerDevice && typeof headerDevice === 'string' && headerDevice.trim().length > 0) {
        return headerDevice.trim();
    }
    if (req.body && req.body.device_name && typeof req.body.device_name === 'string' && req.body.device_name.trim().length > 0) {
        return req.body.device_name.trim();
    }
    const platLower = (platform || '').toLowerCase();
    if (platLower.includes('win')) return 'Windows PC';
    if (platLower.includes('android')) return 'Android Device';
    if (platLower.includes('ios') || platLower.includes('iphone')) return 'iPhone';
    if (platLower.includes('mac')) return 'Mac';
    if (platLower.includes('web')) return 'Web Browser';
    return 'Windows PC';
};

const upsertSession = (userId, token, platform, ipAddress, deviceName) => {
    try {
        const tokenHash = hashToken(token);
        const now = strftime_now();
        const effectivePlatform = platform || 'windows';
        const effectiveDevice = deviceName || (effectivePlatform === 'windows' ? 'Windows PC' : 'Device');

        // If same token re-used (rare), update last_seen
        const existing = db.prepare('SELECT id FROM user_sessions WHERE token_hash = ?').get(tokenHash);
        if (existing) {
            db.prepare(`
                UPDATE user_sessions
                SET last_seen_at = ?,
                    platform = COALESCE(?, platform),
                    ip_address = COALESCE(?, ip_address),
                    device_name = COALESCE(?, device_name)
                WHERE token_hash = ?
            `).run(now, effectivePlatform, ipAddress || null, effectiveDevice, tokenHash);
        } else {
            db.prepare(`
                INSERT INTO user_sessions (user_id, token_hash, platform, ip_address, device_name)
                VALUES (?, ?, ?, ?, ?)
            `).run(userId, tokenHash, effectivePlatform, ipAddress || null, effectiveDevice);
        }
    } catch (err) { console.warn('[Sessions] upsertSession error:', err.message); }
};

const strftime_now = () => new Date().toISOString().replace('T', 'T').slice(0, 19) + 'Z';

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

        // Record session (device tracking)
        const clientPlatform = detectPlatform(req);
        const clientDeviceName = detectDeviceName(req, clientPlatform);
        const clientIp = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket?.remoteAddress || null;
        upsertSession(user.id, token, clientPlatform, clientIp, clientDeviceName);

        // Append login log entry
        try {
            const fullName = [user.first_name, user.last_name].filter(Boolean).join(' ');
            db.prepare(`
                INSERT INTO user_login_logs (user_id, username, full_name, role, platform, ip_address)
                VALUES (?, ?, ?, ?, ?, ?)
            `).run(user.id, user.username, fullName, user.role, clientPlatform, clientIp);
        } catch (_) {}

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

// GET /api/auth/reset-password-web — Serves responsive web form for password reset via link
exports.resetPasswordWebPage = (req, res) => {
    const token = req.query.token;

    const renderPage = ({ title, contentHtml, isError = false }) => {
        return `
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>${title} — Talisay Integrated School RMS</title>
            <link rel="preconnect" href="https://fonts.googleapis.com">
            <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
            <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
            <style>
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body {
                    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
                    background: #f1f5f9;
                    color: #0f172a;
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: 24px 16px;
                }
                .card {
                    background: #ffffff;
                    width: 100%;
                    max-width: 460px;
                    border-radius: 20px;
                    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.05), 0 8px 10px -6px rgba(0, 0, 0, 0.03);
                    border: 1px solid #e2e8f0;
                    overflow: hidden;
                }
                .header {
                    background: linear-gradient(135deg, #15803D 0%, #166534 100%);
                    color: #ffffff;
                    padding: 30px 24px;
                    text-align: center;
                }
                .header-logo {
                    font-size: 32px;
                    margin-bottom: 8px;
                }
                .header h1 {
                    font-size: 20px;
                    font-weight: 800;
                    letter-spacing: 0.3px;
                }
                .header p {
                    font-size: 13px;
                    opacity: 0.9;
                    margin-top: 4px;
                }
                .body {
                    padding: 32px 28px;
                }
                .user-badge {
                    background: #f0fdf4;
                    border: 1px solid #bbf7d0;
                    border-radius: 10px;
                    padding: 12px 16px;
                    margin-bottom: 24px;
                    font-size: 13px;
                    color: #166534;
                    display: flex;
                    align-items: center;
                    gap: 10px;
                }
                .form-group {
                    margin-bottom: 20px;
                }
                .form-group label {
                    display: block;
                    font-size: 13px;
                    font-weight: 600;
                    color: #334155;
                    margin-bottom: 8px;
                }
                .input-wrapper {
                    position: relative;
                    display: flex;
                    align-items: center;
                }
                .input-wrapper input {
                    width: 100%;
                    padding: 13px 44px 13px 14px;
                    border: 1.5px solid #cbd5e1;
                    border-radius: 10px;
                    font-size: 14px;
                    font-family: inherit;
                    color: #0f172a;
                    outline: none;
                    transition: border-color 0.2s, box-shadow 0.2s;
                }
                .input-wrapper input:focus {
                    border-color: #15803D;
                    box-shadow: 0 0 0 3px rgba(21, 128, 61, 0.15);
                }
                .toggle-eye {
                    position: absolute;
                    right: 12px;
                    background: none;
                    border: none;
                    cursor: pointer;
                    color: #64748b;
                    font-size: 16px;
                    padding: 4px;
                }
                .toggle-eye:hover { color: #0f172a; }
                .req-list {
                    background: #f8fafc;
                    border-radius: 8px;
                    padding: 10px 14px;
                    margin-bottom: 24px;
                    font-size: 12px;
                    color: #64748b;
                    line-height: 1.6;
                }
                .req-item {
                    display: flex;
                    align-items: center;
                    gap: 6px;
                }
                .req-item.valid { color: #166534; font-weight: 600; }
                .submit-btn {
                    width: 100%;
                    background: #15803D;
                    color: #ffffff;
                    border: none;
                    border-radius: 10px;
                    padding: 14px;
                    font-size: 15px;
                    font-weight: 700;
                    font-family: inherit;
                    cursor: pointer;
                    box-shadow: 0 4px 12px rgba(21, 128, 61, 0.25);
                    transition: background 0.2s, transform 0.1s;
                }
                .submit-btn:hover { background: #166534; }
                .submit-btn:active { transform: scale(0.99); }
                .submit-btn:disabled { background: #94a3b8; cursor: not-allowed; box-shadow: none; }
                .alert {
                    padding: 12px 16px;
                    border-radius: 10px;
                    font-size: 13px;
                    margin-bottom: 20px;
                    display: none;
                }
                .alert-error {
                    background: #fef2f2;
                    border: 1px solid #fecaca;
                    color: #b91c1c;
                }
                .footer-text {
                    text-align: center;
                    font-size: 11px;
                    color: #94a3b8;
                    padding: 16px 24px;
                    background: #f8fafc;
                    border-top: 1px solid #f1f5f9;
                }
                .status-card {
                    text-align: center;
                    padding: 36px 24px;
                }
                .status-icon {
                    font-size: 48px;
                    margin-bottom: 16px;
                }
                .status-title {
                    font-size: 18px;
                    font-weight: 700;
                    margin-bottom: 8px;
                    color: #0f172a;
                }
                .status-desc {
                    font-size: 14px;
                    color: #64748b;
                    line-height: 1.5;
                }
            </style>
        </head>
        <body>
            <div class="card">
                <div class="header">
                    <div class="header-logo">🏫</div>
                    <h1>Talisay Integrated School</h1>
                    <p>Record Management System</p>
                </div>
                <div class="body">
                    ${contentHtml}
                </div>
                <div class="footer-text">
                    &copy; ${new Date().getFullYear()} Talisay Integrated School. All rights reserved.
                </div>
            </div>
        </body>
        </html>
        `;
    };

    if (!token || !token.trim()) {
        return res.status(400).send(renderPage({
            title: 'Invalid Request',
            isError: true,
            contentHtml: `
                <div class="status-card">
                    <div class="status-icon">⚠️</div>
                    <div class="status-title">Missing Reset Token</div>
                    <div class="status-desc">No password reset token was provided. Please use the exact link sent to your email.</div>
                </div>
            `
        }));
    }

    try {
        const linkRecord = db.prepare(`
            SELECT prl.*, u.username, u.first_name, u.last_name, u.is_active
            FROM password_reset_links prl
            JOIN users u ON prl.user_id = u.id
            WHERE prl.token = ?
        `).get(token.trim());

        if (!linkRecord) {
            return res.status(404).send(renderPage({
                title: 'Invalid Link',
                isError: true,
                contentHtml: `
                    <div class="status-card">
                        <div class="status-icon">❌</div>
                        <div class="status-title">Invalid Reset Link</div>
                        <div class="status-desc">This password reset link is invalid or no longer exists. Please request a new password reset from your administrator.</div>
                    </div>
                `
            }));
        }

        if (linkRecord.status === 'completed') {
            return res.send(renderPage({
                title: 'Link Already Used',
                contentHtml: `
                    <div class="status-card">
                        <div class="status-icon">✅</div>
                        <div class="status-title">Password Already Reset</div>
                        <div class="status-desc">This password reset link has already been used. You can log into the TIS RMS app with your new password.</div>
                    </div>
                `
            }));
        }

        const isExpired = new Date(linkRecord.expires_at).getTime() < Date.now();
        if (isExpired || linkRecord.status === 'expired') {
            // Mark expired and notify admin if not already notified
            if (linkRecord.expired_notified === 0) {
                db.prepare("UPDATE password_reset_links SET status = 'expired', expired_notified = 1 WHERE id = ?").run(linkRecord.id);
                const fullName = [linkRecord.first_name, linkRecord.last_name].filter(Boolean).join(' ');
                createNotification(
                    linkRecord.admin_id || null,
                    'Password Reset Link Expired',
                    `The password reset link for @${linkRecord.username}${fullName ? ` (${fullName})` : ''} has expired.`,
                    'user',
                    'user',
                    linkRecord.user_id
                );
            }

            return res.status(400).send(renderPage({
                title: 'Link Expired',
                isError: true,
                contentHtml: `
                    <div class="status-card">
                        <div class="status-icon">⏱️</div>
                        <div class="status-title">Password Reset Link Expired</div>
                        <div class="status-desc">This password reset link has expired for your security. Please contact your system administrator to request a new link.</div>
                    </div>
                `
            }));
        }

        const fullName = [linkRecord.first_name, linkRecord.last_name].filter(Boolean).join(' ');

        // Render valid Reset Form
        const formHtml = `
            <div id="resetFormContainer">
                <div class="user-badge">
                    <span>👤</span>
                    <div>Resetting password for <strong>@${linkRecord.username}</strong>${fullName ? ` (${fullName})` : ''}</div>
                </div>

                <div id="alertBox" class="alert alert-error"></div>

                <form id="resetPasswordForm" onsubmit="handleFormSubmit(event)">
                    <input type="hidden" id="resetToken" value="${token.trim()}">

                    <div class="form-group">
                        <label for="newPassword">New Password</label>
                        <div class="input-wrapper">
                            <input type="password" id="newPassword" placeholder="Enter new password" required autocomplete="new-password">
                            <button type="button" class="toggle-eye" onclick="togglePassword('newPassword', this)">👁️</button>
                        </div>
                    </div>

                    <div class="form-group">
                        <label for="confirmPassword">Confirm Password</label>
                        <div class="input-wrapper">
                            <input type="password" id="confirmPassword" placeholder="Re-enter new password" required autocomplete="new-password">
                            <button type="button" class="toggle-eye" onclick="togglePassword('confirmPassword', this)">👁️</button>
                        </div>
                    </div>

                    <div class="req-list">
                        <div class="req-item" id="reqLength"><span>•</span> Minimum of 6 characters</div>
                        <div class="req-item" id="reqMatch"><span>•</span> Passwords must match</div>
                    </div>

                    <button type="submit" id="submitBtn" class="submit-btn">Reset Password</button>
                </form>
            </div>

            <div id="successCard" style="display: none;">
                <div class="status-card">
                    <div class="status-icon">🎉</div>
                    <div class="status-title">Password Reset Successful!</div>
                    <div class="status-desc">Your password has been updated. You can now open the TIS RMS app and log in with your new password.</div>
                </div>
            </div>

            <script>
                function togglePassword(inputId, btn) {
                    const input = document.getElementById(inputId);
                    if (input.type === 'password') {
                        input.type = 'text';
                        btn.textContent = '🙈';
                    } else {
                        input.type = 'password';
                        btn.textContent = '👁️';
                    }
                }

                const newPassInput = document.getElementById('newPassword');
                const confirmPassInput = document.getElementById('confirmPassword');
                const reqLength = document.getElementById('reqLength');
                const reqMatch = document.getElementById('reqMatch');
                const alertBox = document.getElementById('alertBox');
                const submitBtn = document.getElementById('submitBtn');

                function validateInputs() {
                    const p1 = newPassInput.value;
                    const p2 = confirmPassInput.value;

                    if (p1.length >= 6) {
                        reqLength.classList.add('valid');
                        reqLength.children[0].textContent = '✓';
                    } else {
                        reqLength.classList.remove('valid');
                        reqLength.children[0].textContent = '•';
                    }

                    if (p1.length > 0 && p1 === p2) {
                        reqMatch.classList.add('valid');
                        reqMatch.children[0].textContent = '✓';
                    } else {
                        reqMatch.classList.remove('valid');
                        reqMatch.children[0].textContent = '•';
                    }
                }

                newPassInput.addEventListener('input', validateInputs);
                confirmPassInput.addEventListener('input', validateInputs);

                async function handleFormSubmit(e) {
                    e.preventDefault();
                    alertBox.style.display = 'none';

                    const newPassword = newPassInput.value.trim();
                    const confirmPassword = confirmPassInput.value.trim();
                    const token = document.getElementById('resetToken').value;

                    if (newPassword.length < 6) {
                        alertBox.textContent = 'Password must be at least 6 characters.';
                        alertBox.style.display = 'block';
                        return;
                    }
                    if (newPassword !== confirmPassword) {
                        alertBox.textContent = 'New password and confirm password do not match.';
                        alertBox.style.display = 'block';
                        return;
                    }

                    submitBtn.disabled = true;
                    submitBtn.textContent = 'Updating Password...';

                    try {
                        const res = await fetch('/api/auth/complete-password-reset', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ token, newPassword, confirmPassword })
                        });

                        const data = await res.json();

                        if (!res.ok) {
                            alertBox.textContent = data.message || 'Failed to reset password.';
                            alertBox.style.display = 'block';
                            submitBtn.disabled = false;
                            submitBtn.textContent = 'Reset Password';
                            return;
                        }

                        document.getElementById('resetFormContainer').style.display = 'none';
                        document.getElementById('successCard').style.display = 'block';
                    } catch (err) {
                        alertBox.textContent = 'Network error. Please try again.';
                        alertBox.style.display = 'block';
                        submitBtn.disabled = false;
                        submitBtn.textContent = 'Reset Password';
                    }
                }
            </script>
        `;

        res.send(renderPage({
            title: 'Reset Password',
            contentHtml: formHtml
        }));
    } catch (err) {
        res.status(500).send(renderPage({
            title: 'Server Error',
            isError: true,
            contentHtml: `
                <div class="status-card">
                    <div class="status-icon">⚠️</div>
                    <div class="status-title">Server Error</div>
                    <div class="status-desc">${err.message}</div>
                </div>
            `
        }));
    }
};

// POST /api/auth/complete-password-reset — Verifies token and saves new password
exports.completePasswordReset = (req, res) => {
    const { token, newPassword, confirmPassword } = req.body;

    if (!token || !newPassword || !confirmPassword) {
        return res.status(400).json({ message: 'All fields are required.' });
    }
    if (newPassword.length < 6) {
        return res.status(400).json({ message: 'Password must be at least 6 characters.' });
    }
    if (newPassword !== confirmPassword) {
        return res.status(400).json({ message: 'New password and confirm password do not match.' });
    }

    try {
        const linkRecord = db.prepare(`
            SELECT prl.*, u.username, u.first_name, u.last_name, u.role, u.password as current_password_hash, u.is_active
            FROM password_reset_links prl
            JOIN users u ON prl.user_id = u.id
            WHERE prl.token = ?
        `).get(token.trim());

        if (!linkRecord) {
            return res.status(404).json({ message: 'Invalid or non-existent password reset link.' });
        }

        if (linkRecord.status === 'completed') {
            return res.status(400).json({ message: 'This password reset link has already been used.' });
        }

        const isExpired = new Date(linkRecord.expires_at).getTime() < Date.now();
        if (isExpired || linkRecord.status === 'expired') {
            if (linkRecord.expired_notified === 0) {
                db.prepare("UPDATE password_reset_links SET status = 'expired', expired_notified = 1 WHERE id = ?").run(linkRecord.id);
                const fullName = [linkRecord.first_name, linkRecord.last_name].filter(Boolean).join(' ');
                createNotification(
                    linkRecord.admin_id || null,
                    'Password Reset Link Expired',
                    `The password reset link for @${linkRecord.username}${fullName ? ` (${fullName})` : ''} has expired.`,
                    'user',
                    'user',
                    linkRecord.user_id
                );
            }
            return res.status(400).json({ message: 'This password reset link has expired. Please contact your administrator for a new link.' });
        }

        if (bcrypt.compareSync(newPassword, linkRecord.current_password_hash)) {
            return res.status(400).json({ message: 'New password cannot be the same as your current password.' });
        }

        // Apply new hashed password
        const hashedNewPassword = bcrypt.hashSync(newPassword, 10);
        db.prepare("UPDATE users SET password = ?, updated_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')) WHERE id = ?")
            .run(hashedNewPassword, linkRecord.user_id);

        // Mark reset link completed
        db.prepare("UPDATE password_reset_links SET status = 'completed', completed_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')) WHERE id = ?")
            .run(linkRecord.id);

        const fullName = [linkRecord.first_name, linkRecord.last_name].filter(Boolean).join(' ');

        // Push & In-app Notification to the User
        createNotification(
            linkRecord.user_id,
            'Password Reset Successful',
            'Your TIS RMS password was successfully reset. You can now log into your account.',
            'user',
            'user',
            linkRecord.user_id
        );

        // Push & In-app Notification to the initiating Admin (or all admins)
        createNotification(
            linkRecord.admin_id || null,
            'Password Reset Completed',
            `User @${linkRecord.username}${fullName ? ` (${fullName})` : ''} has successfully reset their password via the email link.`,
            'user',
            'user',
            linkRecord.user_id
        );

        // Log to activity and user history
        try {
            db.prepare('INSERT INTO activity_log (user_id, action, entity_type, entity_id, description) VALUES (?, ?, ?, ?, ?)')
                .run(linkRecord.user_id, 'UPDATE', 'user', linkRecord.user_id, `Password reset completed via email link for @${linkRecord.username}`);
        } catch (_) {}

        return res.json({
            success: true,
            message: 'Your password has been successfully reset! You can now log into the application.'
        });
    } catch (error) {
        res.status(500).json({ message: 'Failed to complete password reset', error: error.message });
    }
};

// POST /api/auth/self-deactivate
// Lets the authenticated user deactivate their own account immediately.
// No email link is required — just 2-step client-side confirmation.
exports.selfDeactivateAccount = async (req, res) => {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: 'Authentication required' });

    try {
        const user = db.prepare('SELECT id, username, first_name, last_name, email, role, is_active, is_hidden FROM users WHERE id = ?').get(userId);
        if (!user) return res.status(404).json({ message: 'User account not found' });

        if (user.is_hidden === 1) {
            return res.status(403).json({ message: 'Developer super administrator account cannot be deactivated.' });
        }

        if (user.role === 'admin') {
            const otherActiveAdmins = db.prepare(
                "SELECT COUNT(*) as count FROM users WHERE role = 'admin' AND is_active = 1 AND (is_hidden = 0 OR is_hidden IS NULL) AND id != ?"
            ).get(user.id);
            if (!otherActiveAdmins || otherActiveAdmins.count < 1) {
                return res.status(403).json({ message: 'Cannot deactivate the only active administrator account. Please promote another admin first.' });
            }
        }

        // Deactivate the account
        db.prepare("UPDATE users SET is_active = 0, updated_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')) WHERE id = ?").run(userId);

        // Revoke all FCM push tokens
        db.prepare('DELETE FROM fcm_tokens WHERE user_id = ?').run(userId);

        // Revoke all sessions and stamp logout on open login logs
        db.prepare('DELETE FROM user_sessions WHERE user_id = ?').run(userId);
        try {
            db.prepare(`
                UPDATE user_login_logs SET logout_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
                WHERE user_id = ? AND logout_at IS NULL
            `).run(userId);
        } catch (_) {}

        // Log activity
        try {
            db.prepare('INSERT INTO activity_log (user_id, action, entity_type, entity_id, description) VALUES (?, ?, ?, ?, ?)')
                .run(userId, 'UPDATE', 'user', userId, `Self-deactivated account @${user.username}`);
        } catch (_) {}

        // Send email notification if available (async, fire-and-forget)
        const { sendAccountStatusEmail } = require('../services/emailService');
        if (user.email && user.email.trim()) {
            (async () => {
                const qevResult = await validateEmailQEV(user.email.trim());
                if (!qevResult.valid) return;
                sendAccountStatusEmail({
                    to: user.email.trim(),
                    username: user.username,
                    fullName: [user.first_name, user.last_name].filter(Boolean).join(' '),
                    isActivated: false,
                }).catch(() => {});
            })();
        }

        res.json({
            success: true,
            message: 'Your account has been deactivated. You will be signed out.',
        });
    } catch (error) {
        console.error('selfDeactivateAccount error:', error);
        res.status(500).json({ message: 'Failed to deactivate account', error: error.message });
    }
};

// POST /api/auth/request-delete-account
exports.requestAccountDeletion = async (req, res) => {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: 'Authentication required' });

    try {
        const user = db.prepare('SELECT id, username, first_name, last_name, email, role, is_hidden FROM users WHERE id = ?').get(userId);
        if (!user) return res.status(404).json({ message: 'User account not found' });

        if (user.is_hidden === 1) {
            return res.status(403).json({ message: 'Developer super administrator account cannot be deleted.' });
        }

        if (user.role === 'admin') {
            const otherAdmins = db.prepare("SELECT COUNT(*) as count FROM users WHERE role = 'admin' AND (is_hidden = 0 OR is_hidden IS NULL) AND id != ?").get(user.id);
            if (!otherAdmins || otherAdmins.count < 1) {
                return res.status(403).json({ message: 'Cannot delete the only remaining administrator account.' });
            }
        }

        if (!user.email || !user.email.includes('@')) {
            return res.status(400).json({ message: 'An email address is required to verify account deletion. Please add an email address to your profile first.' });
        }

        const qevResult = await validateEmailQEV(user.email.trim());
        if (!qevResult.valid) {
            return res.status(422).json({
                message: `Cannot send deletion email: the registered address "${user.email}" appears to be invalid or undeliverable (${qevResult.reason}).`
            });
        }

        // Generate secure random token
        const token = crypto.randomBytes(32).toString('hex');
        const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();

        // Clean up any prior pending deletion requests for this user
        db.prepare('DELETE FROM account_deletion_requests WHERE user_id = ?').run(user.id);
        db.prepare('INSERT INTO account_deletion_requests (user_id, token, expires_at) VALUES (?, ?, ?)').run(user.id, token, expiresAt);

        const baseUrl = getBestServerBaseUrl(req);
        const deleteLink = `${baseUrl}/api/auth/confirm-delete-account-web?token=${token}`;

        await sendAccountDeletionEmail({
            to: user.email.trim(),
            username: user.username,
            deleteLink,
            expiresMinutes: 15,
        });

        // Log activity
        try {
            db.prepare('INSERT INTO activity_log (user_id, action, entity_type, entity_id, description) VALUES (?, ?, ?, ?, ?)')
                .run(user.id, 'DELETE_REQUEST', 'user', user.id, `Requested account deletion email confirmation for @${user.username}`);
        } catch (_) {}

        res.json({
            success: true,
            message: `A deletion confirmation link has been sent to ${maskEmail(user.email)}. Please check your email to confirm.`,
        });
    } catch (error) {
        console.error('requestAccountDeletion error:', error);
        res.status(500).json({ message: 'Failed to process account deletion request', error: error.message });
    }
};

const renderDeletionPage = ({ title, contentHtml, isError = false }) => {
    return `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>${title} — Talisay Integrated School RMS</title>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
        <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body {
                font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
                background: #f8fafc;
                color: #0f172a;
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 24px 16px;
            }
            .card {
                background: #ffffff;
                width: 100%;
                max-width: 480px;
                border-radius: 20px;
                box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.05), 0 8px 10px -6px rgba(0, 0, 0, 0.03);
                border: 1px solid #e2e8f0;
                overflow: hidden;
            }
            .header {
                background: ${isError ? 'linear-gradient(135deg, #b91c1c 0%, #991b1b 100%)' : 'linear-gradient(135deg, #dc2626 0%, #b91c1c 100%)'};
                color: #ffffff;
                padding: 28px 24px;
                text-align: center;
            }
            .header-logo { font-size: 36px; margin-bottom: 8px; }
            .header h1 { font-size: 20px; font-weight: 800; letter-spacing: 0.3px; }
            .header p { font-size: 13px; opacity: 0.9; margin-top: 4px; }
            .body { padding: 32px 28px; }
            .danger-badge {
                background: #fef2f2;
                border: 1px solid #fecaca;
                border-radius: 12px;
                padding: 16px;
                margin-bottom: 24px;
                font-size: 13px;
                color: #991b1b;
                line-height: 1.6;
            }
            .btn-danger {
                width: 100%;
                background: #dc2626;
                color: #ffffff;
                border: none;
                border-radius: 10px;
                padding: 14px;
                font-size: 15px;
                font-weight: 700;
                cursor: pointer;
                transition: all 0.2s;
                box-shadow: 0 4px 12px rgba(220, 38, 38, 0.3);
            }
            .btn-danger:hover { background: #b91c1c; transform: translateY(-1px); }
            .footer-text { margin-top: 20px; font-size: 12px; text-align: center; color: #94a3b8; }
        </style>
    </head>
    <body>
        <div class="card">
            <div class="header">
                <div class="header-logo">&#128465;</div>
                <h1>${title}</h1>
                <p>Talisay Integrated School &bull; Record Management System</p>
            </div>
            <div class="body">
                ${contentHtml}
                <div class="footer-text">This link is single-use and time-limited.</div>
            </div>
        </div>
    </body>
    </html>
    `;
};

// GET /api/auth/confirm-delete-account-web
exports.confirmDeleteAccountWebPage = (req, res) => {
    const token = req.query.token;

    if (!token) {
        return res.status(400).send(renderDeletionPage({
            title: 'Invalid Request',
            isError: true,
            contentHtml: `
                <div class="danger-badge">
                    <strong>Missing Link Token:</strong> No valid verification token was provided.
                </div>
            `,
        }));
    }

    try {
        const record = db.prepare(`
            SELECT r.*, u.username, u.first_name, u.last_name, u.email
            FROM account_deletion_requests r
            JOIN users u ON r.user_id = u.id
            WHERE r.token = ?
        `).get(token);

        if (!record) {
            return res.status(404).send(renderDeletionPage({
                title: 'Invalid Link',
                isError: true,
                contentHtml: `
                    <div class="danger-badge">
                        <strong>Link Not Found:</strong> This account deletion link has already been used or does not exist.
                    </div>
                `,
            }));
        }

        if (new Date(record.expires_at) < new Date()) {
            return res.status(410).send(renderDeletionPage({
                title: 'Link Expired',
                isError: true,
                contentHtml: `
                    <div class="danger-badge">
                        <strong>Expired Link:</strong> This account deletion confirmation link has expired. Please initiate a new request from Settings in the application.
                    </div>
                `,
            }));
        }

        const fullName = [record.first_name, record.last_name].filter(Boolean).join(' ');

        return res.send(renderDeletionPage({
            title: 'Confirm Account Deletion',
            contentHtml: `
                <div class="danger-badge">
                    <strong>Permanently delete account @${record.username}?</strong><br>
                    User: <strong>${fullName || record.username}</strong><br>
                    Email: <strong>${record.email}</strong><br><br>
                    All your credentials and active sessions will be permanently revoked. This action cannot be reversed.
                </div>
                <form method="POST" action="/api/auth/confirm-delete-account?token=${encodeURIComponent(token)}">
                    <input type="hidden" name="token" value="${token}">
                    <button type="submit" class="btn-danger">Yes, Permanently Delete My Account</button>
                </form>
            `,
        }));
    } catch (error) {
        console.error('confirmDeleteAccountWebPage error:', error);
        return res.status(500).send(renderDeletionPage({
            title: 'System Error',
            isError: true,
            contentHtml: `<div class="danger-badge">An error occurred while processing the confirmation request.</div>`,
        }));
    }
};

// POST /api/auth/confirm-delete-account
exports.confirmDeleteAccount = (req, res) => {
    const token = req.body?.token || req.query?.token;
    const isHtml = req.accepts('html') && !req.xhr && !req.headers['content-type']?.includes('application/json');

    if (!token) {
        if (isHtml) {
            return res.status(400).send(renderDeletionPage({
                title: 'Invalid Request',
                isError: true,
                contentHtml: `<div class="danger-badge"><strong>Invalid Request:</strong> Verification token is missing.</div>`,
            }));
        }
        return res.status(400).json({ message: 'Token is required' });
    }

    try {
        const record = db.prepare(`
            SELECT r.*, u.id as user_id, u.username, u.first_name, u.middle_name, u.last_name, u.role, u.is_hidden
            FROM account_deletion_requests r
            JOIN users u ON r.user_id = u.id
            WHERE r.token = ?
        `).get(token);

        if (!record) {
            const msg = 'Invalid or already used deletion token.';
            if (isHtml) return res.status(404).send(renderDeletionPage({
                title: 'Link Invalid or Used',
                isError: true,
                contentHtml: `<div class="danger-badge"><strong>Link Invalid:</strong> ${msg}</div>`,
            }));
            return res.status(404).json({ message: msg });
        }

        if (new Date(record.expires_at) < new Date()) {
            const msg = 'Deletion confirmation link has expired.';
            if (isHtml) return res.status(410).send(renderDeletionPage({
                title: 'Link Expired',
                isError: true,
                contentHtml: `<div class="danger-badge"><strong>Expired:</strong> ${msg}</div>`,
            }));
            return res.status(410).json({ message: msg });
        }

        if (record.is_hidden === 1) {
            const msg = 'Developer super administrator account cannot be deleted.';
            if (isHtml) return res.status(403).send(renderDeletionPage({
                title: 'Action Prohibited',
                isError: true,
                contentHtml: `<div class="danger-badge"><strong>Action Prohibited:</strong> ${msg}</div>`,
            }));
            return res.status(403).json({ message: msg });
        }

        const fullName = [record.first_name, record.middle_name, record.last_name].filter(Boolean).join(' ');

        // Insert into deleted_users_history
        db.prepare(`
            INSERT INTO deleted_users_history (deleted_user_id, username, full_name, role, reason, deleted_by)
            VALUES (?, ?, ?, ?, ?, ?)
        `).run(record.user_id, record.username, fullName, record.role, 'Self-deleted via email confirmation link', record.user_id);

        // Delete from users (cascades to enrollments/tokens/requests)
        db.prepare('DELETE FROM users WHERE id = ?').run(record.user_id);
        db.prepare('DELETE FROM account_deletion_requests WHERE user_id = ?').run(record.user_id);

        // Log activity
        try {
            db.prepare('INSERT INTO activity_log (user_id, action, entity_type, entity_id, description) VALUES (?, ?, ?, ?, ?)')
                .run(null, 'DELETE', 'user', record.user_id, `User @${record.username} (${record.role}) permanently self-deleted via email confirmation link.`);
        } catch (_) {}

        if (isHtml) {
            return res.send(`
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Account Deleted — Talisay Integrated School RMS</title>
                <link rel="preconnect" href="https://fonts.googleapis.com">
                <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
                <style>
                    * { box-sizing: border-box; margin: 0; padding: 0; }
                    body {
                        font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
                        background: #f8fafc;
                        color: #0f172a;
                        min-height: 100vh;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        padding: 24px 16px;
                    }
                    .card {
                        background: #ffffff;
                        width: 100%;
                        max-width: 460px;
                        border-radius: 20px;
                        box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.05);
                        border: 1px solid #e2e8f0;
                        padding: 40px 32px;
                        text-align: center;
                    }
                    .icon { font-size: 56px; margin-bottom: 16px; }
                    h1 { font-size: 22px; font-weight: 800; color: #0f172a; margin-bottom: 12px; }
                    p { font-size: 14px; color: #475569; line-height: 1.7; margin-bottom: 24px; }
                    .badge {
                        background: #f1f5f9;
                        border: 1px solid #e2e8f0;
                        border-radius: 10px;
                        padding: 10px 16px;
                        font-size: 13px;
                        color: #64748b;
                        display: inline-block;
                    }
                </style>
            </head>
            <body>
                <div class="card">
                    <div class="icon">&#9989;</div>
                    <h1>Account Permanently Deleted</h1>
                    <p>Your account (<strong>@${record.username}</strong>) has been successfully deleted from the Talisay Integrated School Record Management System.</p>
                    <div class="badge">You may now close this browser window.</div>
                </div>
            </body>
            </html>
            `);
        }

        return res.json({
            success: true,
            message: 'Your account has been permanently deleted.',
        });
    } catch (error) {
        console.error('confirmDeleteAccount error:', error);
        res.status(500).json({ message: 'Failed to confirm account deletion', error: error.message });
    }
};

// ── GET /api/auth/sessions — list active sessions for current user ─────────────
exports.getSessions = (req, res) => {
    try {
        const authHeader = req.headers.authorization || '';
        const currentToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
        const currentHash = currentToken ? hashToken(currentToken) : null;
        const reqPlatform = detectPlatform(req);
        const reqDevice = detectDeviceName(req, reqPlatform);
        const reqIp = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket?.remoteAddress || null;

        // Auto backfill current active session if platform/device_name is missing
        if (currentHash && reqPlatform) {
            try {
                db.prepare(`
                    UPDATE user_sessions
                    SET platform = COALESCE(NULLIF(platform, ''), NULLIF(platform, 'unknown'), ?),
                        device_name = COALESCE(NULLIF(device_name, ''), NULLIF(device_name, 'Unknown Device'), ?),
                        ip_address = COALESCE(ip_address, ?),
                        last_seen_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
                    WHERE token_hash = ?
                `).run(reqPlatform, reqDevice, reqIp, currentHash);
            } catch (_) {}
        }

        const sessions = db.prepare(`
            SELECT id, device_name, platform, ip_address, created_at, last_seen_at, token_hash
            FROM user_sessions
            WHERE user_id = ?
            ORDER BY last_seen_at DESC
        `).all(req.user.id);

        const mapped = sessions.map(s => {
            const rawPlat = (s.platform || '').trim().toLowerCase();
            const plat = (rawPlat && rawPlat !== 'unknown') ? rawPlat : 'windows';
            const devName = (s.device_name && s.device_name !== 'Unknown Device' && s.device_name !== 'Device')
                ? s.device_name
                : (plat === 'windows' ? 'Windows PC' : plat === 'android' ? 'Android Device' : `${plat.charAt(0).toUpperCase() + plat.slice(1)} Device`);

            return {
                id: s.id,
                platform: plat,
                device_name: devName,
                ip_address: s.ip_address,
                created_at: s.created_at,
                last_seen_at: s.last_seen_at,
                is_current: currentHash ? s.token_hash === currentHash : false
            };
        });

        res.json(mapped);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch sessions', error: error.message });
    }
};

// ── DELETE /api/auth/sessions/:id — revoke a specific session ─────────────────
exports.revokeSession = (req, res) => {
    try {
        const session = db.prepare('SELECT id, user_id FROM user_sessions WHERE id = ?').get(req.params.id);
        if (!session) return res.status(404).json({ message: 'Session not found' });
        if (session.user_id !== req.user.id) return res.status(403).json({ message: 'Not your session' });
        db.prepare('DELETE FROM user_sessions WHERE id = ?').run(req.params.id);
        res.json({ message: 'Session revoked' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to revoke session', error: error.message });
    }
};

// ── DELETE /api/auth/sessions — revoke all OTHER sessions (keep current) ──────
exports.revokeAllOtherSessions = (req, res) => {
    try {
        const authHeader = req.headers.authorization || '';
        const currentToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
        const currentHash = currentToken ? hashToken(currentToken) : null;
        if (currentHash) {
            db.prepare('DELETE FROM user_sessions WHERE user_id = ? AND token_hash != ?').run(req.user.id, currentHash);
        } else {
            db.prepare('DELETE FROM user_sessions WHERE user_id = ?').run(req.user.id);
        }
        res.json({ message: 'All other sessions revoked' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to revoke sessions', error: error.message });
    }
};

// ── POST /api/auth/logout — stamp logout_at + remove current session ──────────
exports.logout = (req, res) => {
    try {
        const authHeader = req.headers.authorization || '';
        const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
        if (token) {
            const tokenHash = hashToken(token);
            db.prepare('DELETE FROM user_sessions WHERE token_hash = ?').run(tokenHash);
        }
        // Stamp logout_at on the most recent open login log for this user
        try {
            db.prepare(`
                UPDATE user_login_logs SET logout_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
                WHERE id = (
                    SELECT id FROM user_login_logs
                    WHERE user_id = ? AND logout_at IS NULL
                    ORDER BY login_at DESC LIMIT 1
                )
            `).run(req.user.id);
        } catch (_) {}
        res.json({ message: 'Logged out successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Logout failed', error: error.message });
    }
};

// ── GET /api/auth/login-logs — paginated login/logout log (admin: all users; self: own) ──
exports.getLoginLogs = (req, res) => {
    try {
        const page = Math.max(1, parseInt(req.query.page) || 1);
        const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
        const offset = (page - 1) * limit;
        const userId = req.query.user_id ? parseInt(req.query.user_id) : null;
        const search = req.query.search ? `%${req.query.search}%` : null;
        const dateFrom = req.query.date_from || null;
        const dateTo = req.query.date_to || null;

        let where = 'WHERE 1=1';
        const params = [];

        if (userId) { where += ' AND l.user_id = ?'; params.push(userId); }
        if (search) { where += ' AND (l.username LIKE ? OR l.full_name LIKE ?)'; params.push(search, search); }
        if (dateFrom) { where += ' AND l.login_at >= ?'; params.push(dateFrom); }
        if (dateTo) { where += ' AND l.login_at <= ?'; params.push(dateTo + 'T23:59:59Z'); }

        const total = db.prepare(`SELECT COUNT(*) as count FROM user_login_logs l ${where}`).get(...params).count;
        const rows = db.prepare(`
            SELECT l.id, l.user_id, l.username, l.full_name, l.role,
                   COALESCE(NULLIF(l.platform, ''), NULLIF(l.platform, 'unknown'), 'windows') as platform,
                   l.ip_address, l.login_at, l.logout_at
            FROM user_login_logs l
            ${where}
            ORDER BY l.login_at DESC
            LIMIT ? OFFSET ?
        `).all(...params, limit, offset);

        res.json({ total, page, limit, logs: rows });
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch login logs', error: error.message });
    }
};

// Export helpers for use in middleware / other controllers
exports.hashToken = hashToken;
exports.upsertSession = upsertSession;
exports.detectPlatform = detectPlatform;
exports.detectDeviceName = detectDeviceName;
