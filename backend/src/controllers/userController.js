const db = require('../config/db');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const { createNotification } = require('./notificationController');
const { sendPasswordResetLink } = require('../services/emailService');

// ── Helpers ──────────────────────────────────────────────────────────────────
const logActivity = (userId, action, entityType, entityId, description) => {
    try {
        db.prepare('INSERT INTO activity_log (user_id,action,entity_type,entity_id,description) VALUES (?,?,?,?,?)')
            .run(userId ?? null, action, entityType, entityId ?? null, description);
    } catch (err) { console.error('logActivity error:', err.message); }
};

const logUserHistory = (performedBy, targetUserId, action, username, fullName, role) => {
    try {
        db.prepare('INSERT INTO user_history (performed_by,target_user_id,action,username,full_name,role) VALUES (?,?,?,?,?,?)')
            .run(performedBy ?? null, targetUserId ?? null, action, username, fullName, role);
    } catch (err) { console.error('logUserHistory error:', err.message); }
};


// GET /api/users - List all users
exports.getUsers = (req, res) => {
    try {
        const users = db.prepare(`
            SELECT u.id, u.username, u.first_name, u.middle_name, u.last_name, u.extension, u.role, u.email, u.phone, u.is_active, u.created_at,
                   COALESCE(creator.username, creator_del.username, 'System') as added_by_username,
                   COALESCE(creator.first_name || ' ' || creator.last_name, creator_del.full_name, 'System') as added_by_name
            FROM users u
            LEFT JOIN user_history uh ON u.id = uh.target_user_id AND uh.action = 'created'
            LEFT JOIN users creator ON uh.performed_by = creator.id
            LEFT JOIN deleted_users_history creator_del ON uh.performed_by = creator_del.deleted_user_id
            ORDER BY u.role, u.last_name
        `).all();
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

    // Temporary password = username + 123 (e.g. ccharles123)
    const temporaryPassword = `${username}123`;

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
        const newUser = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
        const uid = newUser?.id ?? result.lastInsertRowid;
        const fullName = [firstName, lastName].filter(Boolean).join(' ');
        logActivity(req.user?.id, 'CREATE', 'user', uid, `Added user: ${username} as ${role}`);
        logUserHistory(req.user?.id, uid, 'created', username, fullName, role);
        createNotification(null, 'User Registered', `New ${role} user "${username}" (${fullName}) was registered.`, 'user');

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

    const validRoles = ['admin', 'teacher'];
    if (role && !validRoles.includes(role)) {
        return res.status(400).json({ message: 'Invalid role. Must be admin or teacher.' });
    }

    try {
        const user = db.prepare('SELECT id, username, role, first_name, middle_name, last_name, extension, email, phone FROM users WHERE id = ?').get(id);
        if (!user) return res.status(404).json({ message: 'User not found.' });

        // Prevent self-demotion (locked role for self)
        const effectiveRole = user.id === req.user.id ? user.role : (role || user.role);

        db.prepare(`
            UPDATE users
            SET first_name = ?, middle_name = ?, last_name = ?, extension = ?, role = ?, email = ?, phone = ?, updated_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
            WHERE id = ?
        `).run(firstName, middleName || null, lastName, extension || null, effectiveRole, email || null, phone || null, id);

        const updatedUser = db.prepare('SELECT username FROM users WHERE id = ?').get(id);
        const updatedUsername = updatedUser?.username ?? user.username ?? `#${id}`;
        const fullName = [firstName, lastName].filter(Boolean).join(' ');

        const changes = [];
        if (firstName !== undefined && firstName !== user.first_name) changes.push(`First Name: "${user.first_name || ''}" → "${firstName}"`);
        if (middleName !== undefined && middleName !== (user.middle_name || '')) changes.push(`Middle Name: "${user.middle_name || ''}" → "${middleName || ''}"`);
        if (lastName !== undefined && lastName !== user.last_name) changes.push(`Last Name: "${user.last_name || ''}" → "${lastName}"`);
        if (extension !== undefined && extension !== (user.extension || '')) changes.push(`Extension: "${user.extension || ''}" → "${extension || ''}"`);
        if (role !== undefined && effectiveRole !== user.role) changes.push(`Role: "${user.role}" → "${effectiveRole}"`);
        if (email !== undefined && email !== (user.email || '')) changes.push(`Email: "${user.email || ''}" → "${email || ''}"`);
        if (phone !== undefined && phone !== (user.phone || '')) changes.push(`Phone: "${user.phone || ''}" → "${phone || ''}"`);

        const changesText = changes.length ? `\n• ${changes.join('\n• ')}` : '';
        logActivity(req.user?.id, 'UPDATE', 'user', id, `Updated user: ${updatedUsername}${changesText}`);
        logUserHistory(req.user?.id, id, 'updated',
            updatedUsername,
            fullName, effectiveRole);

        res.json({ message: 'User updated successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to update user', error: error.message });
    }
};


// PUT /api/users/:id/reset-password - Send password reset link to user's email with expiration time
exports.resetPassword = async (req, res) => {
    const { id } = req.params;
    const { adminPassword, expirationMinutes } = req.body;
    const adminId = req.user.id;
    const expMinutes = Math.min(1440, Math.max(5, parseInt(expirationMinutes, 10) || 15));

    try {
        if (!adminPassword) {
            return res.status(400).json({ message: 'Admin password is required to reset a password.' });
        }

        const adminUser = db.prepare('SELECT id, username, password FROM users WHERE id = ?').get(adminId);
        if (!adminUser || !bcrypt.compareSync(adminPassword, adminUser.password)) {
            return res.status(401).json({ message: 'Incorrect Admin Password.' });
        }

        const user = db.prepare('SELECT id, username, first_name, last_name, role, email FROM users WHERE id = ?').get(id);
        if (!user) return res.status(404).json({ message: 'User not found.' });

        if (user.id === req.user.id) {
            return res.status(403).json({ message: 'Cannot reset your own password via this route. Use the Change Password profile setting.' });
        }

        if (!user.email || !user.email.trim()) {
            return res.status(400).json({
                message: `User @${user.username} does not have a registered email address. Please edit the user profile and add an email address first.`
            });
        }

        // Invalidate any previous pending reset links for this user
        db.prepare(`
            UPDATE password_reset_links
            SET status = 'expired', expired_notified = 1
            WHERE user_id = ? AND status = 'pending'
        `).run(user.id);

        // Generate cryptographically secure reset token
        const token = crypto.randomBytes(32).toString('hex');
        const expiresAt = new Date(Date.now() + expMinutes * 60 * 1000).toISOString();

        // Insert new reset link record
        db.prepare(`
            INSERT INTO password_reset_links (user_id, admin_id, token, email, status, expires_at)
            VALUES (?, ?, ?, ?, 'pending', ?)
        `).run(user.id, adminId, token, user.email.trim(), expiresAt);

        // Construct reset link URL
        const protocol = req.headers['x-forwarded-proto'] || req.protocol || 'http';
        const host = req.headers['x-forwarded-host'] || req.get('host');
        const baseUrl = process.env.APP_URL ? process.env.APP_URL.replace(/\/+$/, '') : `${protocol}://${host}`;
        const resetLink = `${baseUrl}/api/auth/reset-password-web?token=${token}`;

        const fullName = [user.first_name, user.last_name].filter(Boolean).join(' ');

        // Send Email with reset link
        try {
            await sendPasswordResetLink({
                to: user.email.trim(),
                username: user.username,
                resetLink: resetLink,
                expiresMinutes: expMinutes,
            });

            // Log activity and history
            logActivity(adminId, 'UPDATE', 'user', id, `Sent password reset email link to @${user.username} (${user.email}) - expires in ${expMinutes}m`);
            logUserHistory(adminId, id, 'reset_password_link', user.username, fullName, user.role);

            // Push notification to the initiating Admin
            createNotification(
                adminId,
                'Password Reset Link Sent',
                `Password reset link was successfully sent to @${user.username} (${user.email}). The link will expire in ${expMinutes} minutes.`,
                'user',
                'user',
                user.id
            );

            return res.json({
                message: `Password reset link sent to ${user.email} (expires in ${expMinutes} minutes).`
            });
        } catch (emailErr) {
            // Update link status as failed
            db.prepare("UPDATE password_reset_links SET status = 'failed' WHERE token = ?").run(token);

            // Push notification to Admin that delivery failed
            createNotification(
                adminId,
                'Password Reset Email Failed',
                `Failed to send password reset email to @${user.username} (${user.email}): ${emailErr.message}`,
                'user',
                'user',
                user.id
            );

            return res.status(500).json({
                message: `Failed to deliver reset email to ${user.email}. Please verify SMTP settings.`,
                error: emailErr.message
            });
        }
    } catch (error) {
        res.status(500).json({ message: 'Failed to initiate password reset', error: error.message });
    }
};

// DELETE /api/users/:id - Delete a user

exports.deleteUser = (req, res) => {
    const { id } = req.params;
    const { reason, password } = req.body; 
    const adminId = req.user.id;

    try {
        // 1. Validate inputs
        if (!reason || !password) {
            return res.status(400).json({ message: 'Reason and admin password are required for deletion.' });
        }

        // 2. Verify Admin Password
        const adminUser = db.prepare('SELECT password FROM users WHERE id = ?').get(adminId);
        if (!adminUser || !bcrypt.compareSync(password, adminUser.password)) {
            return res.status(401).json({ message: 'Incorrect Admin Password.' });
        }

        // 3. Fetch target user details (including name fields for snapshot)
        const user = db.prepare('SELECT id, username, first_name, middle_name, last_name, role FROM users WHERE id = ?').get(id);
        
        if (!user) return res.status(404).json({ message: 'User not found.' });
        if (user.id === adminId) return res.status(403).json({ message: 'Cannot delete your own account.' });
        
        if (user.role === 'admin') {
            const adminCount = db.prepare("SELECT COUNT(*) as count FROM users WHERE role = 'admin'").get().count;
            if (adminCount <= 1) return res.status(403).json({ message: 'Cannot delete the last admin account.' });
        }

        // 4. ✅ INSERT SNAPSHOT into deleted_users_history BEFORE deleting the user
        const fullName = [user.first_name, user.middle_name, user.last_name].filter(Boolean).join(' ');
        
        db.prepare(`
            INSERT INTO deleted_users_history (deleted_user_id, username, full_name, role, reason, deleted_by)
            VALUES (?, ?, ?, ?, ?, ?)
        `).run(user.id, user.username, fullName, user.role, reason, adminId);

        // 5. Delete the user
        db.prepare('DELETE FROM users WHERE id = ?').run(id);
        
        // 6. Log activities
        const logMsg = `Deleted user "@${user.username}" (${user.role}). Reason: ${reason}`;
        logActivity(adminId, 'DELETE', 'user', id, logMsg);
        logUserHistory(adminId, id, 'deleted', user.username, fullName, user.role);

        res.json({ message: 'User deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to delete user', error: error.message });
    }
};

// PUT /api/users/:id/status - Toggle user active/inactive
exports.toggleUserStatus = (req, res) => {
    const { id } = req.params;
    const adminId = req.user.id;

    if (parseInt(id) === adminId) {
        return res.status(403).json({ message: 'You cannot deactivate your own account.' });
    }

    try {
        const user = db.prepare('SELECT id, username, first_name, last_name, role, is_active FROM users WHERE id = ?').get(id);
        if (!user) return res.status(404).json({ message: 'User not found.' });

        const newStatus = user.is_active === 1 ? 0 : 1;
        db.prepare("UPDATE users SET is_active = ?, updated_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')) WHERE id = ?")
            .run(newStatus, id);

        if (newStatus === 0) {
            // Revoke all FCM push tokens immediately upon deactivation
            db.prepare("DELETE FROM fcm_tokens WHERE user_id = ?").run(id);
        }

        const statusLabel = newStatus === 1 ? 'Activated' : 'Deactivated';
        const fullName = [user.first_name, user.last_name].filter(Boolean).join(' ');
        logActivity(adminId, 'UPDATE', 'user', id, `${statusLabel} user: ${user.username}`);
        logUserHistory(adminId, id, statusLabel.toLowerCase(), user.username, fullName, user.role);

        res.json({ message: `User "${user.username}" has been ${statusLabel.toLowerCase()}.`, is_active: newStatus });
    } catch (error) {
        res.status(500).json({ message: 'Failed to update user status', error: error.message });
    }
};

exports.getTeacherSections = (req, res) => {
    const { teacherId } = req.params;
    const isTeacher = req.user?.role?.toLowerCase() === 'teacher';
    if (isTeacher && req.user.id !== parseInt(teacherId)) {
        return res.status(403).json({ message: 'Unauthorized access to teacher sections.' });
    }

    try {
        const sections = db.prepare(`
            SELECT s.*, ay.year_range as academic_year_range
            FROM sections s
            JOIN teacher_sections ts ON s.id = ts.section_id
            LEFT JOIN academic_years ay ON s.academic_year_id = ay.id
            WHERE ts.teacher_id = ?
            ORDER BY ay.year_range DESC, s.grade_level ASC, s.name ASC
        `).all(teacherId);
        res.json(sections);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch teacher sections', error: error.message });
    }
};

// POST /api/users/:teacherId/sections
exports.updateTeacherSections = (req, res) => {
    const { teacherId } = req.params;
    const { sectionIds } = req.body; // Array of section IDs

    if (!Array.isArray(sectionIds)) {
        return res.status(400).json({ message: 'sectionIds must be an array' });
    }

    try {
        db.transaction(() => {
            // Delete existing
            db.prepare('DELETE FROM teacher_sections WHERE teacher_id = ?').run(teacherId);
            
            // Insert new ones
            const insert = db.prepare('INSERT INTO teacher_sections (teacher_id, section_id) VALUES (?, ?)');
            for (const sectionId of sectionIds) {
                insert.run(teacherId, sectionId);
            }
        })();
        res.json({ message: 'Teacher sections updated successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to update teacher sections', error: error.message });
    }
};

// GET /api/users/history?page=1&limit=20&date_from=YYYY-MM-DD&date_to=YYYY-MM-DD (admin only)
exports.getUserHistory = (req, res) => {
    try {
        const page     = Math.max(1, parseInt(req.query.page  || '1'));
        const limit    = Math.min(100, Math.max(1, parseInt(req.query.limit || '20')));
        const offset   = (page - 1) * limit;
        const dateFrom = req.query.date_from || '';
        const dateTo   = req.query.date_to   || '';
        const action   = req.query.action    || '';
        const role     = req.query.role      || '';

        const conditions = [];
        const params     = [];

        if (dateFrom) { conditions.push("DATE(h.created_at) >= DATE(?)"); params.push(dateFrom); }
        if (dateTo)   { conditions.push("DATE(h.created_at) <= DATE(?)"); params.push(dateTo);   }
        if (action)   { conditions.push("h.action = ?"); params.push(action); }
        if (role)     { conditions.push("h.role = ?"); params.push(role); }

        const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

        const total = db.prepare(`SELECT COUNT(*) as count FROM user_history h ${where}`).get(params).count;

        const rows = db.prepare(`
            SELECT
                h.id, h.action, h.username, h.full_name, h.role, h.created_at,
                COALESCE(u.username, dh.username, 'System') AS performed_by_username,
                COALESCE(u.first_name || ' ' || u.last_name, dh.full_name, 'System') AS performed_by_name
            FROM user_history h
            LEFT JOIN users u ON h.performed_by = u.id
            LEFT JOIN deleted_users_history dh ON h.performed_by = dh.deleted_user_id
            ${where}
            ORDER BY h.created_at DESC
            LIMIT ? OFFSET ?
        `).all([...params, limit, offset]);

        res.json({
            history: rows,
            pagination: { total, page, limit, totalPages: Math.ceil(total / limit) }
        });
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch user history', error: error.message });
    }
};
