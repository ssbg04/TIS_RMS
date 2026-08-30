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

        // Resolve Active Academic Year
        const activeAy = db.prepare("SELECT * FROM academic_years WHERE status = 'active' LIMIT 1").get()
            || db.prepare("SELECT * FROM academic_years ORDER BY year_range DESC LIMIT 1").get();
        const activeAyId = activeAy?.id;

        // Mandatory Requirements by Category
        const jhsReqs = db.prepare("SELECT id, name FROM document_requirements WHERE category = 'JHS' AND is_mandatory = 1 AND is_enabled = 1").all();
        const shsReqs = db.prepare("SELECT id, name FROM document_requirements WHERE category = 'SHS' AND is_mandatory = 1 AND is_enabled = 1").all();

        let jhsTotal, shsTotal, jhsDigitized, shsDigitized;
        let activityByDay;
        let statusDistribution;
        let topStudents, bottomStudents;
        let docTypeBreakdown;
        let docTypeByGrade = {};
        let uploadTrend;
        let fileRows, recentRows, olderRows;

        if (isTeacher) {
            // ── 1. Digitalization (Teacher's Students in Active Year) ───────────────────
            jhsTotal = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
                  AND e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)
                  AND e.grade_level <= 10
            `).get(activeAyId, userId).count;

            shsTotal = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
                  AND e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)
                  AND e.grade_level > 10
            `).get(activeAyId, userId).count;

            jhsDigitized = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
                  AND e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)
                  AND e.grade_level <= 10
                  AND NOT EXISTS (
                      SELECT 1
                      FROM document_requirements dr
                      WHERE dr.category = 'JHS'
                        AND dr.is_mandatory = 1
                        AND dr.is_enabled = 1
                        AND NOT EXISTS (
                            SELECT 1 FROM documents d
                            WHERE d.student_id = s.id
                              AND d.requirement_id = dr.id
                              AND d.status = 'Completed'
                              AND d.deleted_at IS NULL
                        )
                  )
            `).get(activeAyId, userId).count;

            shsDigitized = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
                  AND e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)
                  AND e.grade_level > 10
                  AND NOT EXISTS (
                      SELECT 1
                      FROM document_requirements dr
                      WHERE dr.category = 'SHS'
                        AND dr.is_mandatory = 1
                        AND dr.is_enabled = 1
                        AND NOT EXISTS (
                            SELECT 1 FROM documents d
                            WHERE d.student_id = s.id
                              AND d.requirement_id = dr.id
                              AND d.status = 'Completed'
                              AND d.deleted_at IS NULL
                        )
                  )
            `).get(activeAyId, userId).count;

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
                          WHERE ts.teacher_id = ? AND e.academic_year_id = ?
                      ))
                      OR (a.entity_type = 'document' AND a.entity_id IN (
                          SELECT d.id FROM documents d
                          JOIN enrollments e ON d.student_id = e.student_id
                          JOIN teacher_sections ts ON e.section_id = ts.section_id
                          WHERE ts.teacher_id = ? AND e.academic_year_id = ?
                      ))
                  )
                GROUP BY day, a.action, a.entity_type
                ORDER BY day ASC
            `).all(userId, userId, activeAyId, userId, activeAyId);

            // ── 3. Document status distribution (count by distinct document types uploaded) ──
            const statusRows = db.prepare(`
                SELECT d.status, COUNT(DISTINCT d.student_id || '-' || COALESCE(d.requirement_id, d.document_type)) as count
                FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
                  AND e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)
                  AND d.deleted_at IS NULL
                GROUP BY d.status
            `).all(activeAyId, userId);
            statusDistribution = statusRows.map(r => ({ status: r.status, count: r.count }));

            // ── 4. Top & bottom students (Required Document Type Count over Total Required) ──
            const enrolledStudents = db.prepare(`
                SELECT s.id, s.first_name || ' ' || s.last_name as name, e.grade_level,
                       CASE WHEN e.grade_level <= 10 THEN 'JHS' ELSE 'SHS' END as category
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
                  AND e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)
            `).all(activeAyId, userId);

            const studentDocStats = enrolledStudents.map(s => {
                const reqs = s.category === 'JHS' ? jhsReqs : shsReqs;
                const totalRequired = reqs.length;
                const reqIds = reqs.map(r => r.id);
                let uploadedCount = 0;
                if (reqIds.length > 0) {
                    uploadedCount = db.prepare(`
                        SELECT COUNT(DISTINCT requirement_id) as count
                        FROM documents
                        WHERE student_id = ? AND requirement_id IN (${reqIds.join(',')})
                          AND status = 'Completed' AND deleted_at IS NULL
                    `).get(s.id).count;
                }
                const missingCount = Math.max(0, totalRequired - uploadedCount);
                return {
                    id: s.id,
                    name: s.name,
                    gradeLevel: s.grade_level,
                    category: s.category,
                    uploadedCount,
                    totalRequired,
                    missingCount,
                    docCount: uploadedCount,
                    percent: totalRequired === 0 ? 1.0 : uploadedCount / totalRequired
                };
            });

            topStudents = [...studentDocStats]
                .sort((a, b) => b.uploadedCount - a.uploadedCount || a.missingCount - b.missingCount || a.name.localeCompare(b.name))
                .slice(0, 5);

            bottomStudents = [...studentDocStats]
                .sort((a, b) => b.missingCount - a.missingCount || a.uploadedCount - b.uploadedCount || a.name.localeCompare(b.name))
                .slice(0, 5);

            // ── 5. Document type breakdown overall + by Grade Level (Separated by JHS & SHS) ──
            const typeRows = db.prepare(`
                SELECT
                    COALESCE(
                        CASE 
                            WHEN dr.category IS NOT NULL THEN dr.category || ' - ' || dr.name
                            WHEN d.document_type LIKE 'JHS - %' OR d.document_type LIKE 'SHS - %' THEN d.document_type
                            WHEN e.grade_level <= 10 THEN 'JHS - ' || COALESCE(dr.name, d.document_type)
                            WHEN e.grade_level > 10 THEN 'SHS - ' || COALESCE(dr.name, d.document_type)
                            ELSE COALESCE(dr.name, d.document_type)
                        END,
                        'Uncategorized'
                    ) as type_name,
                    COUNT(DISTINCT d.student_id) as count
                FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
                WHERE e.academic_year_id = ?
                  AND e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)
                  AND d.deleted_at IS NULL
                  AND d.status = 'Completed'
                GROUP BY type_name
                ORDER BY count DESC
            `).all(activeAyId, userId);
            docTypeBreakdown = typeRows.map(r => ({ name: r.type_name, count: r.count }));

            // Compute Grade Level Breakdown for each Document Requirement separated by JHS / SHS
            const gradeTotalsRows = db.prepare(`
                SELECT e.grade_level, COUNT(DISTINCT s.id) as total_students
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
                  AND e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)
                GROUP BY e.grade_level
                ORDER BY e.grade_level ASC
            `).all(activeAyId, userId);

            const gradeTotalsMap = {};
            for (const row of gradeTotalsRows) {
                gradeTotalsMap[row.grade_level] = row.total_students;
            }

            const reqRows = db.prepare(`
                SELECT id, category, name 
                FROM document_requirements 
                WHERE is_enabled = 1 
                ORDER BY category ASC, name ASC
            `).all();

            for (const req of reqRows) {
                const isJhs = req.category === 'JHS';
                const minGrade = isJhs ? 7 : 11;
                const maxGrade = isJhs ? 10 : 12;

                const countsByGrade = db.prepare(`
                    SELECT e.grade_level, COUNT(DISTINCT d.student_id) as uploaded_count
                    FROM documents d
                    JOIN students s ON d.student_id = s.id
                    JOIN enrollments e ON s.id = e.student_id
                    LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
                    WHERE e.academic_year_id = ?
                      AND e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)
                      AND e.grade_level BETWEEN ? AND ?
                      AND (d.requirement_id = ? OR dr.name = ? OR d.document_type = ? OR d.document_type = ?)
                      AND d.deleted_at IS NULL
                      AND d.status = 'Completed'
                    GROUP BY e.grade_level
                `).all(activeAyId, userId, minGrade, maxGrade, req.id, req.name, req.name, `${req.category} - ${req.name}`);

                const uploadedMap = {};
                for (const r of countsByGrade) {
                    uploadedMap[r.grade_level] = r.uploaded_count;
                }

                const key = `${req.category} - ${req.name}`;
                const targetGrades = isJhs ? [7, 8, 9, 10] : [11, 12];

                docTypeByGrade[key] = targetGrades.map(g => {
                    const uploaded = uploadedMap[g] || 0;
                    const total = gradeTotalsMap[g] || 0;
                    return {
                        gradeLevel: `Grade ${g}`,
                        grade: g,
                        category: req.category,
                        count: uploaded,
                        totalStudents: total,
                        percent: total === 0 ? 0 : uploaded / total
                    };
                });
            }

            // ── 6. Upload trend (Teacher's Students) ───────────────────────────
            uploadTrend = db.prepare(`
                SELECT
                    DATE(d.created_at) as day,
                    COUNT(*) as count
                FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
                  AND e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)
                  AND DATE(d.created_at) >= DATE('now', '-29 days')
                  AND d.deleted_at IS NULL
                GROUP BY day
                ORDER BY day ASC
            `).all(activeAyId, userId);

            // ── 7. Storage analytics ──────────────────────────────────────────
            fileRows = db.prepare(`
                SELECT d.file_path, d.document_type,
                       COALESCE(dr.name, d.document_type, 'Uncategorized') as type_name
                FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
                WHERE e.academic_year_id = ?
                  AND e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)
                  AND d.deleted_at IS NULL
            `).all(activeAyId, userId);

            recentRows = db.prepare(`
                SELECT d.file_path FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
                  AND e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)
                  AND d.deleted_at IS NULL
                  AND d.created_at >= datetime('now', '-30 days')
            `).all(activeAyId, userId);

            olderRows = db.prepare(`
                SELECT d.file_path FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
                  AND e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)
                  AND d.deleted_at IS NULL
                  AND d.created_at >= datetime('now', '-60 days')
                  AND d.created_at < datetime('now', '-30 days')
            `).all(activeAyId, userId);
        } else {
            // Admin: All students across the school in active academic year
            // ── 1. Digitalization — JHS/SHS donut ───────────────────────────
            jhsTotal = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ? AND e.grade_level <= 10
            `).get(activeAyId).count;

            shsTotal = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ? AND e.grade_level > 10
            `).get(activeAyId).count;

            jhsDigitized = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
                  AND e.grade_level <= 10
                  AND NOT EXISTS (
                      SELECT 1
                      FROM document_requirements dr
                      WHERE dr.category = 'JHS'
                        AND dr.is_mandatory = 1
                        AND dr.is_enabled = 1
                        AND NOT EXISTS (
                            SELECT 1 FROM documents d
                            WHERE d.student_id = s.id
                              AND d.requirement_id = dr.id
                              AND d.status = 'Completed'
                              AND d.deleted_at IS NULL
                        )
                  )
            `).get(activeAyId).count;

            shsDigitized = db.prepare(`
                SELECT COUNT(DISTINCT s.id) as count
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
                  AND e.grade_level > 10
                  AND NOT EXISTS (
                      SELECT 1
                      FROM document_requirements dr
                      WHERE dr.category = 'SHS'
                        AND dr.is_mandatory = 1
                        AND dr.is_enabled = 1
                        AND NOT EXISTS (
                            SELECT 1 FROM documents d
                            WHERE d.student_id = s.id
                              AND d.requirement_id = dr.id
                              AND d.status = 'Completed'
                              AND d.deleted_at IS NULL
                        )
                  )
            `).get(activeAyId).count;

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

            // ── 3. Document status distribution (count by distinct document types uploaded) ──
            const statusRows = db.prepare(`
                SELECT d.status, COUNT(DISTINCT d.student_id || '-' || COALESCE(d.requirement_id, d.document_type)) as count
                FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ? AND d.deleted_at IS NULL
                GROUP BY d.status
            `).all(activeAyId);
            statusDistribution = statusRows.map(r => ({ status: r.status, count: r.count }));

            // ── 4. Top & bottom students by required document types ─────────
            const enrolledStudents = db.prepare(`
                SELECT s.id, s.first_name || ' ' || s.last_name as name, e.grade_level,
                       CASE WHEN e.grade_level <= 10 THEN 'JHS' ELSE 'SHS' END as category
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
            `).all(activeAyId);

            const studentDocStats = enrolledStudents.map(s => {
                const reqs = s.category === 'JHS' ? jhsReqs : shsReqs;
                const totalRequired = reqs.length;
                const reqIds = reqs.map(r => r.id);
                let uploadedCount = 0;
                if (reqIds.length > 0) {
                    uploadedCount = db.prepare(`
                        SELECT COUNT(DISTINCT requirement_id) as count
                        FROM documents
                        WHERE student_id = ? AND requirement_id IN (${reqIds.join(',')})
                          AND status = 'Completed' AND deleted_at IS NULL
                    `).get(s.id).count;
                }
                const missingCount = Math.max(0, totalRequired - uploadedCount);
                return {
                    id: s.id,
                    name: s.name,
                    gradeLevel: s.grade_level,
                    category: s.category,
                    uploadedCount,
                    totalRequired,
                    missingCount,
                    docCount: uploadedCount,
                    percent: totalRequired === 0 ? 1.0 : uploadedCount / totalRequired
                };
            });

            topStudents = [...studentDocStats]
                .sort((a, b) => b.uploadedCount - a.uploadedCount || a.missingCount - b.missingCount || a.name.localeCompare(b.name))
                .slice(0, 5);

            bottomStudents = [...studentDocStats]
                .sort((a, b) => b.missingCount - a.missingCount || a.uploadedCount - b.uploadedCount || a.name.localeCompare(b.name))
                .slice(0, 5);

            // ── 5. Document type breakdown overall + by Grade Level (Separated by JHS & SHS) ──
            const typeRows = db.prepare(`
                SELECT
                    COALESCE(
                        CASE 
                            WHEN dr.category IS NOT NULL THEN dr.category || ' - ' || dr.name
                            WHEN d.document_type LIKE 'JHS - %' OR d.document_type LIKE 'SHS - %' THEN d.document_type
                            WHEN e.grade_level <= 10 THEN 'JHS - ' || COALESCE(dr.name, d.document_type)
                            WHEN e.grade_level > 10 THEN 'SHS - ' || COALESCE(dr.name, d.document_type)
                            ELSE COALESCE(dr.name, d.document_type)
                        END,
                        'Uncategorized'
                    ) as type_name,
                    COUNT(DISTINCT d.student_id) as count
                FROM documents d
                JOIN students s ON d.student_id = s.id
                JOIN enrollments e ON s.id = e.student_id
                LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
                WHERE e.academic_year_id = ?
                  AND d.deleted_at IS NULL
                  AND d.status = 'Completed'
                GROUP BY type_name
                ORDER BY count DESC
            `).all(activeAyId);
            docTypeBreakdown = typeRows.map(r => ({ name: r.type_name, count: r.count }));

            // Compute Grade Level Breakdown for each Document Requirement separated by JHS / SHS
            const gradeTotalsRows = db.prepare(`
                SELECT e.grade_level, COUNT(DISTINCT s.id) as total_students
                FROM students s
                JOIN enrollments e ON s.id = e.student_id
                WHERE e.academic_year_id = ?
                GROUP BY e.grade_level
                ORDER BY e.grade_level ASC
            `).all(activeAyId);

            const gradeTotalsMap = {};
            for (const row of gradeTotalsRows) {
                gradeTotalsMap[row.grade_level] = row.total_students;
            }

            const reqRows = db.prepare(`
                SELECT id, category, name 
                FROM document_requirements 
                WHERE is_enabled = 1 
                ORDER BY category ASC, name ASC
            `).all();

            for (const req of reqRows) {
                const isJhs = req.category === 'JHS';
                const minGrade = isJhs ? 7 : 11;
                const maxGrade = isJhs ? 10 : 12;

                const countsByGrade = db.prepare(`
                    SELECT e.grade_level, COUNT(DISTINCT d.student_id) as uploaded_count
                    FROM documents d
                    JOIN students s ON d.student_id = s.id
                    JOIN enrollments e ON s.id = e.student_id
                    LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
                    WHERE e.academic_year_id = ?
                      AND e.grade_level BETWEEN ? AND ?
                      AND (d.requirement_id = ? OR dr.name = ? OR d.document_type = ? OR d.document_type = ?)
                      AND d.deleted_at IS NULL
                      AND d.status = 'Completed'
                    GROUP BY e.grade_level
                `).all(activeAyId, minGrade, maxGrade, req.id, req.name, req.name, `${req.category} - ${req.name}`);

                const uploadedMap = {};
                for (const r of countsByGrade) {
                    uploadedMap[r.grade_level] = r.uploaded_count;
                }

                const key = `${req.category} - ${req.name}`;
                const targetGrades = isJhs ? [7, 8, 9, 10] : [11, 12];

                docTypeByGrade[key] = targetGrades.map(g => {
                    const uploaded = uploadedMap[g] || 0;
                    const total = gradeTotalsMap[g] || 0;
                    return {
                        gradeLevel: `Grade ${g}`,
                        grade: g,
                        category: req.category,
                        count: uploaded,
                        totalStudents: total,
                        percent: total === 0 ? 0 : uploaded / total
                    };
                });
            }

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
            docTypeByGrade,
            uploadTrend,
            storageAnalytics,
            activeAcademicYear: activeAy?.year_range || null
        });
    } catch (error) {
        console.error('getKpis error:', error);
        res.status(500).json({ message: 'Failed to fetch KPIs', error: error.message });
    }
};
