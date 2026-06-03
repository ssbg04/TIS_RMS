const db = require('../config/db');
const path = require('path');


exports.getArchivedStudents = (req, res) => {
    const {
        search = '',
        page = 1,
        limit = 10,
        status = 'All Statuses',
    } = req.query;

    const pageNum  = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offset   = (pageNum - 1) * limitNum;

    try {
        const conditions = [];
        const params     = [];

        // Base condition: only archived statuses
        if (status === 'All Statuses' || !status) {
            conditions.push(`s.status IN ('Graduated', 'Transferred', 'Dropped')`);
        } else {
            conditions.push(`s.status = ?`);
            params.push(status);
        }

        if (search.trim()) {
            const like = `%${search.trim()}%`;
            conditions.push(`(s.lrn LIKE ? OR s.first_name LIKE ? OR s.last_name LIKE ? OR s.middle_name LIKE ?)`);
            params.push(like, like, like, like);
        }

        const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

        // Count query
        const countSql = `
            SELECT COUNT(DISTINCT s.id) as total
            FROM students s
            ${whereClause}
        `;
        const total = db.prepare(countSql).get(params).total;

        // Fetch query
        const fetchSql = `
            SELECT 
                s.id, s.lrn, s.first_name, s.middle_name, s.last_name, s.extension, 
                s.status, s.created_at,
                date(s.created_at) as archivedDate,
                CASE 
                    WHEN s.status = 'Graduated' THEN date(s.created_at, '+5 years')
                    WHEN s.status = 'Transferred' THEN date(s.created_at, '+5 years')
                    WHEN s.status = 'Dropped' THEN date(s.created_at, '+3 years')
                    ELSE date(s.created_at, '+5 years')
                END as expiryDate
            FROM students s
            ${whereClause}
            ORDER BY s.last_name ASC, s.first_name ASC
            LIMIT ? OFFSET ?
        `;

        const students = db.prepare(fetchSql).all([...params, limitNum, offset]);

        const currentDate = new Date().toISOString().split('T')[0];

        const archives = students.map(student => {
            const nameParts = [student.last_name + ',', student.first_name];
            if (student.middle_name) nameParts.push(student.middle_name.charAt(0) + '.');
            if (student.extension) nameParts.push(student.extension);
            
            const isExpired = student.expiryDate < currentDate;

            return {
                id: student.id,
                lrn: student.lrn,
                name: nameParts.join(' '),
                status: student.status,
                archivedDate: student.archivedDate,
                expiryDate: student.expiryDate,
                isExpired: isExpired
            };
        });

        res.json({
            archives,
            pagination: {
                total,
                page:       pageNum,
                limit:      limitNum,
                totalPages: Math.ceil(total / limitNum),
            },
        });
    } catch (error) {
        console.error('getArchivedStudents error:', error);
        res.status(500).json({ message: 'Failed to fetch archives', error: error.message });
    }
};

exports.restoreArchive = (req, res) => {
    const { id } = req.params;

    const existing = db.prepare('SELECT id, status FROM students WHERE id = ?').get(id);
    if (!existing) return res.status(404).json({ message: 'Student not found.' });

    try {
        db.transaction(() => {
            // Restore student status to Enrolled
            db.prepare("UPDATE students SET status = 'Enrolled' WHERE id = ?").run(id);

            // Restore documents from Archived to Completed (assuming if they had an archive, they were completed, or just set to Completed)
            db.prepare("UPDATE documents SET status = 'Completed', retention_date = NULL WHERE student_id = ? AND status = 'Archived'").run(id);
        })();

        res.json({ message: 'Record restored to active successfully' });
    } catch (error) {
        console.error('restoreArchive error:', error);
        res.status(500).json({ message: 'Failed to restore record', error: error.message });
    }
};

exports.purgeArchive = (req, res) => {
    const { id } = req.params;

    const existing = db.prepare('SELECT id FROM students WHERE id = ?').get(id);
    if (!existing) return res.status(404).json({ message: 'Student not found.' });

    try {
        // Due to CASCADE DELETE on constraints in schema.js, deleting the student will delete their documents, grades, and enrollments
        db.prepare('DELETE FROM students WHERE id = ?').run(id);
        res.json({ message: 'Record permanently purged successfully' });
    } catch (error) {
        console.error('purgeArchive error:', error);
        res.status(500).json({ message: 'Failed to purge record', error: error.message });
    }
};

