const db = require('../config/db');
const fs = require('fs');
const path = require('path');

// ============================================================
// CONFIG — student directory root (configurable via .env)
// ============================================================
const STUDENT_DIR_ROOT = process.env.STUDENT_DIR_ROOT
    ? path.resolve(process.env.STUDENT_DIR_ROOT)
    : path.resolve(__dirname, '../../../data/students');

// ============================================================
// HELPER — sanitize a string for use in a folder name
// ============================================================
const sanitizeFolderName = (str) =>
    (str || '').replace(/[<>:"/\\|?*\x00-\x1F]/g, '').trim();

// ============================================================
// HELPER — validate LRN (exactly 12 digits)
// ============================================================
const isValidLRN = (lrn) => /^\d{12}$/.test((lrn || '').trim());

// ============================================================
// GET /api/students — paginated, searchable, filterable
// ============================================================
exports.getAllStudents = (req, res) => {
    const {
        search = '',
        page = 1,
        limit = 10,
        gradeLevel = '',   // e.g. "7", "8", ... "12"
        status = '',       // e.g. "Enrolled"
    } = req.query;

    const pageNum  = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offset   = (pageNum - 1) * limitNum;

    try {
        // ---- Build WHERE clauses ----
        const conditions = [];
        const params     = [];

        if (search.trim()) {
            const like = `%${search.trim()}%`;
            conditions.push(`(s.lrn LIKE ? OR s.first_name LIKE ? OR s.last_name LIKE ? OR s.middle_name LIKE ?)`);
            params.push(like, like, like, like);
        }

        if (status.trim()) {
            conditions.push(`s.status = ?`);
            params.push(status.trim());
        }

        // grade_level lives in enrollments (latest)
        const gradeJoin = gradeLevel.trim()
            ? `JOIN enrollments e_latest ON e_latest.student_id = s.id
               AND e_latest.id = (SELECT MAX(id) FROM enrollments WHERE student_id = s.id)`
            : '';
        if (gradeLevel.trim()) {
            conditions.push(`e_latest.grade_level = ?`);
            params.push(parseInt(gradeLevel));
        }

        const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

        // ---- Count query ----
        const countSql = `
            SELECT COUNT(DISTINCT s.id) as total
            FROM students s
            ${gradeJoin}
            ${whereClause}
        `;
        const total = db.prepare(countSql).get(params).total;

        // ---- Fetch query ----
        const fetchSql = `
            SELECT DISTINCT
                s.id, s.lrn, s.first_name, s.middle_name, s.last_name,
                s.extension, s.sex, s.birth_date, s.status, s.created_at,
                (
                    SELECT grade_level FROM enrollments
                    WHERE student_id = s.id ORDER BY id DESC LIMIT 1
                ) as latest_grade_level,
                (
                    SELECT sec.name FROM enrollments enr
                    JOIN sections sec ON sec.id = enr.section_id
                    WHERE enr.student_id = s.id ORDER BY enr.id DESC LIMIT 1
                ) as latest_section
            FROM students s
            ${gradeJoin}
            ${whereClause}
            ORDER BY s.last_name ASC, s.first_name ASC
            LIMIT ? OFFSET ?
        `;

        const students = db.prepare(fetchSql).all([...params, limitNum, offset]);

        // ---- Attach missingDocumentsCount badge ----
        const studentsWithBadges = students.map(student => {
            const missingDocs = db.prepare(`
                SELECT COUNT(*) as count
                FROM document_requirements dr
                WHERE dr.is_mandatory = 1
                  AND dr.category = (
                      SELECT CASE WHEN grade_level <= 10 THEN 'JHS' ELSE 'SHS' END
                      FROM enrollments WHERE student_id = ? ORDER BY id DESC LIMIT 1
                  )
                  AND dr.id NOT IN (
                      SELECT requirement_id FROM documents
                      WHERE student_id = ? AND status = 'Verified' AND requirement_id IS NOT NULL
                  )
            `).get(student.id, student.id)?.count ?? 0;

            return { ...student, missingDocumentsCount: missingDocs };
        });

        res.json({
            students: studentsWithBadges,
            pagination: {
                total,
                page:       pageNum,
                limit:      limitNum,
                totalPages: Math.ceil(total / limitNum),
            },
        });
    } catch (error) {
        console.error('getAllStudents error:', error);
        res.status(500).json({ message: 'Failed to fetch students', error: error.message });
    }
};

// ============================================================
// GET /api/students/:id — single student with enrollments
// ============================================================
exports.getStudentById = (req, res) => {
    try {
        const student = db.prepare('SELECT * FROM students WHERE id = ?').get(req.params.id);
        if (!student) return res.status(404).json({ message: 'Student not found' });

        const enrollments = db.prepare(`
            SELECT e.*, ay.year_range, sec.name as section_name
            FROM enrollments e
            JOIN academic_years ay ON e.academic_year_id = ay.id
            JOIN sections sec       ON e.section_id = sec.id
            WHERE e.student_id = ?
            ORDER BY e.id DESC
        `).all(student.id);

        res.json({ ...student, enrollments });
    } catch (error) {
        console.error('getStudentById error:', error);
        res.status(500).json({ message: 'Failed to fetch student details', error: error.message });
    }
};

// ============================================================
// POST /api/students — create + auto-create directory
// ============================================================
exports.createStudent = (req, res) => {
    const { lrn, firstName, middleName, lastName, extension, sex, birthDate } = req.body;

    // ---- Server-side validation ----
    const errors = [];
    if (!lrn || !isValidLRN(lrn))           errors.push('LRN must be exactly 12 digits.');
    if (!firstName || !firstName.trim())     errors.push('First name is required.');
    if (!lastName  || !lastName.trim())      errors.push('Last name is required.');
    if (!sex       || !['Male', 'Female'].includes(sex)) errors.push('Sex must be Male or Female.');
    if (!birthDate)                          errors.push('Date of birth is required.');
    else {
        const dob = new Date(birthDate);
        if (isNaN(dob.getTime()))            errors.push('Invalid date of birth format.');
        else if (dob > new Date())           errors.push('Date of birth cannot be in the future.');
    }
    if (errors.length) return res.status(400).json({ message: errors[0], errors });

    // ---- Duplicate LRN check ----
    const existing = db.prepare('SELECT id FROM students WHERE lrn = ?').get(lrn.trim());
    if (existing) return res.status(409).json({ message: `A student with LRN ${lrn} already exists.` });

    try {
        // ---- Insert in transaction ----
        const insertResult = db.transaction(() => {
            const result = db.prepare(`
                INSERT INTO students (lrn, first_name, middle_name, last_name, extension, sex, birth_date)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            `).run(
                lrn.trim(),
                firstName.trim(),
                middleName?.trim() || null,
                lastName.trim(),
                extension?.trim()  || null,
                sex,
                birthDate
            );
            return result;
        })();

        const newId = insertResult.lastInsertRowid;

        // ---- Auto-create student directory ----
        const folderName = `${sanitizeFolderName(lastName)}_${sanitizeFolderName(firstName)}_${lrn.trim()}`;
        const studentDir = path.join(STUDENT_DIR_ROOT, folderName);
        if (!fs.existsSync(studentDir)) {
            fs.mkdirSync(studentDir, { recursive: true });
        }

        // ---- Auto-create folder record in database ----
        try {
            db.prepare(`
                INSERT INTO document_folders (name, student_id, category, created_by)
                VALUES (?, ?, 'root', ?)
            `).run(folderName, newId, req.user?.id || null);
        } catch (folderError) {
            console.error('Warning: Failed to create folder record:', folderError.message);
        }

        res.status(201).json({
            id: newId,
            message: 'Student created successfully',
            directoryPath: studentDir,
        });
    } catch (error) {
        console.error('createStudent error:', error);
        // SQLite unique constraint gives SQLITE_CONSTRAINT
        if (error.message && error.message.includes('UNIQUE')) {
            return res.status(409).json({ message: `A student with LRN ${lrn} already exists.` });
        }
        res.status(500).json({ message: 'Failed to create student', error: error.message });
    }
};

// ============================================================
// PUT /api/students/:id — update student record
// ============================================================
exports.updateStudent = (req, res) => {
    const { id } = req.params;
    const { lrn, firstName, middleName, lastName, extension, sex, birthDate, status } = req.body;

    // ---- Server-side validation ----
    const errors = [];
    if (!lrn || !isValidLRN(lrn))           errors.push('LRN must be exactly 12 digits.');
    if (!firstName || !firstName.trim())     errors.push('First name is required.');
    if (!lastName  || !lastName.trim())      errors.push('Last name is required.');
    if (!sex       || !['Male', 'Female'].includes(sex)) errors.push('Sex must be Male or Female.');
    if (!birthDate)                          errors.push('Date of birth is required.');
    if (status && !['Enrolled', 'Graduated', 'Transferred Out', 'Dropped'].includes(status)) {
        errors.push('Invalid status value.');
    }
    if (errors.length) return res.status(400).json({ message: errors[0], errors });

    // ---- Existence check ----
    const existing = db.prepare('SELECT id FROM students WHERE id = ?').get(id);
    if (!existing) return res.status(404).json({ message: 'Student not found.' });

    // ---- Duplicate LRN check (excluding self) ----
    const duplicate = db.prepare('SELECT id FROM students WHERE lrn = ? AND id != ?').get(lrn.trim(), id);
    if (duplicate) return res.status(409).json({ message: `Another student already has LRN ${lrn}.` });

    try {
        db.prepare(`
            UPDATE students
            SET lrn = ?, first_name = ?, middle_name = ?, last_name = ?,
                extension = ?, sex = ?, birth_date = ?, status = ?
            WHERE id = ?
        `).run(
            lrn.trim(),
            firstName.trim(),
            middleName?.trim() || null,
            lastName.trim(),
            extension?.trim()  || null,
            sex,
            birthDate,
            status || 'Enrolled',
            id
        );

        res.json({ message: 'Student updated successfully' });
    } catch (error) {
        console.error('updateStudent error:', error);
        if (error.message && error.message.includes('UNIQUE')) {
            return res.status(409).json({ message: `Another student already has LRN ${lrn}.` });
        }
        res.status(500).json({ message: 'Failed to update student', error: error.message });
    }
};

// ============================================================
// DELETE /api/students/:id
// ============================================================
exports.deleteStudent = (req, res) => {
    const { id } = req.params;

    const existing = db.prepare('SELECT id FROM students WHERE id = ?').get(id);
    if (!existing) return res.status(404).json({ message: 'Student not found.' });

    try {
        db.prepare('DELETE FROM students WHERE id = ?').run(id);
        res.json({ message: 'Student deleted successfully' });
    } catch (error) {
        console.error('deleteStudent error:', error);
        res.status(500).json({ message: 'Failed to delete student', error: error.message });
    }
};
