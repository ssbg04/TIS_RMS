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

// GET /api/reports/stats?academicYearId=1
exports.getStats = (req, res) => {
    const { academicYearId } = req.query;
    try {
        let totalStudents;
        if (academicYearId) {
            totalStudents = db.prepare(
                'SELECT COUNT(DISTINCT student_id) as count FROM enrollments WHERE academic_year_id = ?'
            ).get(academicYearId).count;
        } else {
            totalStudents = db.prepare('SELECT COUNT(*) as count FROM students').get().count;
        }

        const pendingDocs = db.prepare("SELECT COUNT(*) as count FROM documents WHERE status = 'Pending'").get().count;
        const verifiedDocs = db.prepare("SELECT COUNT(*) as count FROM documents WHERE status = 'Verified'").get().count;
        const printQueueCount = db.prepare('SELECT COUNT(*) as count FROM print_queue').get().count;
        const totalDocs = pendingDocs + verifiedDocs;
        const verificationRate = totalDocs > 0 ? Math.round((verifiedDocs / totalDocs) * 100) : 0;

        res.json({ totalStudents, pendingDocs, verifiedDocs, printQueueCount, verificationRate });
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
        const result = { Pending: 0, Verified: 0, Draft: 0, Archived: 0 };
        rows.forEach(r => { result[r.status] = r.count; });
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
        const documentStatus = { Pending: 0, Verified: 0, Draft: 0, Archived: 0 };
        docStatusRows.forEach(r => { documentStatus[r.status] = r.count; });

        // Student detail list with document compliance
        let students;
        if (academicYearId) {
            students = db.prepare(`
                SELECT s.lrn, s.first_name, s.last_name, s.sex, e.grade_level,
                       COUNT(CASE WHEN d.status = 'Verified' THEN 1 END) as verified_docs,
                       COUNT(CASE WHEN d.status = 'Pending' THEN 1 END) as pending_docs
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
                       COUNT(CASE WHEN d.status = 'Verified' THEN 1 END) as verified_docs,
                       COUNT(CASE WHEN d.status = 'Pending' THEN 1 END) as pending_docs
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
