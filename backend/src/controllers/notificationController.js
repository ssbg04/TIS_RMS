const db = require('../config/db');

// Programmatic helper to create notifications (can be called from other controllers)
// category: 'student' | 'document' | 'user' | 'system'
exports.createNotification = (userId, title, message, category = 'system') => {
    try {
        db.prepare('INSERT INTO notifications (user_id, title, message, is_read, category) VALUES (?, ?, ?, 0, ?)')
            .run(userId || null, title, message, category);
    } catch (err) {
        // Gracefully fall back if category column doesn't exist yet (before migration)
        try {
            db.prepare('INSERT INTO notifications (user_id, title, message, is_read) VALUES (?, ?, ?, 0)')
                .run(userId || null, title, message);
        } catch (err2) {
            console.error('Error creating notification:', err2.message);
        }
    }
};

// GET /api/notifications - Get notifications for the logged-in user
// Teachers only see student/document category notifications.
exports.getNotifications = (req, res) => {
    try {
        const userId = req.user.id;
        const role   = req.user.role;
        const isTeacher = role === 'teacher';

        let notifications;
        if (isTeacher) {
            // Teachers: only student- and document-related notifications
            notifications = db.prepare(`
                SELECT id, user_id, title, message, is_read, created_at
                FROM notifications
                WHERE (user_id IS NULL OR user_id = ?)
                  AND (LOWER(title) LIKE '%student%'
                       OR LOWER(title) LIKE '%document%'
                       OR LOWER(title) LIKE '%enrolled%'
                       OR LOWER(title) LIKE '%upload%')
                ORDER BY created_at DESC, id DESC
                LIMIT 50
            `).all(userId);
        } else {
            // Admins: all notifications
            notifications = db.prepare(`
                SELECT id, user_id, title, message, is_read, created_at
                FROM notifications
                WHERE user_id IS NULL OR user_id = ?
                ORDER BY created_at DESC, id DESC
                LIMIT 50
            `).all(userId);
        }

        res.json(notifications);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch notifications', error: error.message });
    }
};

// PUT /api/notifications/mark-all-read - Mark all notifications as read
exports.markAllRead = (req, res) => {
    try {
        const userId = req.user.id;
        db.prepare('UPDATE notifications SET is_read = 1 WHERE user_id IS NULL OR user_id = ?').run(userId);
        res.json({ message: 'All notifications marked as read' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to mark notifications as read', error: error.message });
    }
};

// PUT /api/notifications/:id/read - Mark a single notification as read
exports.markRead = (req, res) => {
    const { id } = req.params;
    try {
        const userId = req.user.id;
        const result = db.prepare('UPDATE notifications SET is_read = 1 WHERE id = ? AND (user_id IS NULL OR user_id = ?)')
            .run(id, userId);

        if (result.changes === 0) {
            return res.status(404).json({ message: 'Notification not found or access denied.' });
        }
        res.json({ message: 'Notification marked as read' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to mark notification as read', error: error.message });
    }
};

// DELETE /api/notifications/clear - Clear all notifications visible to current user
exports.clearNotifications = (req, res) => {
    try {
        const userId = req.user.id;
        db.prepare('DELETE FROM notifications WHERE user_id IS NULL OR user_id = ?').run(userId);
        res.json({ message: 'All notifications cleared' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to clear notifications', error: error.message });
    }
};

