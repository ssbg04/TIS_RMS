const db = require('../config/db');
const fcmService = require('../services/fcmService');
fcmService.init();

// Programmatic helper to create notifications (can be called from other controllers)
// category: 'student' | 'document' | 'user' | 'system'
exports.createNotification = (userId, title, message, category = 'system', entityType = null, entityId = null) => {
    let notifId = null;
    try {
        const result = db.prepare('INSERT INTO notifications (user_id, title, message, is_read, category, entity_type, entity_id) VALUES (?, ?, ?, 0, ?, ?, ?)')
            .run(userId || null, title, message, category, entityType, entityId);
        notifId = result.lastInsertRowid;
    } catch (err) {
        // Gracefully fall back if category column doesn't exist yet (before migration)
        try {
            const result2 = db.prepare('INSERT INTO notifications (user_id, title, message, is_read) VALUES (?, ?, ?, 0)')
                .run(userId || null, title, message);
            notifId = result2.lastInsertRowid;
        } catch (err2) {
            console.error('Error creating notification:', err2.message);
        }
    }
    // Fire-and-forget real-time FCM push to target audience
    fcmService.sendNotification({
        userId: userId || null,
        title,
        body: message,
        category,
        entityType,
        entityId,
        notificationId: notifId
    }).catch(() => {});
};

// POST /api/notifications/fcm-token
exports.registerFcmToken = (req, res) => {
    const { token } = req.body;
    if (!token) return res.status(400).json({ message: 'Token required' });
    try {
        db.prepare(`
            INSERT INTO fcm_tokens (user_id, token, updated_at)
            VALUES (?, ?, strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
            ON CONFLICT(token) DO UPDATE
              SET user_id = excluded.user_id,
                  updated_at = excluded.updated_at
        `).run(req.user.id, token);
        res.json({ message: 'FCM token registered' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to register FCM token', error: error.message });
    }
};

// Common WHERE clause fragment for teacher notification scoping.
// Requires 4 bind parameters: [teacherId, teacherId, teacherId, teacherId]
const TEACHER_NOTIF_WHERE_CLAUSE = `
    (
        n.user_id = ?
        OR
        (
            n.user_id IS NULL AND (
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
                (n.entity_type = 'section' AND n.entity_id IN (
                    SELECT ts.section_id FROM teacher_sections ts
                    WHERE ts.teacher_id = ?
                ))
            )
        )
    )
`;

// GET /api/notifications - Get notifications for the logged-in user
// Teachers only see notifications scoped to their assigned sections or directed specifically to them.
exports.getNotifications = (req, res) => {
    try {
        const userId    = req.user.id;
        const role      = req.user.role;
        const isTeacher = role?.toLowerCase() === 'teacher';

        let notifications;
        if (isTeacher) {
            notifications = db.prepare(`
                SELECT n.id, n.user_id, n.title, n.message, n.is_read, n.category, n.entity_type, n.entity_id, n.created_at
                FROM notifications n
                WHERE ${TEACHER_NOTIF_WHERE_CLAUSE}
                ORDER BY n.created_at DESC, n.id DESC
                LIMIT 50
            `).all(userId, userId, userId, userId);
        } else {
            // Admins: all notifications
            notifications = db.prepare(`
                SELECT id, user_id, title, message, is_read, category, entity_type, entity_id, created_at
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
        const role = req.user.role;
        const isTeacher = role?.toLowerCase() === 'teacher';

        if (isTeacher) {
            db.prepare(`
                UPDATE notifications
                SET is_read = 1
                WHERE id IN (
                    SELECT n.id FROM notifications n
                    WHERE ${TEACHER_NOTIF_WHERE_CLAUSE}
                )
            `).run(userId, userId, userId, userId);
        } else {
            db.prepare('UPDATE notifications SET is_read = 1 WHERE user_id IS NULL OR user_id = ?').run(userId);
        }
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
        const role = req.user.role;
        const isTeacher = role?.toLowerCase() === 'teacher';

        let result;
        if (isTeacher) {
            result = db.prepare(`
                UPDATE notifications
                SET is_read = 1
                WHERE id = ? AND id IN (
                    SELECT n.id FROM notifications n
                    WHERE ${TEACHER_NOTIF_WHERE_CLAUSE}
                )
            `).run(id, userId, userId, userId, userId);
        } else {
            result = db.prepare('UPDATE notifications SET is_read = 1 WHERE id = ? AND (user_id IS NULL OR user_id = ?)')
                .run(id, userId);
        }

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
        const role = req.user.role;
        const isTeacher = role?.toLowerCase() === 'teacher';

        if (isTeacher) {
            db.prepare(`
                DELETE FROM notifications
                WHERE id IN (
                    SELECT n.id FROM notifications n
                    WHERE ${TEACHER_NOTIF_WHERE_CLAUSE}
                )
            `).run(userId, userId, userId, userId);
        } else {
            db.prepare('DELETE FROM notifications WHERE user_id IS NULL OR user_id = ?').run(userId);
        }
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
        const role = req.user.role;
        const isTeacher = role?.toLowerCase() === 'teacher';

        let result;
        if (isTeacher) {
            result = db.prepare(`
                DELETE FROM notifications
                WHERE id = ? AND id IN (
                    SELECT n.id FROM notifications n
                    WHERE ${TEACHER_NOTIF_WHERE_CLAUSE}
                )
            `).run(id, userId, userId, userId, userId);
        } else {
            result = db.prepare('DELETE FROM notifications WHERE id = ? AND (user_id IS NULL OR user_id = ?)')
                .run(id, userId);
        }

        if (result.changes === 0) {
            return res.status(404).json({ message: 'Notification not found or access denied.' });
        }
        res.json({ message: 'Notification deleted' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to delete notification', error: error.message });
    }
};
