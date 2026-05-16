const db = require('../config/db');

exports.enrollStudent = (req, res) => {
    const { studentId, academicYearId, sectionId, gradeLevel, trackStrand } = req.body;
    try {
        const result = db.prepare(`
            INSERT INTO enrollments (student_id, academic_year_id, section_id, grade_level, track_strand)
            VALUES (?, ?, ?, ?, ?)
        `).run(studentId, academicYearId, sectionId, gradeLevel, trackStrand);
        res.status(201).json({ id: result.lastInsertRowid, message: 'Student enrolled successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Enrollment failed', error: error.message });
    }
};

exports.getGradesByEnrollment = (req, res) => {
    try {
        const grades = db.prepare(`
            SELECT g.*, s.title, s.code, s.category 
            FROM grades g
            JOIN subjects s ON g.subject_id = s.id
            WHERE g.enrollment_id = ?
        `).all(req.params.enrollmentId);
        res.json(grades);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch grades', error: error.message });
    }
};

exports.updateGrades = (req, res) => {
    const { enrollmentId, subjectId, q1, q2, q3, q4, sem1, sem2, finalGrade, remarks } = req.body;
    try {
        const existing = db.prepare('SELECT id FROM grades WHERE enrollment_id = ? AND subject_id = ?').get(enrollmentId, subjectId);
        
        if (existing) {
            db.prepare(`
                UPDATE grades 
                SET q1 = ?, q2 = ?, q3 = ?, q4 = ?, sem1 = ?, sem2 = ?, final_grade = ?, remarks = ?
                WHERE id = ?
            `).run(q1, q2, q3, q4, sem1, sem2, finalGrade, remarks, existing.id);
        } else {
            db.prepare(`
                INSERT INTO grades (enrollment_id, subject_id, q1, q2, q3, q4, sem1, sem2, final_grade, remarks)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `).run(enrollmentId, subjectId, q1, q2, q3, q4, sem1, sem2, finalGrade, remarks);
        }
        res.json({ message: 'Grades updated successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to update grades', error: error.message });
    }
};

exports.getSF10Data = (req, res) => {
    const { studentId } = req.params;
    try {
        const student = db.prepare('SELECT * FROM students WHERE id = ?').get(studentId);
        if (!student) return res.status(404).json({ message: 'Student not found' });

        const enrollments = db.prepare(`
            SELECT e.*, ay.year_range, s.name as section_name 
            FROM enrollments e
            JOIN academic_years ay ON e.academic_year_id = ay.id
            JOIN sections s ON e.section_id = s.id
            WHERE e.student_id = ?
            ORDER BY e.grade_level ASC
        `).all(studentId);

        const data = enrollments.map(enrollment => {
            const grades = db.prepare(`
                SELECT g.*, sub.title, sub.code, sub.category 
                FROM grades g
                JOIN subjects sub ON g.subject_id = sub.id
                WHERE g.enrollment_id = ?
            `).all(enrollment.id);
            return { ...enrollment, grades };
        });

        res.json({ student, history: data });
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch SF10 data', error: error.message });
    }
};
