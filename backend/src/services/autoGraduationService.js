const db = require('../config/db');

const logActivity = (userId, action, entityType, entityId, description) => {
    try {
        let uid = userId;
        const userCheck = uid ? db.prepare("SELECT id FROM users WHERE id = ?").get(uid) : null;
        if (!userCheck) {
            const anyUser = db.prepare("SELECT id FROM users LIMIT 1").get();
            uid = anyUser ? anyUser.id : null;
        }
        db.prepare(`
            INSERT INTO activity_log (user_id, action, entity_type, entity_id, description)
            VALUES (?, ?, ?, ?, ?)
        `).run(uid, action, entityType, entityId, description);
    } catch (err) {
        console.error('logActivity error:', err.message);
    }
};

/**
 * Checks the active academic year start_date and end_date.
 * If not set, returns { executed: false, reason: 'if not set the start day, month, end year, do not auto graduate' }.
 * If set and today >= end_date, sequentially graduates Grade 10 and Grade 12 students in the active academic year.
 * Generates ONE compiled log entry for Grade 10, and ONE compiled log entry for Grade 12.
 */
const checkAndRunAutoGraduation = (userId = 1) => {
    try {
        const activeYear = db.prepare("SELECT * FROM academic_years WHERE status = 'active' LIMIT 1").get();
        if (!activeYear) {
            return { executed: false, reason: 'No active academic year found.' };
        }

        if (!activeYear.start_date || !activeYear.end_date) {
            return {
                executed: false,
                reason: 'if not set the start day, month, end year, do not auto graduate (start_date or end_date is missing).'
            };
        }

        // Compare today's date (YYYY-MM-DD) with end_date
        const todayStr = new Date().toISOString().slice(0, 10);
        if (todayStr < activeYear.end_date) {
            return {
                executed: false,
                reason: `Active academic year (${activeYear.year_range}) end date (${activeYear.end_date}) has not been reached yet (today: ${todayStr}).`
            };
        }

        // --- Sequentially process Grade 10 students ---
        const g10Students = db.prepare(`
            SELECT DISTINCT s.id, s.lrn, s.first_name, s.last_name
            FROM enrollments e
            JOIN students s ON e.student_id = s.id
            WHERE e.academic_year_id = ? AND e.grade_level = 10 AND s.status != 'Graduated'
            ORDER BY s.id ASC
        `).all(activeYear.id);

        const updateStatus = db.prepare("UPDATE students SET status = 'Graduated' WHERE id = ?");

        if (g10Students.length > 0) {
            db.transaction(() => {
                for (const st of g10Students) {
                    updateStatus.run(st.id);
                }
            })();
            const studentNames = g10Students.map(s => `${s.lrn || ''} (${s.first_name} ${s.last_name})`.trim()).join(', ');
            logActivity(
                userId,
                'UPDATE',
                'student',
                null,
                `Auto-graduated ${g10Students.length} Grade 10 student(s) for Academic Year ${activeYear.year_range}: ${studentNames}`
            );
        }

        // --- Sequentially process Grade 12 students ---
        const g12Students = db.prepare(`
            SELECT DISTINCT s.id, s.lrn, s.first_name, s.last_name
            FROM enrollments e
            JOIN students s ON e.student_id = s.id
            WHERE e.academic_year_id = ? AND e.grade_level = 12 AND s.status != 'Graduated'
            ORDER BY s.id ASC
        `).all(activeYear.id);

        if (g12Students.length > 0) {
            db.transaction(() => {
                for (const st of g12Students) {
                    updateStatus.run(st.id);
                }
            })();
            const studentNames12 = g12Students.map(s => `${s.lrn || ''} (${s.first_name} ${s.last_name})`.trim()).join(', ');
            logActivity(
                userId,
                'UPDATE',
                'student',
                null,
                `Auto-graduated ${g12Students.length} Grade 12 student(s) for Academic Year ${activeYear.year_range}: ${studentNames12}`
            );
        }

        return {
            executed: true,
            grade10Graduated: g10Students.length,
            grade12Graduated: g12Students.length,
            message: `Auto-graduation completed sequentially for active AY ${activeYear.year_range}. Graduated ${g10Students.length} Grade 10 and ${g12Students.length} Grade 12 student(s).`
        };
    } catch (err) {
        console.error('[autoGraduationService] checkAndRunAutoGraduation error:', err);
        return { executed: false, error: err.message };
    }
};

module.exports = {
    checkAndRunAutoGraduation
};