// ============================================================
// GET /api/archives/documents — paginated archived docs
// Includes:
//   • All documents (deleted_at IS NULL) from Graduated/Transferred/Dropped students
//   • All documents with status = 'Archived' from Enrolled students
// ============================================================
exports.getArchivedDocuments = (req, res) => {
    const {
        search = '',
        page = 1,
        limit = 20,
        status = 'All Statuses',   // filter by student status
        documentType = '',
        gradeLevel = '',
        schoolYear = '',
        studentId = '',
    } = req.query;

    const pageNum  = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offset   = (pageNum - 1) * limitNum;

    try {
        const conditions = [];
        const params     = [];

        // Core filter: non-enrolled student docs OR archived-status docs
        if (status && status !== 'All Statuses') {
            // Specific student status filter
            conditions.push(`s.status = ?`);
            params.push(status);
            conditions.push(`d.deleted_at IS NULL`);
        } else {
            // Default: non-enrolled docs OR explicitly Archived docs
            conditions.push(`(
                (s.status IN ('Graduated','Transferred','Dropped') AND d.deleted_at IS NULL)
                OR
                (s.status = 'Enrolled' AND d.status = 'Archived' AND d.deleted_at IS NULL)
            )`);
        }

        if (search.trim()) {
            const like = `%${search.trim()}%`;
            conditions.push(`(s.lrn LIKE ? OR s.first_name LIKE ? OR s.last_name LIKE ? OR d.file_name LIKE ?)`);
            params.push(like, like, like, like);
        }

        if (documentType.trim() && documentType !== 'All Types') {
            const types = documentType.split(',').map(t => t.trim()).filter(t => t);
            if (types.length > 0) {
                const typeConditions = [];
                for (const t of types) {
                    if (t === 'All JHS') {
                        typeConditions.push(`dr.category = 'JHS'`);
                    } else if (t === 'All SHS') {
                        typeConditions.push(`dr.category = 'SHS'`);
                    } else {
                        typeConditions.push(`(d.document_type = ? OR dr.name = ?)`);
                        params.push(t, t);
                    }
                }
                conditions.push(`(${typeConditions.join(' OR ')})`);
            }
        }

        if (gradeLevel.trim()) {
            conditions.push(`e.grade_level = ?`);
            params.push(gradeLevel.trim());
        }

        if (schoolYear.trim()) {
            conditions.push(`ay.year_range = ?`);
            params.push(schoolYear.trim());
        }

        if (studentId.trim()) {
            conditions.push(`d.student_id = ?`);
            params.push(studentId.trim());
        }

        const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

        const joins = `
            LEFT JOIN students s ON d.student_id = s.id
            LEFT JOIN enrollments e ON e.student_id = s.id
                AND e.id = (SELECT id FROM enrollments WHERE student_id = s.id ORDER BY grade_level DESC, id DESC LIMIT 1)
            LEFT JOIN academic_years ay ON e.academic_year_id = ay.id
            LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
        `;

        const total = db.prepare(`
            SELECT COUNT(DISTINCT d.id) as total FROM documents d ${joins} ${whereClause}
        `).get(params).total;

        const rows = db.prepare(`
            SELECT DISTINCT
                d.id, d.student_id, d.file_name, d.document_type, d.status,
                d.created_at, d.file_path,
                s.lrn as student_lrn,
                s.status as student_status,
                s.first_name || ' ' || s.last_name as student_name
            FROM documents d
            ${joins}
            ${whereClause}
            ORDER BY d.created_at DESC
            LIMIT ? OFFSET ?
        `).all([...params, limitNum, offset]);

        const documents = rows.map(d => ({
            id: d.id,
            studentId: d.student_id,
            fileName: d.file_name,
            documentType: d.document_type,
            status: d.status,
            createdAt: d.created_at,
            studentLrn: d.student_lrn,
            studentName: d.student_name,
            studentStatus: d.student_status,
            size: 'Unknown',
            filePath: d.file_path,
        }));

        res.json({
            documents,
            pagination: {
                total,
                page:       pageNum,
                limit:      limitNum,
                totalPages: Math.ceil(total / limitNum),
            },
        });
    } catch (error) {
        console.error('getArchivedDocuments error:', error);
        res.status(500).json({ message: 'Failed to fetch archived documents', error: error.message });
    }
};

// ============================================================
// GET /api/archives/student-folders — student folder list
// Returns folder records for non-enrolled (Graduated/Transferred/Dropped) students
// ============================================================
exports.getArchivedStudentFolders = (req, res) => {
    const { search = '', status = 'All Statuses' } = req.query;
    try {
        const conditions = [];
        const params     = [];

        if (status && status !== 'All Statuses') {
            conditions.push(`s.status = ?`);
            params.push(status);
        } else {
            conditions.push(`s.status IN ('Graduated','Transferred','Dropped')`);
        }

        if (search.trim()) {
            const like = `%${search.trim()}%`;
            conditions.push(`(s.lrn LIKE ? OR s.first_name LIKE ? OR s.last_name LIKE ?)`);
            params.push(like, like, like);
        }

        const whereClause = `WHERE ${conditions.join(' AND ')}`;

        const rows = db.prepare(`
            SELECT
                f.id, f.name, f.student_id, f.category, f.created_at,
                s.lrn, s.first_name, s.last_name, s.status as student_status,
                (SELECT COUNT(*) FROM documents d
                 WHERE d.student_id = f.student_id AND d.deleted_at IS NULL) as document_count
            FROM document_folders f
            JOIN students s ON f.student_id = s.id
            ${whereClause}
            AND f.category = 'root'
            ORDER BY s.last_name ASC, s.first_name ASC
        `).all(params);

        res.json(rows.map(r => ({
            id: r.id,
            name: r.name,
            student_id: r.student_id,
            category: r.category,
            created_at: r.created_at,
            lrn: r.lrn,
            first_name: r.first_name,
            last_name: r.last_name,
            student_status: r.student_status,
            document_count: r.document_count,
        })));
    } catch (error) {
        console.error('getArchivedStudentFolders error:', error);
        res.status(500).json({ message: 'Failed to fetch archived student folders', error: error.message });
    }
};
