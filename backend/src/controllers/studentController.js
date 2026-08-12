const db = require('../config/db');
const fs = require('fs');
const path = require('path');
const { createNotification } = require('./notificationController');

// ============================================================
// HELPER — insert one row into activity_log
// ============================================================
const logActivity = (userId, action, entityType, entityId, description) => {
    if (!userId) return; // Skip if no user context
    try {
        db.prepare(`
            INSERT INTO activity_log (user_id, action, entity_type, entity_id, description) VALUES (?, ?, ?, ?, ?)
        `).run(userId, action, entityType, entityId, description);
    } catch (err) {
        console.error('logActivity error:', err.message);
    }
};

const getEnrollmentLogDesc = (academicYearId, gradeLevel, sectionId, lrn) => {
    try {
        const ay = db.prepare('SELECT year_range FROM academic_years WHERE id = ?').get(academicYearId);
        const sec = db.prepare('SELECT name FROM sections WHERE id = ?').get(sectionId);
        const year = ay?.year_range || '';
        const secName = sec?.name || '';
        const gradeStr = String(gradeLevel).toLowerCase().startsWith('grade') ? gradeLevel : `Grade ${gradeLevel}`;
        return `CREATE enrollment ${year} - ${gradeStr} - ${secName} student ${lrn}`;
    } catch (err) {
        return `CREATE enrollment student ${lrn}`;
    }
};

function normalizeBirthDate(val) {
    if (!val) return null;
    const str = String(val).trim();
    if (!str) return null;
    if (/^\d{4,6}$/.test(str)) {
        const serial = parseInt(str, 10);
        if (serial > 10000 && serial < 80000) {
            const date = new Date(Math.round((serial - 25569) * 86400 * 1000));
            return date.toISOString().split('T')[0];
        }
    }
    const slash = str.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$/);
    if (slash) {
        let m = parseInt(slash[1], 10);
        let d = parseInt(slash[2], 10);
        let y = parseInt(slash[3], 10);
        if (y < 100) y += (y <= 30 ? 2000 : 1900);
        if (m > 12 && d <= 12) {
            const tmp = m;
            m = d;
            d = tmp;
        }
        return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    }
    const parsed = new Date(str);
    if (!isNaN(parsed.getTime())) {
        return parsed.toISOString().split('T')[0];
    }
    return str;
}

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
// HELPER — check for duplicate student by Name (first, middle, last)
// ============================================================
const findDuplicateStudentByName = (firstName, middleName, lastName, excludeId = null) => {
    const fn = (firstName || '').trim();
    const mn = (middleName || '').trim();
    const ln = (lastName || '').trim();
    if (!fn || !ln) return null;
    let query = `
        SELECT id, lrn FROM students 
        WHERE LOWER(TRIM(first_name)) = LOWER(?) 
          AND LOWER(TRIM(COALESCE(middle_name, ''))) = LOWER(?) 
          AND LOWER(TRIM(last_name)) = LOWER(?)
    `;
    const params = [fn, mn, ln];
    if (excludeId) {
        query += ` AND id != ?`;
        params.push(excludeId);
    }
    return db.prepare(query).get(...params);
};

