const db = require('../config/db');

// GET /api/reports/academic-years
exports.getAcademicYears = (req, res) => {
    try {
        const years = db.prepare('SELECT * FROM academic_years ORDER BY id DESC').all();
        res.json(years);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch academic years', error: error.message });
    }
};

// GET /api/reports/stats?academicYearId=1&gradeLevel=7&sectionId=2&status=Enrolled
exports.getStats = (req, res) => {
    const { academicYearId, gradeLevel, sectionId, status } = req.query;
    try {
        let params = [];
        let enrollParams = [];
        let whereClauses = [];
        let enrollWhereClauses = [];

        if (academicYearId) {
            whereClauses.push('e.academic_year_id = ?');
            enrollWhereClauses.push('e.academic_year_id = ?');
            params.push(academicYearId);
            enrollParams.push(academicYearId);
        }
        if (gradeLevel) {
            whereClauses.push('e.grade_level = ?');
            enrollWhereClauses.push('e.grade_level = ?');
            params.push(gradeLevel);
            enrollParams.push(gradeLevel);
        }
        if (sectionId) {
            whereClauses.push('e.section_id = ?');
            enrollWhereClauses.push('e.section_id = ?');
            params.push(sectionId);
            enrollParams.push(sectionId);
        }

        const whereSql = whereClauses.length > 0 ? 'AND ' + whereClauses.join(' AND ') : '';
        const enrollWhereSql = enrollWhereClauses.length > 0 ? 'AND ' + enrollWhereClauses.join(' AND ') : '';

        // 1. Fetch counts of active, dropped, transferee, graduated
        const countsQuery = `
            SELECT 
                COUNT(DISTINCT CASE WHEN s.status = 'Enrolled' THEN s.id END) as active,
                COUNT(DISTINCT CASE WHEN s.status = 'Dropped' THEN s.id END) as dropped,
                COUNT(DISTINCT CASE WHEN s.status = 'Transferred' THEN s.id END) as transferee,
                COUNT(DISTINCT CASE WHEN s.status = 'Graduated' THEN s.id END) as graduated
            FROM students s
            LEFT JOIN enrollments e ON s.id = e.student_id
            WHERE 1=1 ${enrollWhereSql}
        `;
        const studentCounts = db.prepare(countsQuery).get(enrollParams);

        // 2. Fetch missing documents count per requirement type
        const missingQuery = `
            SELECT r.id as requirementId, r.category || ' - ' || r.name as name, COUNT(DISTINCT s.id) as count
            FROM document_requirements r
            CROSS JOIN students s
            JOIN enrollments e ON s.id = e.student_id
            WHERE r.is_enabled = 1
              AND (
                  (r.category = 'JHS' AND e.grade_level BETWEEN 7 AND 10)
                  OR (r.category = 'SHS' AND e.grade_level BETWEEN 11 AND 12)
              )
              ${whereSql}
              AND NOT EXISTS (
                  SELECT 1 FROM documents d 
                  WHERE d.student_id = s.id 
                    AND d.requirement_id = r.id 
                    AND d.status IN ('Completed', 'Archived')
              )
            GROUP BY r.id, r.category, r.name
            ORDER BY count DESC
        `;
        const missingDocsBreakdown = db.prepare(missingQuery).all(params);

        // 3. Fetch students details list (filtered)
        let studentFilterSql = whereSql;
        let studentParams = [...params];
        if (status) {
            studentFilterSql += " AND s.status = ?";
            studentParams.push(status);
        }

        const studentsQuery = `
            SELECT s.id, s.lrn, s.first_name, s.last_name, s.sex, s.status,
                   MAX(e.grade_level) as grade_level, sec.name as section_name,
                   (
                       SELECT COUNT(*) 
                       FROM document_requirements r
                       WHERE r.is_enabled = 1
                         AND (
                             (r.category = 'JHS' AND MAX(e.grade_level) BETWEEN 7 AND 10)
                             OR (r.category = 'SHS' AND MAX(e.grade_level) BETWEEN 11 AND 12)
                         )
                         AND NOT EXISTS (
                             SELECT 1 FROM documents d 
                             WHERE d.student_id = s.id 
                               AND d.requirement_id = r.id 
                               AND d.status IN ('Completed', 'Archived')
                         )
                   ) as missing_count,
                   (
                       SELECT group_concat('[' || r.category || '] ' || r.name, ', ')
                       FROM document_requirements r
                       WHERE r.is_enabled = 1
                         AND (
                             (r.category = 'JHS' AND MAX(e.grade_level) BETWEEN 7 AND 10)
                             OR (r.category = 'SHS' AND MAX(e.grade_level) BETWEEN 11 AND 12)
                         )
                         AND NOT EXISTS (
                             SELECT 1 FROM documents d 
                             WHERE d.student_id = s.id 
                               AND d.requirement_id = r.id 
                               AND d.status IN ('Completed', 'Archived')
                         )
                   ) as missing_requirements
            FROM students s
            JOIN enrollments e ON s.id = e.student_id
            LEFT JOIN sections sec ON e.section_id = sec.id
            WHERE 1=1 ${studentFilterSql}
            GROUP BY s.id
            ORDER BY s.last_name ASC, s.first_name ASC
            LIMIT 1000
        `;
        const studentsList = db.prepare(studentsQuery).all(studentParams);

        res.json({
            studentCounts,
            missingDocsBreakdown,
            students: studentsList
        });
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch report stats', error: error.message });
    }
};

