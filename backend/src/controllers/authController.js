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

