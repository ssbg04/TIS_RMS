const db = require('../config/db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
require('dotenv').config();

// POST /api/auth/login
exports.login = (req, res) => {
    const { username, password } = req.body;

    try {
        const user = db.prepare('SELECT * FROM users WHERE username = ?').get(username);

        if (!user || !bcrypt.compareSync(password, user.password)) {
            return res.status(401).json({ message: 'Invalid username or password' });
        }

        const token = jwt.sign(
            { id: user.id, username: user.username, role: user.role },
            process.env.JWT_SECRET,
            { expiresIn: '30d' } // Extended for Remember Me support
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
            SET first_name = ?, middle_name = ?, last_name = ?, extension = ?, phone = ?, email = ?, updated_at = CURRENT_TIMESTAMP
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

        const hashedNewPassword = bcrypt.hashSync(newPassword, 10);
        db.prepare('UPDATE users SET password = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
            .run(hashedNewPassword, req.user.id);

        res.json({ message: 'Password changed successfully.' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to change password', error: error.message });
    }
};

// POST /api/auth/forgot-password — admin/teacher submits a reset request
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
        const user = db.prepare('SELECT id, role FROM users WHERE username = ?').get(username);
        if (!user) {
            return res.status(404).json({ message: 'Username not found.' });
        }
        if (user.role === 'super_admin') {
            return res.status(403).json({ message: 'Super Admin cannot submit password reset requests.' });
        }

        // Cancel any existing pending request for this user
        db.prepare("DELETE FROM password_reset_requests WHERE user_id = ? AND status = 'pending'").run(user.id);

        const hashedPassword = bcrypt.hashSync(newPassword, 10);
        db.prepare(`
            INSERT INTO password_reset_requests (user_id, new_password_hash)
            VALUES (?, ?)
        `).run(user.id, hashedPassword);

        res.json({ message: 'Password reset request submitted. Awaiting Super Admin approval.' });
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

        db.prepare('UPDATE users SET password = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
            .run(request.new_password_hash, request.user_id);
        db.prepare(`UPDATE password_reset_requests SET status = 'approved', reviewed_at = CURRENT_TIMESTAMP, reviewed_by = ? WHERE id = ?`)
            .run(req.user.id, id);

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

        db.prepare(`UPDATE password_reset_requests SET status = 'rejected', reviewed_at = CURRENT_TIMESTAMP, reviewed_by = ? WHERE id = ?`)
            .run(req.user.id, id);

        res.json({ message: 'Password reset request rejected.' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to reject request', error: error.message });
    }
};
