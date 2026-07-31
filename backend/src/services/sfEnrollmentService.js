const fs = require('fs');
const path = require('path');
const db = require('../config/db');
const ocrParser = require('./ocrParser');

const logActivity = (userId, action, entityType, entityId, description) => {
    try {
        db.prepare(`
            INSERT INTO activity_log (user_id, action, entity_type, entity_id, description)
            VALUES (?, ?, ?, ?, ?)
        `).run(userId, action, entityType, entityId, description);
    } catch (err) {
        console.error('logActivity error:', err.message);
    }
};

const findTeacherUser = (db, adviserName) => {
    if (!adviserName || typeof adviserName !== 'string') return null;
    const clean = adviserName.trim().toLowerCase();
    if (!clean) return null;

    const allUsers = db.prepare("SELECT id, first_name, last_name, username FROM users WHERE role IN ('teacher', 'admin')").all();
    for (const u of allUsers) {
        const full1 = `${(u.first_name || '').trim()} ${(u.last_name || '').trim()}`.toLowerCase().replace(/\s+/g, ' ');
        const full2 = `${(u.last_name || '').trim()}, ${(u.first_name || '').trim()}`.toLowerCase().replace(/\s+/g, ' ');
        const userClean = (u.username || '').trim().toLowerCase();
        if (clean === full1 || clean === full2 || clean === userClean) {
            return u;
        }
    }
    return null;
};

