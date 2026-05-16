const db = require('../config/db');

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
            conditions.push(`s.status IN ('Graduated', 'Transferred Out', 'Dropped')`);
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
                    WHEN s.status = 'Transferred Out' THEN date(s.created_at, '+5 years')
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

            // Restore documents from Archived to Verified (assuming if they had an archive, they were verified, or just set to Verified)
            db.prepare("UPDATE documents SET status = 'Verified', retention_date = NULL WHERE student_id = ? AND status = 'Archived'").run(id);
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