// ============================================================
// GET /api/students — paginated, searchable, filterable
// ============================================================
exports.getAllStudents = (req, res) => {
    const {
        search = '',
        page = 1,
        limit = 20,
        gradeLevel = '',   // e.g. "7", "8", ... "12"
        status = '',       // e.g. "Enrolled"
        section = '',
        schoolYear = '',
        is4ps = '',        // "true" or "false"
        lrn = '',
        sortBy = '',       // 'lrn', 'name', 'grade_section'
        sortOrder = 'asc', // 'asc', 'desc'
    } = req.query;

    const pageNum  = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offset   = (pageNum - 1) * limitNum;

    const isTeacher = req.user?.role?.toLowerCase() === 'teacher';
    const teacherId = req.user?.id;

    try {
        // ---- Build WHERE clauses ----
        const conditions = [];
        const params     = [];

        if (search.trim()) {
            const like = `%${search.trim().split('').join('%' )}%`;
            conditions.push(`(s.lrn LIKE ? OR s.first_name LIKE ? OR s.last_name LIKE ? OR s.middle_name LIKE ?)`);
            params.push(like, like, like, like);
        }

        if (status.trim()) {
            conditions.push(`s.status = ?`);
            params.push(status.trim());
        }

        if (lrn.trim()) {
            conditions.push(`s.lrn LIKE ?`);
            params.push(`%${lrn.trim()}%`);
        }

        if (is4ps === 'true') {
            conditions.push(`s.is_4ps = 1`);
        } else if (is4ps === 'false') {
            conditions.push(`s.is_4ps = 0`);
        }

        // grade_level lives in enrollments (latest)
        const needsEnrollmentJoin = gradeLevel.trim() || section.trim() || schoolYear.trim();
        const enrollmentJoin = needsEnrollmentJoin
            ? `JOIN enrollments e_latest ON e_latest.student_id = s.id
               AND e_latest.id = (
                   SELECT e.id FROM enrollments e
                   JOIN academic_years ay_inner ON e.academic_year_id = ay_inner.id
                   WHERE e.student_id = s.id
                   ORDER BY ay_inner.year_range DESC, e.grade_level DESC, e.id DESC LIMIT 1
               )
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
        // Restrict to students whose LATEST enrollment is in one of this teacher's sections.
        const teacherJoin = isTeacher
            ? `JOIN enrollments e_teacher ON e_teacher.student_id = s.id
               AND e_teacher.id = (
                   SELECT e.id FROM enrollments e
                   JOIN academic_years ay_inner ON e.academic_year_id = ay_inner.id
                   WHERE e.student_id = s.id
                   ORDER BY ay_inner.year_range DESC, e.grade_level DESC, e.id DESC LIMIT 1
               )
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

        const orderDir = (sortOrder || '').toLowerCase() === 'desc' ? 'DESC' : 'ASC';
        let orderByClause = `ORDER BY s.last_name ASC, s.first_name ASC`;
        if (sortBy === 'lrn') {
            orderByClause = `ORDER BY s.lrn ${orderDir}, s.last_name ASC, s.first_name ASC`;
        } else if (sortBy === 'name') {
            orderByClause = `ORDER BY s.last_name ${orderDir}, s.first_name ${orderDir}`;
        } else if (sortBy === 'grade_section') {
            orderByClause = `ORDER BY latest_grade_level ${orderDir}, latest_section ${orderDir}, s.last_name ASC, s.first_name ASC`;
        }

        // ---- Fetch query ----
        const fetchSql = `
            SELECT DISTINCT
                s.id, s.lrn, s.first_name, s.middle_name, s.last_name,
                s.extension, s.sex, s.birth_date, s.status, s.is_4ps, s.created_at,
                (
                    SELECT e.grade_level FROM enrollments e
                    JOIN academic_years ay_inner ON e.academic_year_id = ay_inner.id
                    WHERE e.student_id = s.id
                    ORDER BY ay_inner.year_range DESC, e.grade_level DESC, e.id DESC LIMIT 1
                ) as latest_grade_level,
                (
                    SELECT sec.name FROM enrollments enr
                    JOIN sections sec ON sec.id = enr.section_id
                    JOIN academic_years ay_inner ON enr.academic_year_id = ay_inner.id
                    WHERE enr.student_id = s.id
                    ORDER BY ay_inner.year_range DESC, enr.grade_level DESC, enr.id DESC LIMIT 1
                ) as latest_section
            FROM students s
            ${teacherJoin}
            ${enrollmentJoin}
            ${whereClause}
            ${orderByClause}
            LIMIT ? OFFSET ?
        `;

        const students = db.prepare(fetchSql).all([...params, limitNum, offset]);

        // ---- Attach missingDocumentsCount badge ----
        const studentsWithBadges = students.map(student => {
            // 1. Get total mandatory documents required for this student's grade level(s)
            const totalDocs = db.prepare(`
                SELECT COUNT(*) as count
                FROM document_requirements dr
                WHERE dr.is_mandatory = 1
                  AND dr.is_enabled = 1
                  AND dr.category IN (
                      SELECT DISTINCT CASE WHEN grade_level <= 10 THEN 'JHS' ELSE 'SHS' END
                      FROM enrollments WHERE student_id = ?
                  )
            `).get(student.id)?.count ?? 0;

            // 2. Get missing documents
            const missingDocsQuery = db.prepare(`
                SELECT dr.name, dr.category
                FROM document_requirements dr
                WHERE dr.is_mandatory = 1
                  AND dr.is_enabled = 1
                  AND dr.category IN (
                      SELECT DISTINCT CASE WHEN grade_level <= 10 THEN 'JHS' ELSE 'SHS' END
                      FROM enrollments WHERE student_id = ?
                  )
                  AND dr.id NOT IN (
                      SELECT requirement_id FROM documents
                      WHERE student_id = ? AND status IN ('Completed', 'Archived') AND requirement_id IS NOT NULL
                  )
            `).all(student.id, student.id);
            
            const missingDocsCount = missingDocsQuery.length;
            const missingDocsNames = missingDocsQuery.map(d => `[${d.category}] ${d.name}`);

            return { 
                ...student, 
                missingDocumentsCount: missingDocsCount, 
                totalDocumentsCount: totalDocs,
                missingDocuments: missingDocsNames
            };
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
        const studentId = req.params.id;
        const isTeacher = req.user?.role?.toLowerCase() === 'teacher';
        if (isTeacher) {
            const hasAccess = db.prepare(`
                SELECT 1 FROM enrollments e
                JOIN teacher_sections ts ON e.section_id = ts.section_id
                WHERE e.student_id = ? AND ts.teacher_id = ?
                  AND e.id = (
                      SELECT e2.id FROM enrollments e2
                      JOIN academic_years ay ON e2.academic_year_id = ay.id
                      WHERE e2.student_id = ?
                      ORDER BY ay.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                  )
            `).get(studentId, req.user.id, studentId);
            if (!hasAccess) {
                return res.status(403).json({ message: "Access denied to this student's details." });
            }
        }

        const student = db.prepare('SELECT * FROM students WHERE id = ?').get(studentId);
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
    let { lrn, firstName, middleName, lastName, extension, sex, birthDate, academicYearId, gradeLevel, sectionId, trackStrand, is4ps } = req.body;
    birthDate = normalizeBirthDate(birthDate);

    // ---- Server-side validation ----
    const errors = [];
    if (!lrn || !isValidLRN(lrn))           errors.push('LRN must be exactly 12 digits.');
    if (!firstName || !firstName.trim())     errors.push('First name is required.');
    if (!lastName  || !lastName.trim())      errors.push('Last name is required.');
    if (!sex       || !['Male', 'Female'].includes(sex)) errors.push('Sex must be Male or Female.');
    if (birthDate) {
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

    // ---- Duplicate Name check ----
    const existingByName = findDuplicateStudentByName(firstName, middleName, lastName);
    if (existingByName) {
        const fullName = [firstName, middleName, lastName].filter(Boolean).map(s => s.trim()).join(' ');
        return res.status(409).json({
            message: `A student named "${fullName}" already exists (LRN: ${existingByName.lrn}).`
        });
    }

    try {
        // ---- Insert in transaction ----
        const insertResult = db.transaction(() => {
            const result = db.prepare(`
                INSERT INTO students (lrn, first_name, middle_name, last_name, extension, sex, birth_date, is_4ps)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            `).run(
                lrn.trim(),
                firstName.trim(),
                middleName?.trim() || null,
                lastName.trim(),
                extension?.trim()  || null,
                sex,
                birthDate || null,
                is4ps ? 1 : 0
            );

            const newId = result.lastInsertRowid;

            // Automatically create enrollment record
            const enrRes = db.prepare(`
                INSERT INTO enrollments (student_id, academic_year_id, section_id, grade_level, track_strand)
                VALUES (?, ?, ?, ?, ?)
            `).run(newId, academicYearId, sectionId, gradeLevel, trackStrand || null);
            logActivity(req.user?.id, 'CREATE', 'enrollment', enrRes.lastInsertRowid, getEnrollmentLogDesc(academicYearId, gradeLevel, sectionId, lrn.trim()));

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

        logActivity(req.user?.id, 'CREATE', 'student', newId, `Created student ${firstName} ${lastName}`);

        createNotification(null, 'Student Created', `New student ${firstName} ${lastName} (LRN: ${lrn.trim()}) has been enrolled.`, 'student', 'student', newId);

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
                null,
                'Students Graduated',
                `${count} student(s) status updated to Graduated.`,
                'student'
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
    let { lrn, firstName, middleName, lastName, extension, sex, birthDate, status, academicYearId, gradeLevel, sectionId, trackStrand, is4ps } = req.body;
    birthDate = normalizeBirthDate(birthDate);

    // ---- Server-side validation ----
    const errors = [];
    if (!lrn || !isValidLRN(lrn))           errors.push('LRN must be exactly 12 digits.');
    if (!firstName || !firstName.trim())     errors.push('First name is required.');
    if (!lastName  || !lastName.trim())      errors.push('Last name is required.');
    if (!sex       || !['Male', 'Female'].includes(sex)) errors.push('Sex must be Male or Female.');
    if (birthDate) {
        const dob = new Date(birthDate);
        if (isNaN(dob.getTime()))            errors.push('Invalid date of birth format.');
        else if (dob > new Date())           errors.push('Date of birth cannot be in the future.');
    }
    if (status && !['Enrolled', 'Graduated', 'Transferred', 'Dropped', 'Inactive'].includes(status)) {
        errors.push('Invalid status value.');
    }
    if (status === 'Graduated' && gradeLevel && gradeLevel !== 10 && gradeLevel !== 12) {
        errors.push('Graduation status is only applicable for Grade 10 and Grade 12 students.');
    }
    if (academicYearId > 0 || sectionId > 0) {
        if (!academicYearId)                     errors.push('Academic year is required.');
        if (!gradeLevel)                         errors.push('Grade level is required.');
        if (!sectionId)                          errors.push('Section is required.');
    }

    if (errors.length) return res.status(400).json({ message: errors[0], errors });

    // ---- Existence check ----
    const existing = db.prepare('SELECT id FROM students WHERE id = ?').get(id);
    if (!existing) return res.status(404).json({ message: 'Student not found.' });

    // ---- Duplicate LRN check (excluding self) ----
    const duplicate = db.prepare('SELECT id FROM students WHERE lrn = ? AND id != ?').get(lrn.trim(), id);
    if (duplicate) return res.status(409).json({ message: `Another student already has LRN ${lrn}.` });

    // ---- Duplicate Name check (excluding self) ----
    const duplicateName = findDuplicateStudentByName(firstName, middleName, lastName, id);
    if (duplicateName) {
        const fullName = [firstName, middleName, lastName].filter(Boolean).map(s => s.trim()).join(' ');
        return res.status(409).json({
            message: `Another student named "${fullName}" already exists (LRN: ${duplicateName.lrn}).`
        });
    }

    try {
        db.transaction(() => {
            db.prepare(`
                UPDATE students
                SET lrn = ?, first_name = ?, middle_name = ?, last_name = ?,
                    extension = ?, sex = ?, birth_date = ?, status = ?, is_4ps = ?
                WHERE id = ?
            `).run(
                lrn.trim(),
                firstName.trim(),
                middleName?.trim() || null,
                lastName.trim(),
                extension?.trim()  || null,
                sex,
                birthDate || null,
                status || 'Enrolled',
                is4ps ? 1 : 0,
                id
            );

            if (academicYearId > 0 && gradeLevel > 0 && sectionId > 0) {
                // Get existing enrollment for the specific academic year and grade level
                const existingEnrollment = db.prepare(`
                    SELECT e.* FROM enrollments e
                    WHERE e.student_id = ? AND e.academic_year_id = ? AND e.grade_level = ?
                    LIMIT 1
                `).get(id, academicYearId, gradeLevel);

                if (existingEnrollment) {
                    // Update section and track_strand if they differ
                    if (existingEnrollment.section_id !== parseInt(sectionId) ||
                        existingEnrollment.track_strand !== (trackStrand || null)) {
                        db.prepare(`
                            UPDATE enrollments
                            SET section_id = ?, track_strand = ?
                            WHERE id = ?
                        `).run(sectionId, trackStrand || null, existingEnrollment.id);
                        logActivity(req.user?.id, 'UPDATE', 'enrollment', existingEnrollment.id, `UPDATE enrollment ${existingEnrollment.id} student ${lrn.trim()}`);
                    }
                } else {
                    // No enrollment for this year and grade, create a new one
                    const resEnr = db.prepare(`
                        INSERT INTO enrollments (student_id, academic_year_id, section_id, grade_level, track_strand)
                        VALUES (?, ?, ?, ?, ?)
                    `).run(id, academicYearId, sectionId, gradeLevel, trackStrand || null);
                    logActivity(req.user?.id, 'CREATE', 'enrollment', resEnr.lastInsertRowid, getEnrollmentLogDesc(academicYearId, gradeLevel, sectionId, lrn.trim()));
                }
            }

            // Auto-archive documents if status is non-enrolled
            const newStatus = status || 'Enrolled';
            if (['Graduated', 'Transferred', 'Dropped', 'Inactive'].includes(newStatus)) {
                db.prepare(`
                    UPDATE documents
                    SET status = 'Archived'
                    WHERE student_id = ? AND deleted_at IS NULL
                `).run(id);
            } else if (newStatus === 'Enrolled') {
                db.prepare(`
                    UPDATE documents
                    SET status = 'Completed'
                    WHERE student_id = ? AND deleted_at IS NULL AND status = 'Archived'
                `).run(id);
            }
        })();

        logActivity(req.user?.id, 'UPDATE', 'student', id, `Updated student details (LRN: ${lrn.trim()})`);

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

    const existing = db.prepare('SELECT id, first_name, last_name, lrn FROM students WHERE id = ?').get(id);
    if (!existing) return res.status(404).json({ message: 'Student not found.' });

    try {
        db.prepare('DELETE FROM students WHERE id = ?').run(id);
        logActivity(req.user?.id, 'DELETE', 'student', id, `Deleted student ${existing.first_name} ${existing.last_name} (LRN: ${existing.lrn})`);
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
            const getExistingEnrollment = db.prepare(`
                SELECT e.* FROM enrollments e
                WHERE e.student_id = ? AND e.academic_year_id = ? AND e.grade_level = ?
                LIMIT 1
            `);
            const updateEnrollment = db.prepare('UPDATE enrollments SET section_id = ?, track_strand = ? WHERE id = ?');
            const insertEnrollment = db.prepare('INSERT INTO enrollments (student_id, academic_year_id, section_id, grade_level, track_strand) VALUES (?, ?, ?, ?, ?)');
            const updateStudentStatus = db.prepare('UPDATE students SET status = ? WHERE id = ?');
            
            const getLrn = db.prepare('SELECT lrn FROM students WHERE id = ?');
            for (const studentId of studentIds) {
                const st = getLrn.get(studentId);
                const lrn = st?.lrn || studentId;
                const existing = getExistingEnrollment.get(studentId, academicYearId, gradeLevel);
                if (existing) {
                    if (existing.section_id !== parseInt(sectionId) ||
                        existing.track_strand !== (trackStrand || null)) {
                        updateEnrollment.run(sectionId, trackStrand || null, existing.id);
                        logActivity(req.user?.id, 'UPDATE', 'enrollment', existing.id, `UPDATE enrollment ${existing.id} student ${lrn}`);
                    }
                } else {
                    const resIns = insertEnrollment.run(studentId, academicYearId, sectionId, gradeLevel, trackStrand || null);
                    logActivity(req.user?.id, 'CREATE', 'enrollment', resIns.lastInsertRowid, getEnrollmentLogDesc(academicYearId, gradeLevel, sectionId, lrn));
                }
                updateStudentStatus.run('Enrolled', studentId);
            }
        })();
        logActivity(req.user?.id, 'UPDATE', 'student', null, `Bulk enrolled ${studentIds.length} students`);
        res.json({ message: `Successfully enrolled ${studentIds.length} students.` });
    } catch (error) {
        console.error('bulkEnrollStudents error:', error);
        res.status(500).json({ message: 'Failed to bulk enroll students', error: error.message });
    }
};

// ============================================================
// POST /api/students/bulk-status
// ============================================================
exports.bulkStatusStudents = (req, res) => {
    const { studentIds, status } = req.body;
    if (!Array.isArray(studentIds) || studentIds.length === 0) {
        return res.status(400).json({ message: 'studentIds must be a non-empty array' });
    }
    if (!status) {
        return res.status(400).json({ message: 'status is required' });
    }
    
    try {
        let studentDetails = [];
        db.transaction(() => {
            const updateStudentStatus = db.prepare('UPDATE students SET status = ? WHERE id = ?');
            const archiveDocuments = db.prepare('UPDATE documents SET status = ? WHERE student_id = ? AND deleted_at IS NULL');
            const getStudent = db.prepare('SELECT lrn, last_name FROM students WHERE id = ?');
            
            for (const studentId of studentIds) {
                updateStudentStatus.run(status, studentId);
                
                // Auto-archive documents if status is non-enrolled
                if (['Graduated', 'Transferred', 'Dropped', 'Inactive'].includes(status)) {
                    archiveDocuments.run('Archived', studentId);
                } else if (status === 'Enrolled') {
                    archiveDocuments.run('Completed', studentId); // We use archiveDocuments query which updates documents based on student_id
                }
                
                const student = getStudent.get(studentId);
                if (student) {
                    studentDetails.push(`${student.lrn} ${student.last_name}`);
                }
            }
        })();
        
        const detailsString = studentDetails.join(', ');
        logActivity(req.user?.id, 'UPDATE', 'student', null, `Bulk changed status to ${status} for: ${detailsString}`);
        
        res.json({ message: `Successfully changed status for ${studentIds.length} students.` });
    } catch (error) {
        console.error('bulkStatusStudents error:', error);
        res.status(500).json({ message: 'Failed to bulk change status', error: error.message });
    }
};

// ============================================================
// POST /api/students/:id/enrollments
// ============================================================
exports.addEnrollment = (req, res) => {
    const { id: studentId } = req.params;
    const { academicYearId, sectionId, gradeLevel, trackStrand } = req.body;

    if (!academicYearId || !sectionId || !gradeLevel) {
        return res.status(400).json({ message: 'academicYearId, sectionId, and gradeLevel are required' });
    }

    const student = db.prepare('SELECT id FROM students WHERE id = ?').get(studentId);
    if (!student) return res.status(404).json({ message: 'Student not found.' });

    // ---- Enrollment downgrade restriction ----
    const existingGradeRow = db.prepare(`
        SELECT MAX(grade_level) as max_grade
        FROM enrollments
        WHERE student_id = ? AND academic_year_id = ?
    `).get(studentId, academicYearId);
    
    const existingMaxGrade = existingGradeRow?.max_grade ?? null;
    if (existingMaxGrade !== null && gradeLevel < existingMaxGrade) {
        return res.status(400).json({
            message: `Cannot add enrollment. This student is already in Grade ${existingMaxGrade} for this academic year. You cannot add them to Grade ${gradeLevel} in the same academic year.`,
        });
    }

    try {
        const info = db.prepare(`
            INSERT INTO enrollments (student_id, academic_year_id, section_id, grade_level, track_strand)
            VALUES (?, ?, ?, ?, ?)
        `).run(studentId, academicYearId, sectionId, gradeLevel, trackStrand || null);

        const studentRow = db.prepare('SELECT lrn FROM students WHERE id = ?').get(studentId);
        const lrn = studentRow?.lrn || studentId;
        logActivity(req.user?.id, 'CREATE', 'enrollment', info.lastInsertRowid, getEnrollmentLogDesc(academicYearId, gradeLevel, sectionId, lrn));
        res.status(201).json({ message: 'Enrollment added successfully', id: info.lastInsertRowid });
    } catch (error) {
        console.error('addEnrollment error:', error);
        res.status(500).json({ message: 'Failed to add enrollment', error: error.message });
    }
};

// ============================================================
// PUT /api/students/enrollments/:enrollmentId
// ============================================================
exports.updateEnrollment = (req, res) => {
    const { enrollmentId } = req.params;
    const { academicYearId, sectionId, gradeLevel, trackStrand } = req.body;

    if (!academicYearId || !sectionId || !gradeLevel) {
        return res.status(400).json({ message: 'academicYearId, sectionId, and gradeLevel are required' });
    }

    const existing = db.prepare('SELECT * FROM enrollments WHERE id = ?').get(enrollmentId);
    if (!existing) return res.status(404).json({ message: 'Enrollment not found.' });

    // ---- Enrollment downgrade restriction ----
    const existingGradeRow = db.prepare(`
        SELECT MAX(grade_level) as max_grade
        FROM enrollments
        WHERE student_id = ? AND academic_year_id = ? AND id != ?
    `).get(existing.student_id, academicYearId, enrollmentId);
    
    const existingMaxGrade = existingGradeRow?.max_grade ?? null;
    if (existingMaxGrade !== null && gradeLevel < existingMaxGrade) {
        return res.status(400).json({
            message: `Cannot downgrade enrollment. This student is already in Grade ${existingMaxGrade} for this academic year. You cannot change it to Grade ${gradeLevel} in the same academic year.`,
        });
    }

    try {
        db.prepare(`
            UPDATE enrollments
            SET academic_year_id = ?, section_id = ?, grade_level = ?, track_strand = ?
            WHERE id = ?
        `).run(academicYearId, sectionId, gradeLevel, trackStrand || null, enrollmentId);

        const studentRow = db.prepare('SELECT lrn FROM students WHERE id = ?').get(existing.student_id);
        const lrn = studentRow?.lrn || existing.student_id;
        logActivity(req.user?.id, 'UPDATE', 'enrollment', enrollmentId, `UPDATE enrollment ${enrollmentId} student ${lrn}`);
        res.json({ message: 'Enrollment updated successfully' });
    } catch (error) {
        console.error('updateEnrollment error:', error);
        res.status(500).json({ message: 'Failed to update enrollment', error: error.message });
    }
};

// ============================================================
// DELETE /api/students/enrollments/:enrollmentId
// ============================================================
exports.deleteEnrollment = (req, res) => {
    const { enrollmentId } = req.params;

    const existing = db.prepare('SELECT * FROM enrollments WHERE id = ?').get(enrollmentId);
    if (!existing) return res.status(404).json({ message: 'Enrollment not found.' });

    try {
        db.prepare('DELETE FROM enrollments WHERE id = ?').run(enrollmentId);
        const studentRow = db.prepare('SELECT lrn FROM students WHERE id = ?').get(existing.student_id);
        const lrn = studentRow?.lrn || existing.student_id;
        logActivity(req.user?.id, 'DELETE', 'enrollment', enrollmentId, `DELETE enrollment ${enrollmentId} student ${lrn}`);
        res.json({ message: 'Enrollment deleted successfully' });
    } catch (error) {
        console.error('deleteEnrollment error:', error);
        res.status(500).json({ message: 'Failed to delete enrollment', error: error.message });
    }
};

// ============================================================
// POST /api/students/:id/ocr-enrollment
// ============================================================
exports.scanEnrollmentFromSF = async (req, res) => {
    try {
        const studentId = req.params.id;
        const docs = db.prepare(`
            SELECT * FROM documents
            WHERE student_id = ? AND deleted_at IS NULL
              AND (
                document_type LIKE '%SF10%' OR document_type LIKE '%SF9%'
                OR document_type LIKE '%Form 10%' OR document_type LIKE '%Form 9%'
                OR document_type LIKE '%Form 137%' OR document_type LIKE '%Form 138%'
                OR document_type LIKE '%School Form 10%' OR document_type LIKE '%School Form 9%'
                OR document_type LIKE '%Report Card%' OR document_type LIKE '%Permanent Record%'
                OR document_type LIKE '%SF1%' OR document_type LIKE '%SF-1%'
                OR file_name LIKE '%sf10%' OR file_name LIKE '%sf9%'
                OR file_name LIKE '%form 137%' OR file_name LIKE '%form 138%'
                OR file_name LIKE '%form 10%' OR file_name LIKE '%form 9%'
                OR file_name LIKE '%sf1%' OR file_name LIKE '%report card%'
              )
            ORDER BY id DESC
        `).all(studentId);

        if (!docs || docs.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'No SF10 or SF9 document found for this student. Auto Enrollment supports only SF9 and SF10 documents.'
            });
        }

        const sfEnrollmentService = require('../services/sfEnrollmentService');
        const seenKey = new Set();
        const records = [];
        let lastExtracted = null;
        let lastError = null;

        for (const doc of docs) {
            const result = await sfEnrollmentService.extractEnrollmentData({
                file: { path: doc.file_path, originalname: doc.file_name },
                documentType: doc.document_type,
                manual: true
            });
            if (!result.ok) {
                lastError = result.message;
                continue;
            }
            lastExtracted = result.extracted;
            for (const rec of result.uniqueRecords) {
                const gradeNum = parseInt(String(rec.gradeLevel).replace(/\D/g, ''), 10);
                const key = `${gradeNum}_${(rec.schoolYear || '').trim()}_${(rec.section || '').trim()}`.toLowerCase();
                if (seenKey.has(key)) continue;
                seenKey.add(key);
                records.push({
                    gradeLevel: String(gradeNum),
                    section: (rec.section || '').trim(),
                    schoolYear: (rec.schoolYear || '').trim(),
                    adviserName: rec.adviserName || '',
                    semester: rec.semester || ''
                });
            }
        }

        if (records.length === 0) {
            return res.status(400).json({
                success: false,
                message: lastError || 'No Grade 7-12 enrollment records could be extracted from the SF10/SF9 documents.'
            });
        }

        return res.json({
            success: true,
            message: `Scanned ${records.length} enrollment record(s). Review before saving.`,
            data: { extracted: lastExtracted, records }
        });
    } catch (error) {
        console.error('scanEnrollmentFromSF error:', error);
        res.status(500).json({ success: false, message: 'Failed to scan SF10/SF9 for enrollment', error: error.message });
    }
};

// ============================================================
// POST /api/students/bulk-ocr-import — bulk create students from OCR
// Each item: { lrn, firstName, middleName?, lastName, extension?, sex,
//              birthDate?, academicYearId, gradeLevel, sectionId,
//              trackStrand?, is4ps? }
// Returns 207: { created, skipped, failed, results[] }
// ============================================================
exports.bulkCreateStudents = (req, res) => {
    const { students } = req.body;

    if (!Array.isArray(students) || students.length === 0) {
        return res.status(400).json({ message: 'No student records provided.' });
    }

    const results = [];
    let created = 0;
    let skipped = 0;
    let failed  = 0;

    const insertOne = db.transaction((s) => {
        // Validate required fields
        const rowErrors = [];
        const lrn = (s.lrn || '').trim();
        const normDob = normalizeBirthDate(s.birthDate);
        if (!isValidLRN(lrn))                                        rowErrors.push('LRN must be exactly 12 digits.');
        if (!s.firstName || !s.firstName.trim())                     rowErrors.push('First name is required.');
        if (!s.lastName  || !s.lastName.trim())                      rowErrors.push('Last name is required.');
        if (!s.sex       || !['Male','Female'].includes(s.sex))      rowErrors.push('Sex must be Male or Female.');
        if (!s.academicYearId)                                       rowErrors.push('Academic year is required.');
        if (!s.gradeLevel)                                           rowErrors.push('Grade level is required.');
        if (!s.sectionId)                                            rowErrors.push('Section is required.');
        if (normDob) {
            const dob = new Date(normDob);
            if (isNaN(dob.getTime()))                                rowErrors.push('Invalid date of birth format.');
            else if (dob > new Date())                               rowErrors.push('Date of birth cannot be in the future.');
        }
        if (rowErrors.length) return { status: 'failed', reason: rowErrors[0] };

        // Duplicate LRN check — skip, don't fail the whole batch
        const existing = db.prepare('SELECT id FROM students WHERE lrn = ?').get(lrn);
        if (existing) return { status: 'skipped', reason: `LRN ${lrn} already exists.` };

        // Duplicate Name check (anti duplication from first, middle, and last name)
        const existingByName = findDuplicateStudentByName(s.firstName, s.middleName, s.lastName);
        if (existingByName) {
            const fullName = [s.firstName, s.middleName, s.lastName].filter(Boolean).map(str => str.trim()).join(' ');
            return {
                status: 'skipped',
                reason: `Student name "${fullName}" already exists (LRN: ${existingByName.lrn}).`
            };
        }

        const fnUpper = s.firstName.trim().toUpperCase();
        const mnUpper = s.middleName?.trim() ? s.middleName.trim().toUpperCase() : null;
        const lnUpper = s.lastName.trim().toUpperCase();
        const extUpper = s.extension?.trim() ? s.extension.trim().toUpperCase() : null;

        // Insert student
        const result = db.prepare(`
            INSERT INTO students (lrn, first_name, middle_name, last_name, extension, sex, birth_date, is_4ps)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
            lrn,
            fnUpper,
            mnUpper,
            lnUpper,
            extUpper,
            s.sex,
            normDob || null,
            s.is4ps ? 1 : 0
        );
        const newId = result.lastInsertRowid;

        // Insert enrollment
        const enrRes = db.prepare(`
            INSERT INTO enrollments (student_id, academic_year_id, section_id, grade_level, track_strand)
            VALUES (?, ?, ?, ?, ?)
        `).run(newId, s.academicYearId, s.sectionId, s.gradeLevel, s.trackStrand || null);
        logActivity(req.user?.id, 'CREATE', 'enrollment', enrRes.lastInsertRowid, getEnrollmentLogDesc(s.academicYearId, s.gradeLevel, s.sectionId, lrn));

        // Auto-create student directory
        const folderName = `${sanitizeFolderName(s.lastName)}_${sanitizeFolderName(s.firstName)}_${lrn}`;
        const studentDir = path.join(STUDENT_DIR_ROOT, folderName);
        if (!fs.existsSync(studentDir)) {
            fs.mkdirSync(studentDir, { recursive: true });
        }

        // Auto-create folder record
        try {
            db.prepare(`
                INSERT INTO document_folders (name, student_id, category, created_by)
                VALUES (?, ?, 'root', ?)
            `).run(folderName, newId, req.user?.id || null);
        } catch (_) { /* non-fatal */ }

        logActivity(req.user?.id, 'CREATE', 'student', newId,
            `BULK OCR CREATE student ${s.firstName} ${s.lastName}`);

        return { status: 'created', id: newId };
    });

    for (const s of students) {
        try {
            const outcome = insertOne(s);
            results.push({ lrn: (s.lrn || '').trim(), name: `${s.lastName}, ${s.firstName}`, ...outcome });
            if (outcome.status === 'created')  created++;
            else if (outcome.status === 'skipped') skipped++;
            else failed++;
        } catch (err) {
            console.error('bulkCreateStudents row error:', err.message);
            results.push({ lrn: (s.lrn || '').trim(), name: `${s.lastName}, ${s.firstName}`, status: 'failed', reason: err.message });
            failed++;
        }
    }

    if (created > 0) {
        createNotification(
            null,
            'Bulk OCR Import Complete',
            `${created} student(s) imported via OCR Bulk Import.`,
            'student'
        );
    }

    res.status(207).json({ created, skipped, failed, results });
};