exports.autoEnrollFromSF = async ({ studentId, file, documentType = '', userId = null, manual = false }) => {
    // 1. If not manual, check toggle setting in system_settings
    if (!manual) {
        const settingRow = db.prepare("SELECT value FROM system_settings WHERE key = 'auto_update_enrollment_from_sf'").get();
        if (settingRow && (settingRow.value === 'false' || settingRow.value === '0')) {
            return {
                success: false,
                skipped: true,
                message: 'Auto-update enrollment from SF10/SF9 is disabled in system settings.'
            };
        }
    }

    // 2. Determine if SF10 or SF9
    const docTypeStr = String(documentType || '');
    const fileNameStr = String(file?.originalname || file?.name || '');
    const isSF10 = /sf10|sf-10|sf 10|permanent record|form 10/i.test(docTypeStr) ||
                   /sf10|sf-10|sf 10|permanent record|form 10/i.test(fileNameStr);
    const isSF9  = /sf9|sf-9|sf 9|report card|form 9/i.test(docTypeStr) ||
                   /sf9|sf-9|sf 9|report card|form 9/i.test(fileNameStr);

    if (!isSF10 && !isSF9 && !manual) {
        return {
            success: false,
            skipped: true,
            message: 'Document is not an SF10 or SF9.'
        };
    }

    if (!file || !file.path || !fs.existsSync(file.path)) {
        return {
            success: false,
            message: 'File path not found for OCR scanning.'
        };
    }

    // 3. Extract text from PDF, Image, or Excel
    let text = '';
    try {
        text = await ocrParser.extractTextFromFile(file.path, file.originalname || '', file.mimetype || '');
    } catch (err) {
        console.error('[sfEnrollmentService] OCR/Excel text extraction error:', err.message);
        return {
            success: false,
            message: 'Failed to extract text from document: ' + err.message
        };
    }

    if (!text || text.trim().length === 0) {
        return {
            success: false,
            message: 'No readable text extracted from document.'
        };
    }

    // 4. Parse text using SF10 or SF9 parser
    const docLabel = isSF10 ? 'SF10' : (isSF9 ? 'SF9' : 'SF Document');
    let extracted = isSF10 ? ocrParser.parseSF10(text) : ocrParser.parseSF9(text);
    if (!extracted.schoolYear && !extracted.gradeLevel && !extracted.section && !isSF10) {
        // Fallback check: if we tried SF9 and got nothing, try SF10 just in case
        extracted = ocrParser.parseSF10(text);
    } else if (!extracted.schoolYear && !extracted.gradeLevel && !extracted.section && isSF10) {
        extracted = ocrParser.parseSF9(text);
    }

    const { schoolYear, gradeLevel, section, trackStrand } = extracted;

    // 5. Gather all records to enroll (use deduplicated scholasticRecords or fallback to single extracted)
    let recordsToEnroll = Array.isArray(extracted.scholasticRecords) && extracted.scholasticRecords.length > 0
        ? extracted.scholasticRecords
        : [{
            gradeLevel: extracted.gradeLevel,
            section: extracted.section,
            schoolYear: extracted.schoolYear,
            adviserName: extracted.adviserName || '',
            semester: extracted.semester || '',
            trackStrand: extracted.trackStrand || null
        }];

    // Deduplicate: if 2 sem is the same, do not duplicate
    const uniqueRecords = [];
    const seenSemKey = new Set();
    for (const rec of recordsToEnroll) {
        const gradeNum = parseInt(String(rec.gradeLevel).replace(/\D/g, ''), 10);
        if (isNaN(gradeNum) || gradeNum <= 0 || !rec.section) continue;

        const syStr = (rec.schoolYear || '').trim();
        const secName = (rec.section || '').trim();
        const dedupeKey = `${gradeNum}_${syStr}_${secName}`.toLowerCase();
        if (!seenSemKey.has(dedupeKey)) {
            seenSemKey.add(dedupeKey);
            uniqueRecords.push(rec);
        }
    }

    if (uniqueRecords.length === 0) {
        return {
            success: false,
            message: `Could not extract Grade Level and Section from ${docLabel}. Found -> Grade: "${gradeLevel || ''}", Section: "${section || ''}"`
        };
    }

    let lastAction = '';
    let processedRecords = [];

    for (const rec of uniqueRecords) {
        const gradeNum = parseInt(String(rec.gradeLevel).replace(/\D/g, ''), 10);
        const sectionName = rec.section.trim();
        let syStr = (rec.schoolYear || '').trim();

        // 5a. Resolve Academic Year
        let ayRow = null;
        if (syStr) {
            ayRow = db.prepare('SELECT id, year_range FROM academic_years WHERE year_range = ?').get(syStr);
            if (!ayRow && /^\d{4}-\d{4}$/.test(syStr)) {
                const res = db.prepare("INSERT INTO academic_years (year_range, status) VALUES (?, 'inactive')").run(syStr);
                ayRow = { id: res.lastInsertRowid, year_range: syStr };
            }
        }
        if (!ayRow) {
            ayRow = db.prepare("SELECT id, year_range FROM academic_years WHERE status = 'active' LIMIT 1").get();
        }
        if (!ayRow) continue;

        // 6. Resolve or Create Section
        let secRow = db.prepare(`
            SELECT id FROM sections
            WHERE LOWER(name) = LOWER(?) AND grade_level = ? AND (academic_year_id = ? OR academic_year_id IS NULL)
        `).get(sectionName, gradeNum, ayRow.id);

        if (!secRow) {
            const res = db.prepare(`
                INSERT INTO sections (name, grade_level, academic_year_id)
                VALUES (?, ?, ?)
            `).run(sectionName, gradeNum, ayRow.id);
            secRow = { id: res.lastInsertRowid };
        }

        // 6b. Check Teacher Name -> do not fill out if the name of teacher is not on the database users
        if (rec.adviserName) {
            const teacherUser = findTeacherUser(db, rec.adviserName);
            if (teacherUser) {
                const existingTeacherSec = db.prepare(`
                    SELECT id FROM teacher_sections WHERE teacher_id = ? AND section_id = ?
                `).get(teacherUser.id, secRow.id);
                if (!existingTeacherSec) {
                    db.prepare(`
                        INSERT INTO teacher_sections (teacher_id, section_id) VALUES (?, ?)
                    `).run(teacherUser.id, secRow.id);
                }
            } else {
                console.log(`[sfEnrollmentService] Teacher "${rec.adviserName}" not found in database users. Skipping teacher assignment.`);
            }
        }

        // 7. Check Existing Enrollment
        const existingEnrollment = db.prepare(`
            SELECT * FROM enrollments
            WHERE student_id = ? AND academic_year_id = ? AND grade_level = ?
            LIMIT 1
        `).get(studentId, ayRow.id, gradeNum);

        const cleanTrackStrand = (rec.trackStrand || trackStrand) ? (rec.trackStrand || trackStrand).trim() : null;

        const studentRow = db.prepare('SELECT lrn FROM students WHERE id = ?').get(studentId);
        const lrn = studentRow?.lrn || studentId;

        if (existingEnrollment) {
            if (existingEnrollment.section_id !== secRow.id ||
                (cleanTrackStrand && existingEnrollment.track_strand !== cleanTrackStrand)) {
                db.prepare(`
                    UPDATE enrollments
                    SET section_id = ?, track_strand = ?
                    WHERE id = ?
                `).run(secRow.id, cleanTrackStrand || existingEnrollment.track_strand || null, existingEnrollment.id);
                lastAction = 'updated';
                logActivity(userId, 'UPDATE', 'enrollment', existingEnrollment.id, `UPDATE enrollment ${existingEnrollment.id} student ${lrn}`);
            } else {
                lastAction = 'already_up_to_date';
            }
        } else {
            const resEnr = db.prepare(`
                INSERT INTO enrollments (student_id, academic_year_id, section_id, grade_level, track_strand)
                VALUES (?, ?, ?, ?, ?)
            `).run(studentId, ayRow.id, secRow.id, gradeNum, cleanTrackStrand);
            lastAction = 'added';
            logActivity(userId, 'CREATE', 'enrollment', resEnr.lastInsertRowid, `CREATE enrollment ${resEnr.lastInsertRowid} student ${lrn}`);
        }

        processedRecords.push({
            gradeLevel: String(gradeNum),
            section: sectionName,
            schoolYear: ayRow.year_range,
            adviserName: rec.adviserName || '',
            semester: rec.semester || '',
            action: lastAction
        });
    }

    // 8. Log Activity
    const student = db.prepare('SELECT first_name, last_name, lrn FROM students WHERE id = ?').get(studentId);
    const studentName = student ? `${student.first_name} ${student.last_name}`.trim() : `Student #${studentId}`;
    const latestRec = processedRecords[processedRecords.length - 1] || {};
    const logMsg = `Successful OCR scan of ${docLabel} for ${studentName} - Processed ${processedRecords.length} enrollment record(s): latest SY ${latestRec.schoolYear || 'N/A'}, Grade ${latestRec.gradeLevel || 'N/A'}, Section ${latestRec.section || 'N/A'}`;
    logActivity(userId || null, 'CREATE', 'enrollment', studentId, logMsg);

    return {
        success: true,
        action: lastAction || 'processed',
        schoolYear: latestRec.schoolYear || schoolYear,
        gradeLevel: latestRec.gradeLevel || gradeLevel,
        section: latestRec.section || section,
        trackStrand: trackStrand || null,
        message: logMsg,
        allRecords: processedRecords
    };
};
