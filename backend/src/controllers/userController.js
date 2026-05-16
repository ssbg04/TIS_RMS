const db = require('../config/db');
const bcrypt = require('bcrypt');

// GET /api/users - List all users
exports.getUsers = (req, res) => {
    try {
        const users = db.prepare(
            'SELECT id, username, first_name, middle_name, last_name, extension, role, email, phone, created_at FROM users ORDER BY role, last_name'
        ).all();
        res.json(users);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch users', error: error.message });
    }
};

// POST /api/users - Create a new user
exports.createUser = (req, res) => {
    const { username, firstName, middleName, lastName, extension, role, email, phone } = req.body;
    // Password is optional — auto-generated if not provided
    let providedPassword = req.body.password;

    if (!username || !firstName || !lastName || !role) {
        return res.status(400).json({ message: 'Username, first name, last name, and role are required.' });
    }

    const validRoles = ['admin', 'teacher']; // Super admin can only be created by seeding
    if (!validRoles.includes(role)) {
        return res.status(400).json({ message: 'Invalid role. Must be admin or teacher.' });
    }

    // Auto-generate a secure temporary password if none was provided
    const generatePassword = () => {
        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#';
        let pwd = '';
        for (let i = 0; i < 10; i++) pwd += chars[Math.floor(Math.random() * chars.length)];
        return pwd;
    };

    const temporaryPassword = (providedPassword && providedPassword.trim().length >= 6)
        ? providedPassword.trim()
        : generatePassword();

    try {
        const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
        if (existing) {
            return res.status(409).json({ message: `Username "${username}" is already taken.` });
        }

        const hashedPassword = bcrypt.hashSync(temporaryPassword, 10);
        const result = db.prepare(`
            INSERT INTO users (username, password, first_name, middle_name, last_name, extension, role, email, phone)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(username, hashedPassword, firstName, middleName || null, lastName, extension || null, role, email || null, phone || null);

        // Return the plaintext password ONCE — it will never be retrievable again
        res.status(201).json({
            message: 'User created successfully',
            userId: result.lastInsertRowid,
            temporaryPassword,
        });
    } catch (error) {
        res.status(500).json({ message: 'Failed to create user', error: error.message });
    }
};

// PUT /api/users/:id - Update a user
exports.updateUser = (req, res) => {
    const { id } = req.params;
    const { firstName, middleName, lastName, extension, role, email, phone } = req.body;

    const validRoles = ['super_admin', 'admin', 'teacher'];
    if (role && !validRoles.includes(role)) {
        return res.status(400).json({ message: 'Invalid role.' });
    }

    try {
        const user = db.prepare('SELECT id, role FROM users WHERE id = ?').get(id);
        if (!user) return res.status(404).json({ message: 'User not found.' });

        // Prevent modifying super_admin role
        if (user.role === 'super_admin' && role && role !== 'super_admin') {
            return res.status(403).json({ message: 'Cannot change the Super Admin role.' });
        }
        // Preserve super_admin role — cannot be changed to anything else
        const effectiveRole = user.role === 'super_admin' ? 'super_admin' : (role || user.role);

        db.prepare(`
            UPDATE users
            SET first_name = ?, middle_name = ?, last_name = ?, extension = ?, role = ?, email = ?, phone = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
        `).run(firstName, middleName || null, lastName, extension || null, effectiveRole, email || null, phone || null, id);

        res.json({ message: 'User updated successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to update user', error: error.message });
    }
};

// PUT /api/users/:id/reset-password - Reset a user's password
exports.resetPassword = (req, res) => {
    const { id } = req.params;
    const newPassword = 'changeme123';

    try {
        const user = db.prepare('SELECT id, role FROM users WHERE id = ?').get(id);
        if (!user) return res.status(404).json({ message: 'User not found.' });
        if (user.role === 'super_admin') {
            return res.status(403).json({ message: 'Cannot reset the Super Admin password via this route.' });
        }

        const hashed = bcrypt.hashSync(newPassword, 10);
        db.prepare('UPDATE users SET password = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(hashed, id);

        res.json({ message: `Password has been reset to "${newPassword}".` });
    } catch (error) {
        res.status(500).json({ message: 'Failed to reset password', error: error.message });
    }
};

// DELETE /api/users/:id - Delete a user
exports.deleteUser = (req, res) => {
    const { id } = req.params;
    try {
        const user = db.prepare('SELECT id, role FROM users WHERE id = ?').get(id);
        if (!user) return res.status(404).json({ message: 'User not found.' });
        if (user.role === 'super_admin') {
            return res.status(403).json({ message: 'Cannot delete the Super Admin account.' });
        }

        db.prepare('DELETE FROM users WHERE id = ?').run(id);
        res.json({ message: 'User deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to delete user', error: error.message });
    }
};
