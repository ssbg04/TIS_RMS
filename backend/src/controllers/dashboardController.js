const db = require('../config/db');
const fs = require('fs');
const path = require('path');


// GET /api/dashboard/stats
exports.getStats = (req, res) => {
    try {
        const isTeacher = req.user?.role?.toLowerCase() === 'teacher';
        const userId = req.user.id;

        let totalStudents;
        let completedDocuments;
        let missingDocuments;
        const activeUsers = db.prepare('SELECT COUNT(*) as count FROM users WHERE is_active = 1').get().count;

        if (isTeacher) {
            // Count of students whose latest enrollment is in teacher's assigned sections
            totalStudents = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id
                    FROM teacher_sections
                    WHERE teacher_id = ?
                )
            `).get(userId).count;

            // Count of students in teacher's sections who have ALL mandatory docs complete
            completedDocuments = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id FROM teacher_sections WHERE teacher_id = ?
                )
                AND NOT EXISTS (
                    SELECT 1
                    FROM document_requirements dr
                    WHERE dr.is_mandatory = 1
                      AND dr.is_enabled = 1
                      AND dr.category IN (
                          SELECT DISTINCT CASE WHEN grade_level <= 10 THEN 'JHS' ELSE 'SHS' END
                          FROM enrollments WHERE student_id = s.id
                      )
                      AND NOT EXISTS (
                          SELECT 1 FROM documents d
                          WHERE d.student_id = s.id
                            AND d.requirement_id = dr.id
                            AND d.status = 'Completed'
                            AND d.deleted_at IS NULL
                      )
                )
            `).get(userId).count;

            // Count of students in teacher's assigned sections who are missing at least one mandatory document
            missingDocuments = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id FROM teacher_sections WHERE teacher_id = ?
                )
                AND EXISTS (
                    SELECT 1
                    FROM document_requirements dr
                    WHERE dr.is_mandatory = 1
                      AND dr.is_enabled = 1
                      AND dr.category IN (
                          SELECT DISTINCT CASE WHEN grade_level <= 10 THEN 'JHS' ELSE 'SHS' END
                          FROM enrollments WHERE student_id = s.id
                      )
                      AND NOT EXISTS (
                          SELECT 1 FROM documents d
                          WHERE d.student_id = s.id
                            AND d.requirement_id = dr.id
                            AND d.status = 'Completed'
                            AND d.deleted_at IS NULL
                      )
                )
            `).get(userId).count;
        } else {
            // Admin: All students
            totalStudents = db.prepare('SELECT COUNT(*) as count FROM students').get().count;

            // Count of students who have ALL mandatory docs complete across all sections
            completedDocuments = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM document_requirements dr
                    WHERE dr.is_mandatory = 1
                      AND dr.is_enabled = 1
                      AND dr.category IN (
                          SELECT DISTINCT CASE WHEN grade_level <= 10 THEN 'JHS' ELSE 'SHS' END
                          FROM enrollments WHERE student_id = s.id
                      )
                      AND NOT EXISTS (
                          SELECT 1 FROM documents d
                          WHERE d.student_id = s.id
                            AND d.requirement_id = dr.id
                            AND d.status = 'Completed'
                            AND d.deleted_at IS NULL
                      )
                )
            `).get().count;

            // Count of students who are missing at least one mandatory document across all sections
            missingDocuments = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                WHERE EXISTS (
                    SELECT 1
                    FROM document_requirements dr
                    WHERE dr.is_mandatory = 1
                      AND dr.is_enabled = 1
                      AND dr.category IN (
                          SELECT DISTINCT CASE WHEN grade_level <= 10 THEN 'JHS' ELSE 'SHS' END
                          FROM enrollments WHERE student_id = s.id
                      )
                      AND NOT EXISTS (
                          SELECT 1 FROM documents d
                          WHERE d.student_id = s.id
                            AND d.requirement_id = dr.id
                            AND d.status = 'Completed'
                            AND d.deleted_at IS NULL
                      )
                )
            `).get().count;
        }

        const hasAssignedSections = isTeacher 
            ? (db.prepare('SELECT COUNT(*) as count FROM teacher_sections WHERE teacher_id = ?').get(userId).count > 0)
            : true;

        res.json({ totalStudents, activeUsers, completedDocuments, missingDocuments, hasAssignedSections });
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch stats', error: error.message });
    }
};

// GET /api/dashboard/recent-activities?page=1&limit=10&date_from=YYYY-MM-DD&date_to=YYYY-MM-DD&entity_types=student,document
exports.getRecentActivities = (req, res) => {
    try {
        const page = Math.max(1, parseInt(req.query.page || '1'));
        const limit = Math.min(50, Math.max(1, parseInt(req.query.limit || '10')));
        const offset = (page - 1) * limit;
        const dateFrom = req.query.date_from || '';
        const dateTo = req.query.date_to || '';
        const action = req.query.action || '';
        // Comma-separated entity type filter, e.g. "student,document" (teacher view)
        const entityTypesRaw = req.query.entity_types || '';

        const conditions = [];
        const params = [];

        if (dateFrom) { conditions.push("DATE(a.created_at) >= DATE(?)"); params.push(dateFrom); }
        if (dateTo) { conditions.push("DATE(a.created_at) <= DATE(?)"); params.push(dateTo); }
        if (action) { conditions.push("a.action = ?"); params.push(action); }

        if (entityTypesRaw) {
            const types = entityTypesRaw.split(',').map(t => t.trim()).filter(Boolean);
            if (types.length > 0) {
                const placeholders = types.map(() => '?').join(', ');
                conditions.push(`a.entity_type IN (${placeholders})`);
                params.push(...types);
            }
        }

        const isTeacher = req.user?.role?.toLowerCase() === 'teacher';
        const teacherId = req.user.id;

        if (isTeacher) {
            conditions.push(`
                (
                    (a.entity_type = 'student' AND a.entity_id IN (
                        SELECT s.id FROM students s
                        JOIN enrollments e ON s.id = e.student_id
                        JOIN teacher_sections ts ON e.section_id = ts.section_id
                        WHERE ts.teacher_id = ? AND e.id = (
                            SELECT e2.id FROM enrollments e2
                            JOIN academic_years ay ON e2.academic_year_id = ay.id
                            WHERE e2.student_id = s.id
                            ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                        )
                    ))
                    OR
                    (a.entity_type = 'document' AND a.entity_id IN (
                        SELECT d.id FROM documents d
                        JOIN enrollments e ON d.student_id = e.student_id
                        JOIN teacher_sections ts ON e.section_id = ts.section_id
                        WHERE ts.teacher_id = ? AND e.id = (
                            SELECT e2.id FROM enrollments e2
                            JOIN academic_years ay ON e2.academic_year_id = ay.id
                            WHERE e2.student_id = e.student_id
                            ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                        )
                    ))
                    OR
                    (a.entity_type = 'enrollment' AND a.entity_id IN (
                        SELECT e.id FROM enrollments e
                        JOIN teacher_sections ts ON e.section_id = ts.section_id
                        WHERE ts.teacher_id = ?
                    ))
                    OR
                    (a.user_id = ?)
                )
            `);
            params.push(teacherId, teacherId, teacherId, teacherId);
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

// ============================================================
// GET /api/dashboard/kpis
// Returns all chart-ready KPI datasets in one call
// ============================================================
exports.getKpis = (req, res) => {
    try {
        const isTeacher = req.user?.role?.toLowerCase() === 'teacher';
        const userId = req.user.id;

        let jhsTotal, shsTotal, jhsDigitized, shsDigitized;
        let activityByDay;
        let statusDistribution;
        let topStudents, bottomStudents;
        let docTypeBreakdown;
        let uploadTrend;
        let fileRows, recentRows, olderRows;

        if (isTeacher) {
            // ── 1. Digitalization (Teacher's Students) ───────────────────────────
            jhsTotal = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id FROM teacher_sections WHERE teacher_id = ?
                )
                AND e.grade_level <= 10
            `).get(userId).count;

            shsTotal = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id FROM teacher_sections WHERE teacher_id = ?
                )
                AND e.grade_level > 10
            `).get(userId).count;

            jhsDigitized = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                JOIN documents d ON d.student_id = s.id AND d.deleted_at IS NULL
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id FROM teacher_sections WHERE teacher_id = ?
                )
                AND e.grade_level <= 10
            `).get(userId).count;

            shsDigitized = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                JOIN documents d ON d.student_id = s.id AND d.deleted_at IS NULL
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id FROM teacher_sections WHERE teacher_id = ?
                )
                AND e.grade_level > 10
            `).get(userId).count;

            // ── 2. Activity by day (Teacher's Activities / Students) ────────────
            activityByDay = db.prepare(`
                SELECT
                    DATE(a.created_at) as day,
                    a.action,
                    a.entity_type,
                    COUNT(*) as count
                FROM activity_log a
                WHERE DATE(a.created_at) >= DATE('now', '-6 days')
                  AND (
                      a.user_id = ?
                      OR (a.entity_type = 'student' AND a.entity_id IN (
                          SELECT s.id FROM students s
                          JOIN enrollments e ON s.id = e.student_id
                          JOIN teacher_sections ts ON e.section_id = ts.section_id
                          WHERE ts.teacher_id = ?
                      ))
                      OR (a.entity_type = 'document' AND a.entity_id IN (
                          SELECT d.id FROM documents d
                          JOIN enrollments e ON d.student_id = e.student_id
                          JOIN teacher_sections ts ON e.section_id = ts.section_id
                          WHERE ts.teacher_id = ?
                      ))
                  )
                GROUP BY day, a.action, a.entity_type
                ORDER BY day ASC
            `).all(userId, userId, userId);

            // ── 3. Document status distribution (Teacher's Students) ─────────────
            const statusRows = db.prepare(`
                SELECT d.status, COUNT(*) as count
                FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id FROM teacher_sections WHERE teacher_id = ?
                )
                AND d.deleted_at IS NULL
                GROUP BY d.status
            `).all(userId);
            statusDistribution = statusRows.map(r => ({ status: r.status, count: r.count }));

            // ── 4. Top & bottom students (Teacher's Students) ──────────────────
            const studentDocCounts = db.prepare(`
                SELECT
                    s.id,
                    s.first_name || ' ' || s.last_name as name,
                    COUNT(d.id) as doc_count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                LEFT JOIN documents d ON d.student_id = s.id AND d.deleted_at IS NULL
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id FROM teacher_sections WHERE teacher_id = ?
                )
                GROUP BY s.id
                ORDER BY doc_count DESC
            `).all(userId);

            topStudents = studentDocCounts.slice(0, 5);
            bottomStudents = [...studentDocCounts].sort((a, b) => a.doc_count - b.doc_count).slice(0, 5);

            // ── 5. Document type breakdown (Teacher's Students) ────────────────
            const typeRows = db.prepare(`
                SELECT
                    COALESCE(dr.name, d.document_type, 'Uncategorized') as type_name,
                    COUNT(*) as count
                FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id FROM teacher_sections WHERE teacher_id = ?
                )
                AND d.deleted_at IS NULL
                GROUP BY type_name
                ORDER BY count DESC
                LIMIT 10
            `).all(userId);
            docTypeBreakdown = typeRows.map(r => ({ name: r.type_name, count: r.count }));

            // ── 6. Upload trend (Teacher's Students) ───────────────────────────
            uploadTrend = db.prepare(`
                SELECT
                    DATE(d.created_at) as day,
                    COUNT(*) as count
                FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id FROM teacher_sections WHERE teacher_id = ?
                )
                AND DATE(d.created_at) >= DATE('now', '-29 days')
                AND d.deleted_at IS NULL
                GROUP BY day
                ORDER BY day ASC
            `).all(userId);

            // ── 7. Storage analytics (Teacher's Students) ──────────────────────
            fileRows = db.prepare(`
                SELECT d.file_path, d.document_type,
                       COALESCE(dr.name, d.document_type, 'Uncategorized') as type_name
                FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id FROM teacher_sections WHERE teacher_id = ?
                )
                AND d.deleted_at IS NULL
            `).all(userId);

            recentRows = db.prepare(`
                SELECT d.file_path FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id FROM teacher_sections WHERE teacher_id = ?
                )
                AND d.deleted_at IS NULL
                AND d.created_at >= datetime('now', '-30 days')
            `).all(userId);

            olderRows = db.prepare(`
                SELECT d.file_path FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
                AND e.section_id IN (
                    SELECT section_id FROM teacher_sections WHERE teacher_id = ?
                )
                AND d.deleted_at IS NULL
                AND d.created_at >= datetime('now', '-60 days')
                AND d.created_at < datetime('now', '-30 days')
            `).all(userId);
        } else {
            // Admin: All students across the school
            // ── 1. Digitalization — JHS/SHS donut ───────────────────────────
            jhsTotal = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.grade_level <= 10
            `).get().count;

            shsTotal = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.grade_level > 10
            `).get().count;

            jhsDigitized = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN documents d ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.grade_level <= 10 AND d.deleted_at IS NULL
            `).get().count;

            shsDigitized = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN documents d ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.grade_level > 10 AND d.deleted_at IS NULL
            `).get().count;

            // ── 2. Activity by day — last 7 days bar chart ──────────────────
            activityByDay = db.prepare(`
                SELECT
                    DATE(created_at) as day,
                    action,
                    entity_type,
                    COUNT(*) as count
                FROM activity_log
                WHERE DATE(created_at) >= DATE('now', '-6 days')
                GROUP BY day, action, entity_type
                ORDER BY day ASC
            `).all();

            // ── 3. Document status distribution ─────────────────────────────
            const statusRows = db.prepare(`
                SELECT status, COUNT(*) as count
                FROM documents
                WHERE deleted_at IS NULL
                GROUP BY status
            `).all();
            statusDistribution = statusRows.map(r => ({ status: r.status, count: r.count }));

            // ── 4. Top & bottom students by document count ──────────────────
            const studentDocCounts = db.prepare(`
                SELECT
                    s.id,
                    s.first_name || ' ' || s.last_name as name,
                    COUNT(d.id) as doc_count
                FROM students s
                LEFT JOIN documents d ON d.student_id = s.id AND d.deleted_at IS NULL
                GROUP BY s.id
                ORDER BY doc_count DESC
            `).all();

            topStudents = studentDocCounts.slice(0, 5);
            bottomStudents = [...studentDocCounts].sort((a, b) => a.doc_count - b.doc_count).slice(0, 5);

            // ── 5. Document type breakdown pie ──────────────────────────────
            const typeRows = db.prepare(`
                SELECT
                    COALESCE(dr.name, d.document_type, 'Uncategorized') as type_name,
                    COUNT(*) as count
                FROM documents d
                LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
                WHERE d.deleted_at IS NULL
                GROUP BY type_name
                ORDER BY count DESC
                LIMIT 10
            `).all();
            docTypeBreakdown = typeRows.map(r => ({ name: r.type_name, count: r.count }));

            // ── 6. Upload trend — last 30 days line chart ───────────────────
            uploadTrend = db.prepare(`
                SELECT
                    DATE(created_at) as day,
                    COUNT(*) as count
                FROM documents
                WHERE DATE(created_at) >= DATE('now', '-29 days')
                  AND deleted_at IS NULL
                GROUP BY day
                ORDER BY day ASC
            `).all();

            // ── 7. Storage analytics — compute sizes from disk ──────────────
            fileRows = db.prepare(`
                SELECT file_path, document_type,
                       COALESCE(dr.name, document_type, 'Uncategorized') as type_name
                FROM documents d
                LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
                WHERE deleted_at IS NULL
            `).all();

            recentRows = db.prepare(`
                SELECT file_path FROM documents
                WHERE deleted_at IS NULL
                  AND created_at >= datetime('now', '-30 days')
            `).all();

            olderRows = db.prepare(`
                SELECT file_path FROM documents
                WHERE deleted_at IS NULL
                  AND created_at >= datetime('now', '-60 days')
                  AND created_at < datetime('now', '-30 days')
            `).all();
        }

        const digitalization = {
            jhs: { total: jhsTotal, digitized: jhsDigitized },
            shs: { total: shsTotal, digitized: shsDigitized },
            overall: {
                total: jhsTotal + shsTotal,
                digitized: jhsDigitized + shsDigitized,
            },
        };

        let totalBytes = 0;
        const byType = {};
        let filesWithSize = 0;

        for (const row of fileRows) {
            try {
                if (row.file_path && fs.existsSync(row.file_path)) {
                    const size = fs.statSync(row.file_path).size;
                    totalBytes += size;
                    filesWithSize++;
                    const key = row.type_name || 'Uncategorized';
                    byType[key] = (byType[key] || 0) + size;
                }
            } catch (_) { /* skip inaccessible files */ }
        }

        // Growth rate: bytes added in last 30 days vs prior 30 days
        const sumSize = (rows) => rows.reduce((acc, r) => {
            try {
                if (r.file_path && fs.existsSync(r.file_path)) {
                    return acc + fs.statSync(r.file_path).size;
                }
            } catch (_) {}
            return acc;
        }, 0);

        const recentBytes = sumSize(recentRows);
        const olderBytes = sumSize(olderRows);
        const growthRate = olderBytes > 0
            ? Math.round(((recentBytes - olderBytes) / olderBytes) * 100)
            : (recentBytes > 0 ? 100 : 0);

        const storageAnalytics = {
            totalBytes,
            totalFiles: fileRows.length,
            filesWithSize,
            byType: Object.entries(byType)
                .sort((a, b) => b[1] - a[1])
                .slice(0, 8)
                .map(([name, bytes]) => ({ name, bytes })),
            growthRate,
            recentBytes,
        };

        res.json({
            digitalization,
            activityByDay,
            statusDistribution,
            topStudents,
            bottomStudents,
            docTypeBreakdown,
            uploadTrend,
            storageAnalytics,
        });
    } catch (error) {
        console.error('getKpis error:', error);
        res.status(500).json({ message: 'Failed to fetch KPIs', error: error.message });
    }
};
