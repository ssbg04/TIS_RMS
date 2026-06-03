const db = require('../config/db');

// GET /api/dashboard/stats
exports.getStats = (req, res) => {
    try {
        const isTeacher = req.user.role === 'teacher';
        const userId = req.user.id;

        let totalStudents;
        let completedDocuments;
        let missingDocuments;
        const activeUsers = db.prepare('SELECT COUNT(*) as count FROM users').get().count;

        if (isTeacher) {
            // Count of students whose latest enrollment is in teacher's assigned sections
            totalStudents = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.id = (
                    SELECT MAX(id)
                    FROM enrollments
                    WHERE student_id = s.id
                )
                AND e.section_id IN (
                    SELECT section_id
                    FROM teacher_sections
                    WHERE teacher_id = ?
                )
            `).get(userId).count;

            // Count of students in teacher's sections who have ALL mandatory docs complete
            completedDocuments = db.prepare(`
                SELECT COUNT(DISTINCT ce.student_id) as count
                FROM (
                    SELECT 
                        s.id AS student_id,
                        CASE WHEN e.grade_level <= 10 THEN 'JHS' ELSE 'SHS' END AS category
                    FROM students s
                    JOIN enrollments e ON s.id = e.student_id
                    WHERE e.id = (
                        SELECT MAX(id)
                        FROM enrollments
                        WHERE student_id = s.id
                    )
                    AND e.section_id IN (
                        SELECT section_id
                        FROM teacher_sections
                        WHERE teacher_id = ?
                    )
                ) ce
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM document_requirements dr
                    WHERE dr.category = ce.category
                      AND dr.is_mandatory = 1
                      AND dr.is_enabled = 1
                      AND NOT EXISTS (
                          SELECT 1 FROM documents d
                          WHERE d.student_id = ce.student_id
                            AND d.requirement_id = dr.id
                            AND d.status IN ('Completed', 'Archived')
                      )
                )
            `).get(userId).count;

            // Count of students in teacher's assigned sections who are missing at least one mandatory document
            missingDocuments = db.prepare(`
                SELECT COUNT(DISTINCT ce.student_id) as count
                FROM (
                    SELECT 
                        s.id AS student_id,
                        CASE WHEN e.grade_level <= 10 THEN 'JHS' ELSE 'SHS' END AS category
                    FROM students s
                    JOIN enrollments e ON s.id = e.student_id
                    WHERE e.id = (
                        SELECT MAX(id)
                        FROM enrollments
                        WHERE student_id = s.id
                    )
                    AND e.section_id IN (
                        SELECT section_id
                        FROM teacher_sections
                        WHERE teacher_id = ?
                    )
                ) ce
                JOIN document_requirements dr ON ce.category = dr.category
                WHERE dr.is_mandatory = 1 
                  AND dr.is_enabled = 1
                  AND NOT EXISTS (
                      SELECT 1 
                      FROM documents d 
                      WHERE d.student_id = ce.student_id 
                        AND d.requirement_id = dr.id 
                        AND d.status IN ('Completed', 'Archived')
                  )
            `).get(userId).count;
        } else {
            // Admin: All students
            totalStudents = db.prepare('SELECT COUNT(*) as count FROM students').get().count;

            // Count of students who have ALL mandatory docs complete across all sections
            completedDocuments = db.prepare(`
                SELECT COUNT(DISTINCT ce.student_id) as count
                FROM (
                    SELECT 
                        s.id AS student_id,
                        CASE WHEN e.grade_level <= 10 THEN 'JHS' ELSE 'SHS' END AS category
                    FROM students s
                    JOIN enrollments e ON s.id = e.student_id
                    WHERE e.id = (
                        SELECT MAX(id)
                        FROM enrollments
                        WHERE student_id = s.id
                    )
                ) ce
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM document_requirements dr
                    WHERE dr.category = ce.category
                      AND dr.is_mandatory = 1
                      AND dr.is_enabled = 1
                      AND NOT EXISTS (
                          SELECT 1 FROM documents d
                          WHERE d.student_id = ce.student_id
                            AND d.requirement_id = dr.id
                            AND d.status IN ('Completed', 'Archived')
                      )
                )
            `).get().count;

            // Count of students who are missing at least one mandatory document across all sections
            missingDocuments = db.prepare(`
                SELECT COUNT(DISTINCT ce.student_id) as count
                FROM (
                    SELECT 
                        s.id AS student_id,
                        CASE WHEN e.grade_level <= 10 THEN 'JHS' ELSE 'SHS' END AS category
                    FROM students s
                    JOIN enrollments e ON s.id = e.student_id
                    WHERE e.id = (
                        SELECT MAX(id)
                        FROM enrollments
                        WHERE student_id = s.id
                    )
                ) ce
                JOIN document_requirements dr ON ce.category = dr.category
                WHERE dr.is_mandatory = 1 
                  AND dr.is_enabled = 1
                  AND NOT EXISTS (
                      SELECT 1 
                      FROM documents d 
                      WHERE d.student_id = ce.student_id 
                        AND d.requirement_id = dr.id 
                        AND d.status IN ('Completed', 'Archived')
                  )
            `).get().count;
        }

        res.json({ totalStudents, activeUsers, completedDocuments, missingDocuments });
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch stats', error: error.message });
    }
};

// GET /api/dashboard/recent-activities?page=1&limit=10&date_from=YYYY-MM-DD&date_to=YYYY-MM-DD&entity_types=student,document
exports.getRecentActivities = (req, res) => {
    try {
        const page      = Math.max(1, parseInt(req.query.page  || '1'));
        const limit     = Math.min(50, Math.max(1, parseInt(req.query.limit || '10')));
        const offset    = (page - 1) * limit;
        const dateFrom  = req.query.date_from || '';
        const dateTo    = req.query.date_to   || '';
        // Comma-separated entity type filter, e.g. "student,document" (teacher view)
        const entityTypesRaw = req.query.entity_types || '';

        const conditions = [];
        const params     = [];

        if (dateFrom) { conditions.push("DATE(a.created_at) >= DATE(?)"); params.push(dateFrom); }
        if (dateTo)   { conditions.push("DATE(a.created_at) <= DATE(?)"); params.push(dateTo);   }

        if (entityTypesRaw) {
            const types = entityTypesRaw.split(',').map(t => t.trim()).filter(Boolean);
            if (types.length > 0) {
                const placeholders = types.map(() => '?').join(', ');
                conditions.push(`a.entity_type IN (${placeholders})`);
                params.push(...types);
            }
        }

        const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

        const total = db.prepare(`SELECT COUNT(*) as count FROM activity_log a ${where}`).get(params).count;

        const rows = db.prepare(`
            SELECT
                a.id, a.action, a.entity_type, a.entity_id, a.description, a.created_at,
                COALESCE(u.username, dh.username, 'System') AS username,
                COALESCE(u.first_name || ' ' || u.last_name, dh.full_name, 'System') AS performed_by
            FROM activity_log a
            LEFT JOIN users u ON a.user_id = u.id
            LEFT JOIN deleted_users_history dh ON a.user_id = dh.deleted_user_id
            ${where}
            ORDER BY a.created_at DESC
            LIMIT ? OFFSET ?
        `).all([...params, limit, offset]);

        res.json({
            activities: rows,
            pagination: { total, page, limit, totalPages: Math.ceil(total / limit) }
        });
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch recent activities', error: error.message });
    }
};
