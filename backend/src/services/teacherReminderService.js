const db = require('../config/db');
const { sendTeacherAttentionReminder } = require('./emailService');

const logActivity = (userId, action, entityType, entityId, description) => {
    try {
        let uid = userId;
        const userCheck = uid ? db.prepare("SELECT id FROM users WHERE id = ?").get(uid) : null;
        if (!userCheck) {
            const anyUser = db.prepare("SELECT id FROM users WHERE role = 'admin' LIMIT 1").get();
            uid = anyUser ? anyUser.id : null;
        }
        db.prepare(`
            INSERT INTO activity_log (user_id, action, entity_type, entity_id, description)
            VALUES (?, ?, ?, ?, ?)
        `).run(uid, action, entityType, entityId, description);
    } catch (err) {
        console.error('[teacherReminderService] logActivity error:', err.message);
    }
};

/**
 * Checks document requirements with due dates and sends automated reminder emails
 * to advisory teachers whose enrolled students are missing those requirements.
 */
const checkAndRunTeacherDueDateReminders = async (forced = false) => {
    try {
        const enabledRow = db.prepare("SELECT value FROM system_settings WHERE key = 'remind_teachers_due_date_enabled'").get();
        const isEnabled = enabledRow?.value === 'true';

        if (!isEnabled && !forced) {
            return { executed: false, reason: 'Teacher due date reminders are disabled in system settings.' };
        }

        const daysRow = db.prepare("SELECT value FROM system_settings WHERE key = 'remind_teachers_due_date_days'").get();
        const reminderDays = parseInt(daysRow?.value || '3', 10) || 3;

        // Today's date string YYYY-MM-DD
        const now = new Date();
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const day = String(now.getDate()).padStart(2, '0');
        const todayStr = `${year}-${month}-${day}`;

        // Check if already executed today
        if (!forced) {
            const lastRunRow = db.prepare("SELECT value FROM system_settings WHERE key = 'last_teacher_reminder_date'").get();
            if (lastRunRow?.value === todayStr) {
                return { executed: false, reason: 'Teacher due date reminders already ran today.' };
            }
        }

        // Get enabled document requirements that have a due date set
        const requirements = db.prepare(`
            SELECT id, name, category, due_date, is_mandatory
            FROM document_requirements
            WHERE is_enabled = 1 AND due_date IS NOT NULL AND TRIM(due_date) != ''
        `).all();

        if (requirements.length === 0) {
            if (!forced) {
                db.prepare(`
                    INSERT INTO system_settings (key, value, updated_at)
                    VALUES ('last_teacher_reminder_date', ?, CURRENT_TIMESTAMP)
                    ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = CURRENT_TIMESTAMP
                `).run(todayStr);
            }
            return { executed: false, reason: 'No document requirements with due dates found.' };
        }

        // Filter requirements that are due within reminderDays (0 <= diffDays <= reminderDays)
        const todayDateOnly = new Date(`${todayStr}T00:00:00`);
        const dueSoonRequirements = requirements.filter(req => {
            const reqDateStr = req.due_date.split('T')[0].split(' ')[0];
            const reqDate = new Date(`${reqDateStr}T00:00:00`);
            const diffTime = reqDate.getTime() - todayDateOnly.getTime();
            const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
            return diffDays >= 0 && diffDays <= reminderDays;
        });

        if (dueSoonRequirements.length === 0) {
            if (!forced) {
                db.prepare(`
                    INSERT INTO system_settings (key, value, updated_at)
                    VALUES ('last_teacher_reminder_date', ?, CURRENT_TIMESTAMP)
                    ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = CURRENT_TIMESTAMP
                `).run(todayStr);
            }
            return { executed: false, reason: `No document requirements due within the next ${reminderDays} day(s).` };
        }

        // Get active teachers with emails
        const teachers = db.prepare(`
            SELECT id, username, first_name, middle_name, last_name, email
            FROM users
            WHERE role = 'teacher' AND is_active = 1 AND email IS NOT NULL AND TRIM(email) != ''
        `).all();

        if (teachers.length === 0) {
            return { executed: false, reason: 'No active teachers with valid emails found.' };
        }

        let sentCount = 0;
        let skippedCount = 0;

        for (const teacher of teachers) {
            const teacherName = `${teacher.first_name} ${teacher.last_name}`.trim();

            // Get sections assigned to this teacher
            const sections = db.prepare(`
                SELECT s.id, s.name, s.grade_level
                FROM teacher_sections ts
                JOIN sections s ON ts.section_id = s.id
                WHERE ts.teacher_id = ?
                ORDER BY s.grade_level ASC, s.name ASC
            `).all(teacher.id);

            if (sections.length === 0) {
                skippedCount++;
                continue;
            }

            const sectionsWithAttentionStudents = [];

            for (const section of sections) {
                // Find enrolled students in this section
                const students = db.prepare(`
                    SELECT s.id, s.lrn, s.first_name, s.middle_name, s.last_name, s.extension
                    FROM enrollments e
                    JOIN students s ON e.student_id = s.id
                    WHERE e.section_id = ? AND s.status = 'Enrolled'
                    ORDER BY s.last_name ASC, s.first_name ASC
                `).all(section.id);

                const sectionAttentionStudents = [];

                for (const student of students) {
                    const studentFullName = [student.last_name, student.first_name, student.middle_name, student.extension]
                        .filter(Boolean)
                        .join(' ');

                    // Check missing requirements among the due soon requirements
                    const studentLevelCategory = section.grade_level <= 10 ? 'JHS' : 'SHS';
                    const matchingReqs = dueSoonRequirements.filter(r => r.category === studentLevelCategory);

                    if (matchingReqs.length === 0) continue;

                    const missingForStudent = [];

                    for (const req of matchingReqs) {
                        const hasCompleted = db.prepare(`
                            SELECT id FROM documents
                            WHERE student_id = ? AND requirement_id = ? AND status = 'Completed' AND deleted_at IS NULL
                            LIMIT 1
                        `).get(student.id, req.id);

                        if (!hasCompleted) {
                            const reqDateStr = req.due_date.split('T')[0].split(' ')[0];
                            missingForStudent.push(`${req.name} (Due: ${reqDateStr})`);
                        }
                    }

                    if (missingForStudent.length > 0) {
                        sectionAttentionStudents.push({
                            id: student.id,
                            lrn: student.lrn,
                            name: studentFullName,
                            missingDocs: missingForStudent
                        });
                    }
                }

                if (sectionAttentionStudents.length > 0) {
                    sectionsWithAttentionStudents.push({
                        sectionId: section.id,
                        sectionName: section.name,
                        gradeLevel: section.grade_level,
                        students: sectionAttentionStudents
                    });
                }
            }

            if (sectionsWithAttentionStudents.length > 0) {
                try {
                    // Validate teacher email before sending reminder (MEV / QEV)
                    let validEmail = true;
                    try {
                        const { validateEmailMEV } = require('../controllers/authController');
                        const mevResult = await validateEmailMEV(teacher.email);
                        if (!mevResult.valid) {
                            validEmail = false;
                            console.warn(`[TeacherReminderService] Skipping ${teacher.email}: ${mevResult.reason}`);
                        }
                    } catch (_) {}

                    if (!validEmail) {
                        skippedCount++;
                        continue;
                    }

                    await sendTeacherAttentionReminder({
                        to: teacher.email,
                        teacherName,
                        sectionsWithStudents: sectionsWithAttentionStudents
                    });
                    sentCount++;
                } catch (err) {
                    console.error(`[TeacherReminderService] Failed to send reminder email to ${teacher.email}:`, err.message);
                }
            } else {
                skippedCount++;
            }
        }

        // Mark today as executed
        db.prepare(`
            INSERT INTO system_settings (key, value, updated_at)
            VALUES ('last_teacher_reminder_date', ?, CURRENT_TIMESTAMP)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = CURRENT_TIMESTAMP
        `).run(todayStr);

        if (sentCount > 0) {
            logActivity(
                null,
                'NOTIFY',
                'system_settings',
                null,
                `Automated due date reminder emails sent to ${sentCount} teacher(s)`
            );
            console.log(`[TeacherReminderService] Successfully sent due date reminder emails to ${sentCount} teacher(s).`);
        }

        return {
            executed: true,
            sentCount,
            skippedCount,
            dueRequirementsCount: dueSoonRequirements.length
        };
    } catch (error) {
        console.error('[TeacherReminderService] checkAndRunTeacherDueDateReminders error:', error);
        return { executed: false, error: error.message };
    }
};

module.exports = {
    checkAndRunTeacherDueDateReminders
};
