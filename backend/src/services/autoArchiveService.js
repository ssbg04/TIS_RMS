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
        console.error('[autoArchiveService] logActivity error:', err.message);
    }
};

/**
 * Checks the active academic year start_date.
 * If not set or no active year, does not run auto-archive.
 * Grace period (in days) is fetched from system_settings ('enrollment_grace_period_days', default 30).
 * If today >= (start_date + grace_period_days):
 *   ONLY targets students with status = 'Enrolled' (never touches Graduated, Transferred, Dropped, or Inactive).
 *   Checks which of these 'Enrolled' students do NOT have an enrollment record in the active academic year.
 *   Updates their status to 'Inactive'.
 *   Archives their active documents (status = 'Archived').
 *   Logs the activity to activity_log.
 */
const checkAndRunAutoArchive = (userId = 1) => {
    try {
        const activeYear = db.prepare("SELECT * FROM academic_years WHERE status = 'active' LIMIT 1").get();
        if (!activeYear) {
            return { executed: false, reason: 'No active academic year found.' };
        }

        if (!activeYear.start_date) {
            return {
                executed: false,
                reason: 'Active academic year has no start_date configured.'
            };
        }

        // Fetch grace period days from system_settings (defaults to 30 days)
        const graceRow = db.prepare("SELECT value FROM system_settings WHERE key = 'enrollment_grace_period_days'").get();
        const graceDays = Math.max(1, parseInt(graceRow?.value || '30', 10));

        // Calculate cutoff date: start_date + graceDays
        const startDate = new Date(activeYear.start_date + 'T00:00:00');
        if (isNaN(startDate.getTime())) {
            return { executed: false, reason: 'Invalid start_date format in active academic year.' };
        }

        const cutoffDate = new Date(startDate);
        cutoffDate.setDate(cutoffDate.getDate() + graceDays);
        const cutoffDateStr = cutoffDate.toISOString().slice(0, 10);

        const todayStr = new Date().toISOString().slice(0, 10);
        if (todayStr < cutoffDateStr) {
            return {
                executed: false,
                reason: `Enrollment grace period (${graceDays} days) from academic year start (${activeYear.start_date}) has not been reached yet. Cutoff date is ${cutoffDateStr} (today: ${todayStr}).`
            };
        }

        // STRICT REQUIREMENT: ONLY TARGET STUDENTS WITH status = 'Enrolled'
        // Never alters students who are already Graduated, Transferred, Dropped, or Inactive.
        const unEnrolledStudents = db.prepare(`
            SELECT DISTINCT s.id, s.lrn, s.first_name, s.last_name
            FROM students s
            WHERE s.status = 'Enrolled'
              AND s.id NOT IN (
                  SELECT student_id FROM enrollments WHERE academic_year_id = ?
              )
            ORDER BY s.id ASC
        `).all(activeYear.id);

        if (unEnrolledStudents.length === 0) {
            return {
                executed: true,
                archivedCount: 0,
                message: `All enrolled students are registered in active academic year ${activeYear.year_range}. No students auto-archived.`
            };
        }

        const updateStudentStatus = db.prepare("UPDATE students SET status = 'Inactive' WHERE id = ?");
        const archiveStudentDocs = db.prepare(`
            UPDATE documents
            SET status = 'Archived'
            WHERE student_id = ? AND deleted_at IS NULL AND status != 'Archived'
        `);

        db.transaction(() => {
            for (const st of unEnrolledStudents) {
                updateStudentStatus.run(st.id);
                archiveStudentDocs.run(st.id);
            }
        })();

        const studentSummary = unEnrolledStudents.slice(0, 20).map(s => `${s.lrn || ''} (${s.first_name} ${s.last_name})`.trim()).join(', ');
        const extraText = unEnrolledStudents.length > 20 ? ` and ${unEnrolledStudents.length - 20} more` : '';

        logActivity(
            userId,
            'ARCHIVE',
            'student',
            null,
            `Auto-archived ${unEnrolledStudents.length} student(s) to 'Inactive' (no enrollment in AY ${activeYear.year_range} after ${graceDays}-day grace period): ${studentSummary}${extraText}`
        );

        return {
            executed: true,
            archivedCount: unEnrolledStudents.length,
            message: `Successfully auto-archived ${unEnrolledStudents.length} student(s) to 'Inactive'.`
        };
    } catch (err) {
        console.error('[autoArchiveService] checkAndRunAutoArchive error:', err);
        return { executed: false, error: err.message };
    }
};

module.exports = {
    checkAndRunAutoArchive
};