// GET /api/reports/enrollment-by-grade?academicYearId=1
exports.getEnrollmentByGrade = (req, res) => {
    const { academicYearId } = req.query;
    try {
        let rows;
        if (academicYearId) {
            rows = db.prepare(`
                SELECT grade_level, COUNT(*) as count
                FROM enrollments
                WHERE academic_year_id = ?
                GROUP BY grade_level
                ORDER BY grade_level ASC
            `).all(academicYearId);
        } else {
            rows = db.prepare(`
                SELECT grade_level, COUNT(*) as count
                FROM enrollments
                GROUP BY grade_level
                ORDER BY grade_level ASC
            `).all();
        }
        res.json(rows);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch enrollment data', error: error.message });
    }
};

// GET /api/reports/document-status
exports.getDocumentStatus = (req, res) => {
    try {
        const rows = db.prepare(`
            SELECT status, COUNT(*) as count FROM documents GROUP BY status
        `).all();
        const result = { Completed: 0, Archived: 0 };
        rows.forEach(r => { if (r.status in result) result[r.status] = r.count; });
        res.json(result);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch document status', error: error.message });
    }
};

// GET /api/reports/export-data?academicYearId=1  — Full data payload for Excel export
exports.getExportData = (req, res) => {
    const { academicYearId } = req.query;
    try {
        // Enrollment summary per grade level
        let enrollmentByGrade;
        if (academicYearId) {
            enrollmentByGrade = db.prepare(`
                SELECT e.grade_level, COUNT(DISTINCT e.student_id) as total_students,
                       ay.year_range
                FROM enrollments e
                JOIN academic_years ay ON e.academic_year_id = ay.id
                WHERE e.academic_year_id = ?
                GROUP BY e.grade_level
                ORDER BY e.grade_level ASC
            `).all(academicYearId);
        } else {
            enrollmentByGrade = db.prepare(`
                SELECT e.grade_level, COUNT(DISTINCT e.student_id) as total_students,
                       'All Years' as year_range
                FROM enrollments e
                GROUP BY e.grade_level
                ORDER BY e.grade_level ASC
            `).all();
        }

        // Document status breakdown
        const docStatusRows = db.prepare(`
            SELECT status, COUNT(*) as count FROM documents GROUP BY status
        `).all();
        const documentStatus = { Completed: 0, Archived: 0 };
        docStatusRows.forEach(r => { if (r.status in documentStatus) documentStatus[r.status] = r.count; });

        // Student detail list with document compliance
        let students;
        if (academicYearId) {
            students = db.prepare(`
                SELECT s.lrn, s.first_name, s.last_name, s.sex, e.grade_level,
                       COUNT(CASE WHEN d.status = 'Completed' THEN 1 END) as verified_docs,
                       COUNT(CASE WHEN d.status = 'Archived' THEN 1 END) as archived_docs
                FROM students s
                JOIN enrollments e ON s.id = e.student_id AND e.academic_year_id = ?
                LEFT JOIN documents d ON s.id = d.student_id
                GROUP BY s.id
                ORDER BY s.last_name ASC
                LIMIT 500
            `).all(academicYearId);
        } else {
            students = db.prepare(`
                SELECT s.lrn, s.first_name, s.last_name, s.sex,
                       MAX(e.grade_level) as grade_level,
                       COUNT(CASE WHEN d.status = 'Completed' THEN 1 END) as verified_docs,
                       COUNT(CASE WHEN d.status = 'Archived' THEN 1 END) as archived_docs
                FROM students s
                LEFT JOIN enrollments e ON s.id = e.student_id
                LEFT JOIN documents d ON s.id = d.student_id
                GROUP BY s.id
                ORDER BY s.last_name ASC
                LIMIT 500
            `).all();
        }

        res.json({ enrollmentByGrade, documentStatus, students });
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch export data', error: error.message });
    }
};

// GET /api/reports/yearly-comparison
exports.getYearlyComparison = (req, res) => {
    try {
        const query = `
            SELECT 
                ay.year_range as year,
                COUNT(DISTINCT CASE WHEN (CASE WHEN e.academic_year_id = sly.max_ay_id THEN s.status ELSE 'Enrolled' END) = 'Enrolled' THEN s.id END) as enrolled,
                COUNT(DISTINCT CASE WHEN (CASE WHEN e.academic_year_id = sly.max_ay_id THEN s.status ELSE 'Enrolled' END) = 'Dropped' THEN s.id END) as dropped,
                COUNT(DISTINCT CASE WHEN (CASE WHEN e.academic_year_id = sly.max_ay_id THEN s.status ELSE 'Enrolled' END) = 'Graduated' THEN s.id END) as graduated,
                COUNT(DISTINCT CASE WHEN (CASE WHEN e.academic_year_id = sly.max_ay_id THEN s.status ELSE 'Enrolled' END) = 'Transferred' THEN s.id END) as transferred
            FROM academic_years ay
            LEFT JOIN enrollments e ON ay.id = e.academic_year_id
            LEFT JOIN students s ON e.student_id = s.id
            LEFT JOIN (
                SELECT e1.student_id, e1.academic_year_id as max_ay_id
                FROM enrollments e1
                JOIN academic_years ay1 ON e1.academic_year_id = ay1.id
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM enrollments e2
                    JOIN academic_years ay2 ON e2.academic_year_id = ay2.id
                    WHERE e2.student_id = e1.student_id
                      AND ay2.year_range > ay1.year_range
                )
            ) sly ON s.id = sly.student_id
            GROUP BY ay.id, ay.year_range
            ORDER BY ay.id DESC
            LIMIT 5
        `;
        const data = db.prepare(query).all();
        // Return oldest first for charting (left to right)
        res.json(data.reverse());
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch yearly comparison', error: error.message });
    }
};
