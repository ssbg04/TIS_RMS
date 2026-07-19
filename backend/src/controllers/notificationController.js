const db = require('../config/db');

// Programmatic helper to create notifications (can be called from other controllers)
// category: 'student' | 'document' | 'user' | 'system'
exports.createNotification = (userId, title, message, category = 'system', entityType = null, entityId = null) => {
    try {
        db.prepare('INSERT INTO notifications (user_id, title, message, is_read, category, entity_type, entity_id) VALUES (?, ?, ?, 0, ?, ?, ?)')
            .run(userId || null, title, message, category, entityType, entityId);
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
// Teachers only see student/document category notifications scoped to their sections.
exports.getNotifications = (req, res) => {
    try {
        const userId    = req.user.id;
        const teacherId = req.user.id;
        const role      = req.user.role;
        const isTeacher = role?.toLowerCase() === 'teacher';

        let notifications;
        if (isTeacher) {
            // Teachers: student/document notifications scoped to their assigned sections
            // (using timeline-based latest-enrollment sorting, not MAX(id)),
            // plus any unscoped broadcast notifications (entity_type IS NULL, user_id IS NULL)
            // for permitted categories, plus their own direct notifications.
            notifications = db.prepare(`
                SELECT n.id, n.user_id, n.title, n.message, n.is_read, n.created_at
                FROM notifications n
                WHERE (n.user_id IS NULL OR n.user_id = ?)
                  AND (
                      (n.entity_type = 'student' AND n.entity_id IN (
                          SELECT s.id FROM students s
                          JOIN enrollments e ON s.id = e.student_id
                          JOIN teacher_sections ts ON e.section_id = ts.section_id
                          WHERE ts.teacher_id = ?
                            AND e.id = (
                                SELECT e2.id FROM enrollments e2
                                JOIN academic_years ay_inner ON e2.academic_year_id = ay_inner.id
                                WHERE e2.student_id = s.id
                                ORDER BY ay_inner.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                            )
                      ))
                      OR
                      (n.entity_type = 'document' AND n.entity_id IN (
                          SELECT d.id FROM documents d
                          JOIN enrollments e ON d.student_id = e.student_id
                          JOIN teacher_sections ts ON e.section_id = ts.section_id
                          WHERE ts.teacher_id = ?
                            AND e.id = (
                                SELECT e2.id FROM enrollments e2
                                JOIN academic_years ay_inner ON e2.academic_year_id = ay_inner.id
                                WHERE e2.student_id = d.student_id
                                ORDER BY ay_inner.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                            )
                      ))
                      OR
                      (n.entity_type IS NULL AND n.user_id IS NULL AND n.category IN ('student', 'document', 'system'))
                      OR
                      (n.user_id = ?)
                  )
                ORDER BY n.created_at DESC, n.id DESC
                LIMIT 50
            `).all(userId, teacherId, teacherId, teacherId);
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

// DELETE /api/notifications/:id - Delete a specific notification
exports.deleteNotification = (req, res) => {
    const { id } = req.params;
    try {
        const userId = req.user.id;
        const result = db.prepare('DELETE FROM notifications WHERE id = ? AND (user_id IS NULL OR user_id = ?)')
            .run(id, userId);

        if (result.changes === 0) {
            return res.status(404).json({ message: 'Notification not found or access denied.' });
        }
        res.json({ message: 'Notification deleted' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to delete notification', error: error.message });
    }
};
