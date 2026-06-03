const db = require('../config/db');
const fs = require('fs');
const path = require('path');
const { createNotification } = require('./notificationController');

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
        section = '',
        schoolYear = '',
    } = req.query;

    const pageNum  = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offset   = (pageNum - 1) * limitNum;

    const isTeacher = req.user?.role === 'teacher';
    const teacherId = req.user?.id;

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
        const needsEnrollmentJoin = gradeLevel.trim() || section.trim() || schoolYear.trim();
        const enrollmentJoin = needsEnrollmentJoin
            ? `JOIN enrollments e_latest ON e_latest.student_id = s.id
               AND e_latest.id = (SELECT id FROM enrollments WHERE student_id = s.id ORDER BY grade_level DESC, id DESC LIMIT 1)
               JOIN sections sec ON sec.id = e_latest.section_id
               JOIN academic_years ay ON ay.id = e_latest.academic_year_id`
            : '';

        if (gradeLevel.trim()) {
            conditions.push(`e_latest.grade_level = ?`);
            params.push(parseInt(gradeLevel));
        }
        if (section.trim()) {
            conditions.push(`sec.name = ?`);
            params.push(section.trim());
        }
        if (schoolYear.trim()) {
            conditions.push(`ay.year_range = ?`);
            params.push(schoolYear.trim());
        }

        // ---- Teacher section scoping ----
        // When the caller is a teacher, restrict results to students enrolled
        // in any of the sections assigned to that teacher.
        const teacherJoin = isTeacher
            ? `JOIN enrollments e_teacher ON e_teacher.student_id = s.id
               JOIN teacher_sections ts ON ts.section_id = e_teacher.section_id AND ts.teacher_id = ?`
            : '';
        if (isTeacher) params.unshift(teacherId);

        const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

        // ---- Count query ----
        const countSql = `
            SELECT COUNT(DISTINCT s.id) as total
            FROM students s
            ${teacherJoin}
            ${enrollmentJoin}
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
                    WHERE student_id = s.id ORDER BY grade_level DESC, id DESC LIMIT 1
                ) as latest_grade_level,
                (
                    SELECT sec.name FROM enrollments enr
                    JOIN sections sec ON sec.id = enr.section_id
                    WHERE enr.student_id = s.id ORDER BY enr.grade_level DESC, enr.id DESC LIMIT 1
                ) as latest_section
            FROM students s
            ${teacherJoin}
            ${enrollmentJoin}
            ${whereClause}
            ORDER BY s.last_name ASC, s.first_name ASC
            LIMIT ? OFFSET ?
        `;

        const students = db.prepare(fetchSql).all([...params, limitNum, offset]);

        // ---- Attach missingDocumentsCount badge ----
        const studentsWithBadges = students.map(student => {
            // 1. Get total mandatory documents required for this student's grade level
            const totalDocs = db.prepare(`
                SELECT COUNT(*) as count
                FROM document_requirements dr
                WHERE dr.is_mandatory = 1
                  AND dr.is_enabled = 1
                  AND dr.category = (
                      SELECT CASE WHEN grade_level <= 10 THEN 'JHS' ELSE 'SHS' END
                      FROM enrollments WHERE student_id = ? ORDER BY grade_level DESC, id DESC LIMIT 1
                  )
            `).get(student.id)?.count ?? 0;

            // 2. Get missing documents
            const missingDocs = db.prepare(`
                SELECT COUNT(*) as count
                FROM document_requirements dr
                WHERE dr.is_mandatory = 1
                  AND dr.is_enabled = 1
                  AND dr.category = (
                      SELECT CASE WHEN grade_level <= 10 THEN 'JHS' ELSE 'SHS' END
                      FROM enrollments WHERE student_id = ? ORDER BY grade_level DESC, id DESC LIMIT 1
                  )
                  AND dr.id NOT IN (
                      SELECT requirement_id FROM documents
                      WHERE student_id = ? AND status IN ('Completed', 'Archived') AND requirement_id IS NOT NULL
                  )
            `).get(student.id, student.id)?.count ?? 0;

            return { ...student, missingDocumentsCount: missingDocs, totalDocumentsCount: totalDocs };
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
            ORDER BY e.academic_year_id DESC, e.grade_level DESC
        `).all(student.id);

        res.json({ ...student, enrollments });
    } catch (error) {
        console.error('getStudentById error:', error);
        res.status(500).json({ message: 'Failed to fetch student details', error: error.message });
    }
};

// ============================================================
// POST /api/students — create + auto-create directory & enrollment
// ============================================================
exports.createStudent = (req, res) => {
    const { lrn, firstName, middleName, lastName, extension, sex, birthDate, academicYearId, gradeLevel, sectionId, trackStrand } = req.body;

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
    if (!academicYearId)                     errors.push('Academic year is required.');
    if (!gradeLevel)                         errors.push('Grade level is required.');
    if (!sectionId)                          errors.push('Section is required.');

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

            const newId = result.lastInsertRowid;

            // Automatically create enrollment record
            db.prepare(`
                INSERT INTO enrollments (student_id, academic_year_id, section_id, grade_level, track_strand)
                VALUES (?, ?, ?, ?, ?)
            `).run(newId, academicYearId, sectionId, gradeLevel, trackStrand || null);

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

        createNotification(null, 'Student Created', `New student ${firstName} ${lastName} (LRN: ${lrn.trim()}) has been enrolled.`, 'student');

        res.status(201).json({
            id: newId,
            message: 'Student created successfully',
            directoryPath: studentDir,
        });
    } catch (error) {
        console.error('createStudent error:', error);
        if (error.message && error.message.includes('UNIQUE')) {
            return res.status(409).json({ message: `A student with LRN ${lrn} already exists.` });
        }
        res.status(500).json({ message: 'Failed to create student', error: error.message });
    }
};

// ============================================================
// PUT /api/students/bulk-graduate — Update multiple students to Graduated
// ============================================================
exports.bulkGraduate = (req, res) => {
    const { studentIds } = req.body;

    if (!Array.isArray(studentIds) || studentIds.length === 0) {
        return res.status(400).json({ message: 'No student IDs provided' });
    }

    try {
        // Query for only Grade 10 and Grade 12 students in their latest enrollment
        const eligibleStudents = db.prepare(`
            SELECT s.id
            FROM students s
            JOIN enrollments e ON s.id = e.student_id
            JOIN academic_years ay ON e.academic_year_id = ay.id
            WHERE s.id IN (${studentIds.map(() => '?').join(',')})
              AND NOT EXISTS (
                  SELECT 1
                  FROM enrollments e2
                  JOIN academic_years ay2 ON e2.academic_year_id = ay2.id
                  WHERE e2.student_id = s.id
                    AND ay2.year_range > ay.year_range
              )
              AND e.grade_level IN (10, 12)
        `).all(...studentIds);

        const eligibleIds = eligibleStudents.map(s => s.id);
        let count = 0;

        if (eligibleIds.length > 0) {
            const updateStmt = db.prepare(`UPDATE students SET status = 'Graduated' WHERE id = ?`);
            const archiveDocsStmt = db.prepare(`UPDATE documents SET status = 'Archived' WHERE student_id = ? AND deleted_at IS NULL`);
            const updateMany = db.transaction((ids) => {
                let cnt = 0;
                for (const id of ids) {
                    const info = updateStmt.run(id);
                    if (info.changes > 0) {
                        archiveDocsStmt.run(id);
                        cnt++;
                    }
                }
                return cnt;
            });
            count = updateMany(eligibleIds);
        }

        // Notify admins if any graduated
        if (count > 0) {
            createNotification(
                'Students Graduated',
                `${count} student(s) status updated to Graduated.`,
                'admin',
                null
            );
        }

        res.json({ message: `${count} student(s) successfully graduated.` });
    } catch (error) {
        console.error('bulkGraduate error:', error);
        res.status(500).json({ message: 'Failed to bulk graduate students', error: error.message });
    }
};

// ============================================================
// PUT /api/students/:id — update student record
// ============================================================
exports.updateStudent = (req, res) => {
    const { id } = req.params;
    const { lrn, firstName, middleName, lastName, extension, sex, birthDate, status, academicYearId, gradeLevel, sectionId, trackStrand } = req.body;

    // ---- Server-side validation ----
    const errors = [];
    if (!lrn || !isValidLRN(lrn))           errors.push('LRN must be exactly 12 digits.');
    if (!firstName || !firstName.trim())     errors.push('First name is required.');
    if (!lastName  || !lastName.trim())      errors.push('Last name is required.');
    if (!sex       || !['Male', 'Female'].includes(sex)) errors.push('Sex must be Male or Female.');
    if (!birthDate)                          errors.push('Date of birth is required.');
    if (status && !['Enrolled', 'Graduated', 'Transferred', 'Dropped'].includes(status)) {
        errors.push('Invalid status value.');
    }
    if (status === 'Graduated' && gradeLevel !== 10 && gradeLevel !== 12) {
        errors.push('Graduation status is only applicable for Grade 10 and Grade 12 students.');
    }
    if (!academicYearId)                     errors.push('Academic year is required.');
    if (!gradeLevel)                         errors.push('Grade level is required.');
    if (!sectionId)                          errors.push('Section is required.');

    if (errors.length) return res.status(400).json({ message: errors[0], errors });

    // ---- Existence check ----
    const existing = db.prepare('SELECT id FROM students WHERE id = ?').get(id);
    if (!existing) return res.status(404).json({ message: 'Student not found.' });

    // ---- Duplicate LRN check (excluding self) ----
    const duplicate = db.prepare('SELECT id FROM students WHERE lrn = ? AND id != ?').get(lrn.trim(), id);
    if (duplicate) return res.status(409).json({ message: `Another student already has LRN ${lrn}.` });

    try {
        db.transaction(() => {
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

            // Upsert enrollment record
            const existingEnrollment = db.prepare('SELECT id FROM enrollments WHERE student_id = ? AND academic_year_id = ?').get(id, academicYearId);
            if (existingEnrollment) {
                db.prepare(`
                    UPDATE enrollments
                    SET section_id = ?, grade_level = ?, track_strand = ?
                    WHERE id = ?
                `).run(sectionId, gradeLevel, trackStrand || null, existingEnrollment.id);
            } else {
                db.prepare(`
                    INSERT INTO enrollments (student_id, academic_year_id, section_id, grade_level, track_strand)
                    VALUES (?, ?, ?, ?, ?)
                `).run(id, academicYearId, sectionId, gradeLevel, trackStrand || null);
            }

            // Auto-archive documents if status is non-enrolled
            const newStatus = status || 'Enrolled';
            if (['Graduated', 'Transferred', 'Dropped'].includes(newStatus)) {
                db.prepare(`
                    UPDATE documents
                    SET status = 'Archived'
                    WHERE student_id = ? AND deleted_at IS NULL
                `).run(id);
            }
        })();

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

// ============================================================
// POST /api/students/bulk-enroll
// ============================================================
exports.bulkEnrollStudents = (req, res) => {
    const { studentIds, academicYearId, sectionId, gradeLevel, trackStrand } = req.body;
    if (!Array.isArray(studentIds) || studentIds.length === 0) {
        return res.status(400).json({ message: 'studentIds must be a non-empty array' });
    }
    if (!academicYearId || !sectionId || !gradeLevel) {
        return res.status(400).json({ message: 'academicYearId, sectionId, and gradeLevel are required' });
    }
    try {
        db.transaction(() => {
            const checkEnrollment = db.prepare('SELECT id FROM enrollments WHERE student_id = ? AND academic_year_id = ?');
            const updateEnrollment = db.prepare('UPDATE enrollments SET section_id = ?, grade_level = ?, track_strand = ? WHERE id = ?');
            const insertEnrollment = db.prepare('INSERT INTO enrollments (student_id, academic_year_id, section_id, grade_level, track_strand) VALUES (?, ?, ?, ?, ?)');
            
            for (const studentId of studentIds) {
                const existing = checkEnrollment.get(studentId, academicYearId);
                if (existing) {
                    updateEnrollment.run(sectionId, gradeLevel, trackStrand || null, existing.id);
                } else {
                    insertEnrollment.run(studentId, academicYearId, sectionId, gradeLevel, trackStrand || null);
                }
            }
        })();
        res.json({ message: `Successfully enrolled ${studentIds.length} students.` });
    } catch (error) {
        console.error('bulkEnrollStudents error:', error);
        res.status(500).json({ message: 'Failed to bulk enroll students', error: error.message });
    }
};
