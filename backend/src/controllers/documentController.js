const db = require('../config/db');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { createNotification } = require('./notificationController');
const LibreOfficeService = require('../services/libreOfficeService');

// ── Helper: insert one row into activity_log ─────────────────────────────────
const logActivity = (userId, action, entityType, entityId, description) => {
    try {
        db.prepare(
            'INSERT INTO activity_log (user_id, action, entity_type, entity_id, description) VALUES (?, ?, ?, ?, ?)'
        ).run(userId ?? null, action, entityType, entityId ?? null, description);
    } catch (err) {
        console.error('logActivity error:', err.message);
    }
};

// ── Helper: format file size in human-readable string ─────────────────────────
const formatBytes = (bytes) => {
    if (bytes === null || bytes === undefined || isNaN(bytes) || bytes < 0) return 'Unknown';
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
};

const getDocSize = (d) => {
    if (d.file_size !== null && d.file_size !== undefined && d.file_size > 0) {
        return d.file_size;
    }
    if (d.file_path && fs.existsSync(d.file_path)) {
        try {
            const stat = fs.statSync(d.file_path);
            return stat.size;
        } catch (_) {}
    }
    return null;
};

const STUDENT_DIR_ROOT = process.env.STUDENT_DIR_ROOT
    ? path.resolve(process.env.STUDENT_DIR_ROOT)
    : path.resolve(__dirname, '../../../data/students');

const sanitizeFolderName = (str) =>
    (str || '').replace(/[<>:"/\\|?*\x00-\x1F]/g, '').trim();

// Configure Multer
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        // We expect studentId, documentType, and requirementId in req.body
        const { studentId, documentType, requirementId } = req.body;

        let uploadPath = process.env.UPLOAD_PATH ? path.resolve(process.env.UPLOAD_PATH) : path.resolve(__dirname, '../../../data/uploads');

        if (studentId) {
            try {
                const student = db.prepare('SELECT lrn, first_name, last_name FROM students WHERE id = ?').get(studentId);
                if (student) {
                    const folderName = `${sanitizeFolderName(student.last_name)}_${sanitizeFolderName(student.first_name)}_${student.lrn}`;
                    uploadPath = path.join(STUDENT_DIR_ROOT, folderName);

                    // Determine subfolder: 'JHS Documents', 'SHS Documents', or fallback to documentType
                    let subFolder = documentType ? sanitizeFolderName(documentType) : 'Documents';
                    if (requirementId && requirementId !== 'null') {
                        try {
                            const reqRow = db.prepare('SELECT category FROM document_requirements WHERE id = ?').get(requirementId);
                            if (reqRow?.category === 'JHS') subFolder = 'JHS Documents';
                            else if (reqRow?.category === 'SHS') subFolder = 'SHS Documents';
                        } catch (reqErr) {
                            console.error('Error fetching requirement category:', reqErr);
                        }
                    }
                    uploadPath = path.join(uploadPath, subFolder);
                }
            } catch (err) {
                console.error('Error fetching student for upload path:', err);
            }
        }

        if (!fs.existsSync(uploadPath)) {
            fs.mkdirSync(uploadPath, { recursive: true });
        }
        // Store for use by filename callback (collision detection)
        req._uploadPath = uploadPath;
        cb(null, uploadPath);
    },
    filename: (req, file, cb) => {
        // Use the document type name as the filename (originalname is set to the doc type by the frontend).
        // Add a human-readable timestamp prefix only if a file with the same name already exists (collision guard).
        const ext = path.extname(file.originalname);
        const base = sanitizeFolderName(path.basename(file.originalname, ext));
        const desiredName = `${base}${ext}`;

        const destDir = req._uploadPath;
        if (destDir && fs.existsSync(path.join(destDir, desiredName))) {
            // File already exists — prefix with readable timestamp e.g. "2026-07-25_00-45-23"
            const now = new Date();
            const pad = (n) => String(n).padStart(2, '0');
            const ts = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}_${pad(now.getHours())}-${pad(now.getMinutes())}-${pad(now.getSeconds())}`;
            cb(null, `${ts}-${desiredName}`);
        } else {
            cb(null, desiredName);
        }
    }
});

const upload = multer({
    storage,
    limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
    fileFilter: (req, file, cb) => {
        // Only allow certain file types
        const allowedMimeTypes = [
            'application/pdf', 
            'image/jpeg', 
            'image/png', 
            'image/jpg',
            'application/msword', // .doc
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document', // .docx
            'application/vnd.ms-excel', // .xls
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' // .xlsx
        ];
        if (allowedMimeTypes.includes(file.mimetype)) {
            cb(null, true);
        } else {
            cb(new Error('Invalid file format. Supported: PDF, JPG, PNG, DOC/DOCX, XLS/XLSX.'), false);
        }
    }
});

exports.uploadMiddleware = (req, res, next) => {
    upload.single('document')(req, res, (err) => {
        if (err) {
            return res.status(400).json({ message: err.message });
        }
        next();
    });
};

exports.uploadDocument = (req, res) => {
    const { studentId, requirementId, documentType } = req.body;
    const file = req.file;

    if (!file) return res.status(400).json({ message: 'No file uploaded' });
    if (!studentId) return res.status(400).json({ message: 'Student ID is required' });
    if (!documentType) return res.status(400).json({ message: 'Document Type is required' });

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
            if (file.path && fs.existsSync(file.path)) {
                fs.unlinkSync(file.path);
            }
            return res.status(403).json({ message: 'Access denied to upload documents for this student.' });
        }
    }

    try {
        const reqId = requirementId && requirementId !== 'null' ? requirementId : null;
        const fileSize = file.size || (file.path && fs.existsSync(file.path) ? fs.statSync(file.path).size : null);

        const result = db.prepare(`
            INSERT INTO documents (student_id, requirement_id, file_name, file_path, document_type, status, uploaded_by, file_size)
            VALUES (?, ?, ?, ?, ?, 'Completed', ?, ?)
        `).run(studentId, reqId, file.originalname, file.path, documentType, req.user.id, fileSize);

        // Log activity
        const student = db.prepare('SELECT first_name, last_name FROM students WHERE id = ?').get(studentId);
        const studentName = student ? `${student.first_name} ${student.last_name}` : `Student #${studentId}`;
        logActivity(req.user.id, 'CREATE', 'document', result.lastInsertRowid,
            `Uploaded "${file.originalname}" (${documentType}) for ${studentName}`);

        createNotification(null, 'Document Uploaded', `Document "${file.originalname}" (${documentType}) has been uploaded for ${studentName}.`, 'document', 'document', result.lastInsertRowid);

        // Check auto-enrollment update if document is SF10 or SF9
        try {
            const sfEnrollmentService = require('../services/sfEnrollmentService');
            sfEnrollmentService.autoEnrollFromSF({
                studentId,
                file: { path: file.path, originalname: file.originalname, mimetype: file.mimetype },
                documentType,
                userId: req.user?.id,
                manual: false
            }).catch(e => console.error('[uploadDocument] autoEnrollFromSF async error:', e.message));
        } catch (sfErr) {
            console.error('[uploadDocument] autoEnrollFromSF trigger error:', sfErr.message);
        }

        res.status(201).json({ id: result.lastInsertRowid, message: 'Document uploaded successfully' });
    } catch (error) {
        console.error('Upload Error:', error);
        res.status(500).json({ message: 'Failed to upload document', error: error.message });
    }
};


exports.viewDocument = (req, res) => {
    try {
        const doc = db.prepare('SELECT student_id, file_path, file_name FROM documents WHERE id = ?').get(req.params.id);
        if (!doc) return res.status(404).json({ message: 'Document not found' });

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
            `).get(doc.student_id, req.user.id, doc.student_id);
            if (!hasAccess) {
                return res.status(403).json({ message: 'Access denied to this document.' });
            }
        }

        if (!fs.existsSync(doc.file_path)) {
            return res.status(404).json({ message: 'File not found on server' });
        }
        
        if (req.query.download === 'true') {
            res.download(path.resolve(doc.file_path), doc.file_name);
        } else {
            res.sendFile(path.resolve(doc.file_path));
        }
    } catch (error) {
        console.error('viewDocument error:', error);
        res.status(500).json({ message: 'Failed to view document', error: error.message });
    }
};

exports.getAllDocuments = (req, res) => {
    const {
        search = '',
        page = 1,
        limit = 20,
        status = '',
        documentType = '',
        gradeLevel = '',
        schoolYear = '',
        studentId = ''
    } = req.query;

    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (pageNum - 1) * limitNum;

    try {
        const conditions = [];
        const params = [];

        if (search.trim()) {
            const like = `%${search.trim().split('').join('%' )}%`;
            conditions.push(`(s.lrn LIKE ? OR s.first_name LIKE ? OR s.last_name LIKE ? OR d.file_name LIKE ?)`);
            params.push(like, like, like, like);
        }

        if (status.trim() && status !== 'All Statuses') {
            conditions.push(`d.status = ?`);
            params.push(status.trim());
        } else {
            // Default on active Documents screen: hide archived files
            conditions.push(`d.status = 'Completed'`);
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

        // Only show active documents for Enrolled students
        conditions.push("d.deleted_at IS NULL");
        conditions.push("s.status = 'Enrolled'");

        const isTeacher = req.user?.role?.toLowerCase() === 'teacher';
        const teacherId = req.user?.id;

        const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

        const teacherJoin = isTeacher 
            ? `JOIN teacher_sections ts ON e.section_id = ts.section_id AND ts.teacher_id = ?`
            : '';
        
        if (isTeacher) {
            params.unshift(teacherId);
        }

        const joins = `
            LEFT JOIN students s ON d.student_id = s.id
            LEFT JOIN enrollments e ON e.student_id = s.id 
                AND e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay_inner ON e2.academic_year_id = ay_inner.id
                    WHERE e2.student_id = s.id
                    ORDER BY ay_inner.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
                )
            ${teacherJoin}
            LEFT JOIN academic_years ay ON e.academic_year_id = ay.id
            LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
        `;

        const countSql = `
            SELECT COUNT(DISTINCT d.id) as total
            FROM documents d
            ${joins}
            ${whereClause}
        `;
        const total = db.prepare(countSql).get(params).total;

        const fetchSql = `
            SELECT DISTINCT
                d.id, d.student_id, d.requirement_id, d.file_name, d.document_type, d.status, d.created_at, d.file_path, d.uploaded_by, d.file_size,
                s.lrn as student_lrn,
                s.first_name || ' ' || s.last_name as student_name,
                TRIM(COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '')) as uploaded_by_name,
                u.username as uploaded_by_username
            FROM documents d
            LEFT JOIN users u ON d.uploaded_by = u.id
            ${joins}
            ${whereClause}
            ORDER BY d.created_at DESC
            LIMIT ? OFFSET ?
        `;

        const documents = db.prepare(fetchSql).all([...params, limitNum, offset]);

        const mappedDocs = documents.map(d => {
            const rawSize = getDocSize(d);
            const uploaderName = d.uploaded_by_name && d.uploaded_by_name.trim().length > 0
                ? d.uploaded_by_name.trim()
                : (d.uploaded_by_username || (d.uploaded_by ? `User #${d.uploaded_by}` : null));
            return {
                id: d.id,
                studentId: d.student_id,
                requirementId: d.requirement_id,
                fileName: d.file_name,
                documentType: d.document_type,
                status: d.status,
                createdAt: d.created_at,
                studentLrn: d.student_lrn,
                studentName: d.student_name,
                uploadedBy: d.uploaded_by,
                uploadedByName: uploaderName,
                fileSize: rawSize,
                size: rawSize !== null ? formatBytes(rawSize) : 'Unknown',
                filePath: d.file_path
            };
        });

        res.json({
            documents: mappedDocs,
            pagination: {
                total,
                page: pageNum,
                limit: limitNum,
                totalPages: Math.ceil(total / limitNum)
            }
        });

    } catch (error) {
        console.error('getAllDocuments error:', error);
        res.status(500).json({ message: 'Failed to fetch documents', error: error.message });
    }
};

exports.getRequirements = (req, res) => {
    try {
        const requirements = db.prepare('SELECT * FROM document_requirements ORDER BY name ASC').all();
        res.json(requirements);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch document requirements', error: error.message });
    }
};

exports.getStatuses = (req, res) => {
    try {
        const rows = db.prepare(
            "SELECT DISTINCT status FROM documents WHERE status IS NOT NULL ORDER BY status ASC"
        ).all();
        const statuses = rows.map(r => r.status);
        res.json(statuses);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch statuses', error: error.message });
    }
};

// ============================================================
// GET /api/documents/student/:studentId — get single student's documents
// ============================================================
exports.getDocumentsByStudent = exports.getDocumentById = (req, res) => {
    const studentId = req.params.studentId || req.params.id;
    try {
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
                return res.status(403).json({ message: "Access denied to fetch this student's documents." });
            }
        }

        const { status } = req.query;
        let statusCondition = "AND d.status = 'Completed'";
        const queryParams = [studentId];
        if (status && status !== 'All Statuses' && status !== 'all' && status !== 'Completed') {
            statusCondition = "AND d.status = ?";
            queryParams.push(status);
        } else {
            statusCondition = "AND d.status = 'Completed'";
        }

        const documents = db.prepare(`
            SELECT d.*, dr.name as requirement_name,
                   s.lrn as student_lrn,
                   s.first_name || ' ' || s.last_name as student_name,
                   TRIM(COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '')) as uploaded_by_name,
                   u.username as uploaded_by_username
            FROM documents d
            LEFT JOIN users u ON d.uploaded_by = u.id
            LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
            LEFT JOIN students s ON d.student_id = s.id
            WHERE d.student_id = ? AND d.deleted_at IS NULL ${statusCondition}
        `).all(...queryParams);

        const mappedDocs = documents.map(d => {
            const rawSize = getDocSize(d);
            const uploaderName = d.uploaded_by_name && d.uploaded_by_name.trim().length > 0
                ? d.uploaded_by_name.trim()
                : (d.uploaded_by_username || (d.uploaded_by ? `User #${d.uploaded_by}` : null));
            return {
                id: d.id,
                studentId: d.student_id,
                requirementId: d.requirement_id,
                fileName: d.file_name,
                documentType: d.document_type,
                status: d.status,
                createdAt: d.created_at,
                studentLrn: d.student_lrn,
                studentName: d.student_name,
                uploadedBy: d.uploaded_by,
                uploadedByName: uploaderName,
                fileSize: rawSize,
                size: rawSize !== null ? formatBytes(rawSize) : 'Unknown',
                filePath: d.file_path,
                requirementName: d.requirement_name
            };
        });

        res.json(mappedDocs);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch documents', error: error.message });
    }
};

exports.updateStatus = (req, res) => {
    const { status } = req.body;
    if (!['Completed', 'Archived'].includes(status)) {
        return res.status(400).json({ message: 'Invalid status. Must be Completed or Archived.' });
    }
    try {
        const doc = db.prepare('SELECT file_name, student_id FROM documents WHERE id = ?').get(req.params.id);
        db.prepare('UPDATE documents SET status = ? WHERE id = ?').run(status, req.params.id);
        if (doc) {
            logActivity(req.user?.id, 'UPDATE', 'document', req.params.id,
                `Changed status of "${doc.file_name}" to ${status}`);
        }
        res.json({ message: 'Document status updated' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to update status', error: error.message });
    }
};

exports.deleteDocument = (req, res) => {
    try {
        const document = db.prepare('SELECT file_name, student_id, file_path, document_type FROM documents WHERE id = ?').get(req.params.id);
        if (!document) return res.status(404).json({ message: 'Document not found' });

        db.transaction(() => {
            db.prepare(`
                INSERT INTO recent_deleted (document_id, student_id, file_name, file_path, document_type, deleted_by)
                VALUES (?, ?, ?, ?, ?, ?)
            `).run(req.params.id, document.student_id, document.file_name, document.file_path, document.document_type, req.user?.id);

            db.prepare("UPDATE documents SET deleted_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?").run(req.params.id);
        })();

        logActivity(req.user?.id, 'DELETE', 'document', req.params.id,
            `Moved document "${document.file_name}" to Recycle Bin`);
        createNotification(null, 'Document Deleted', `Document "${document.file_name}" was moved to Recycle Bin.`, 'document', 'document', req.params.id);
        res.json({ message: 'Document moved to Recycle Bin successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to delete document', error: error.message });
    }
};


// ============================================================
// GET /api/documents/print-queue — get print queue for user
// ============================================================
exports.getPrintQueue = (req, res) => {
    try {
        const userId = req.user.id;
        const queue = db.prepare(`
            SELECT pq.id as queue_id, pq.document_id, pq.added_at,
                   d.file_name, d.file_path, d.document_type, d.status,
                   s.first_name || ' ' || s.last_name as student_name,
                   s.lrn as student_lrn
            FROM print_queue pq
            JOIN documents d ON pq.document_id = d.id
            LEFT JOIN students s ON d.student_id = s.id
            WHERE pq.user_id = ?
            ORDER BY pq.added_at DESC
        `).all(userId);
        res.json(queue);
    } catch (error) {
        console.error('getPrintQueue error:', error);
        res.status(500).json({ message: 'Failed to fetch print queue', error: error.message });
    }
};

exports.getPrintHistory = (req, res) => {
    try {
        const userId = req.user.id;
        const history = db.prepare(`
            SELECT ph.id, ph.document_id, ph.document_name, ph.student_name, ph.printed_at,
                   s.lrn as student_lrn, d.file_name, d.document_type
            FROM printed_document_history ph
            LEFT JOIN students s ON ph.student_id = s.id
            LEFT JOIN documents d ON ph.document_id = d.id
            WHERE ph.user_id = ?
            ORDER BY ph.printed_at DESC
            LIMIT 50
        `).all(userId);
        res.json(history);
    } catch (error) {
        console.error('getPrintHistory error:', error);
        res.status(500).json({ message: 'Failed to fetch print history', error: error.message });
    }
};

exports.clearPrintHistory = (req, res) => {
    try {
        const userId = req.user.id;
        db.prepare('DELETE FROM printed_document_history WHERE user_id = ?').run(userId);
        res.json({ message: 'Print history cleared' });
    } catch (error) {
        console.error('clearPrintHistory error:', error);
        res.status(500).json({ message: 'Failed to clear print history', error: error.message });
    }
};

// ============================================================
// POST /api/documents/print-queue — add document to print queue
// ============================================================
exports.addToPrintQueue = (req, res) => {
    const { documentId } = req.body;
    const userId = req.user.id;

    if (!documentId) return res.status(400).json({ message: 'Document ID is required' });

    try {
        const document = db.prepare('SELECT id, student_id FROM documents WHERE id = ?').get(documentId);
        if (!document) return res.status(404).json({ message: 'Document not found' });

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
            `).get(document.student_id, userId, document.student_id);
            if (!hasAccess) {
                return res.status(403).json({ message: 'Access denied to print this document.' });
            }
        }

        // Check if already in queue for this user
        const existing = db.prepare('SELECT id FROM print_queue WHERE document_id = ? AND user_id = ?').get(documentId, userId);
        if (existing) {
            return res.status(409).json({ message: 'Document already in print queue' });
        }

        const result = db.prepare('INSERT INTO print_queue (document_id, user_id) VALUES (?, ?)').run(documentId, userId);
        res.status(201).json({ id: result.lastInsertRowid, message: 'Added to print queue' });
    } catch (error) {
        console.error('addToPrintQueue error:', error);
        res.status(500).json({ message: 'Failed to add to print queue', error: error.message });
    }
};

// ============================================================
// DELETE /api/documents/print-queue/:queueId — remove from print queue
// ============================================================
exports.removeFromPrintQueue = (req, res) => {
    const { queueId } = req.params;
    const userId = req.user.id;
    try {
        const item = db.prepare('SELECT id FROM print_queue WHERE id = ? AND user_id = ?').get(queueId, userId);
        if (!item) return res.status(404).json({ message: 'Queue item not found' });
        db.prepare('DELETE FROM print_queue WHERE id = ?').run(queueId);
        res.json({ message: 'Removed from print queue' });
    } catch (error) {
        console.error('removeFromPrintQueue error:', error);
        res.status(500).json({ message: 'Failed to remove from print queue', error: error.message });
    }
};

// ============================================================
// DELETE /api/documents/print-queue — clear all from user's queue
// ============================================================
exports.clearPrintQueue = (req, res) => {
    const userId = req.user.id;
    try {
        db.prepare('DELETE FROM print_queue WHERE user_id = ?').run(userId);
        res.json({ message: 'Print queue cleared' });
    } catch (error) {
        console.error('clearPrintQueue error:', error);
        res.status(500).json({ message: 'Failed to clear print queue', error: error.message });
    }
};

// ============================================================
// POST /api/documents/:id/copy — copy a document
// ============================================================
exports.copyDocument = (req, res) => {
    const { id } = req.params;
    try {
        const doc = db.prepare('SELECT * FROM documents WHERE id = ?').get(id);
        if (!doc) return res.status(404).json({ message: 'Document not found' });

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
            `).get(doc.student_id, req.user.id, doc.student_id);
            if (!hasAccess) {
                return res.status(403).json({ message: 'Access denied to copy this document.' });
            }
        }

        const originalPath = doc.file_path;
        if (!fs.existsSync(originalPath)) {
            return res.status(404).json({ message: 'Physical file not found' });
        }

        const ext = path.extname(doc.file_name);
        const baseName = path.basename(doc.file_name, ext);
        const existingNames = db.prepare(
            'SELECT file_name FROM documents WHERE student_id = ? AND deleted_at IS NULL'
        ).all(doc.student_id).map((r) => r.file_name);
        let counter = 1;
        let newFileName = `${baseName} (${counter})${ext}`;
        while (existingNames.includes(newFileName)) {
            counter++;
            newFileName = `${baseName} (${counter})${ext}`;
        }

        const dir = path.dirname(originalPath);
        const newFilePath = path.join(dir, `${Date.now()}-${newFileName.replace(/[^a-zA-Z0-9.-]/g, '_')}`);

        // Copy file on disk
        fs.copyFileSync(originalPath, newFilePath);

        // Insert into DB
        const fileSize = doc.file_size || (fs.existsSync(newFilePath) ? fs.statSync(newFilePath).size : null);
        const result = db.prepare(`
            INSERT INTO documents (student_id, requirement_id, file_name, file_path, document_type, status, uploaded_by, file_size)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `).run(doc.student_id, doc.requirement_id, newFileName, newFilePath, doc.document_type, doc.status, req.user.id, fileSize);

        // Log activity
        const student = db.prepare('SELECT first_name, last_name FROM students WHERE id = ?').get(doc.student_id);
        const studentName = student ? `${student.first_name} ${student.last_name}` : `Student #${doc.student_id}`;
        logActivity(req.user.id, 'CREATE', 'document', result.lastInsertRowid,
            `Copied document "${doc.file_name}" as "${newFileName}" for ${studentName}`);
        createNotification(null, 'Document Copied', `Document "${doc.file_name}" copied as "${newFileName}" for ${studentName}.`, 'document', 'document', result.lastInsertRowid);

        res.status(201).json({ id: result.lastInsertRowid, fileName: newFileName, message: 'Document copied successfully' });
    } catch (error) {
        console.error('Copy Error:', error);
        res.status(500).json({ message: 'Failed to copy document', error: error.message });
    }
};

// ============================================================
// POST /api/documents/:id/convert-to-pdf — convert Excel to PDF
// ============================================================
exports.convertToPdf = async (req, res) => {
    const { id } = req.params;
    try {
        const doc = db.prepare('SELECT * FROM documents WHERE id = ?').get(id);
        if (!doc) return res.status(404).json({ message: 'Document not found' });

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
            `).get(doc.student_id, req.user.id, doc.student_id);
            if (!hasAccess) {
                return res.status(403).json({ message: 'Access denied to convert this document.' });
            }
        }

        const originalPath = doc.file_path;
        if (!fs.existsSync(originalPath)) {
            return res.status(404).json({ message: 'Physical file not found on disk' });
        }

        const ext = path.extname(doc.file_name).toLowerCase();
        const validExcelExts = ['.xlsx', '.xls', '.csv'];
        if (!validExcelExts.includes(ext)) {
            return res.status(400).json({ message: 'Only Excel files (.xlsx, .xls, .csv) can be converted to PDF.' });
        }

        const dir = path.dirname(originalPath);
        const baseName = path.basename(doc.file_name, ext);

        // Perform conversion with headless LibreOffice
        const { pdfPath: tempPdfPath } = await LibreOfficeService.convertToPdf(originalPath, dir);

        // Determine non-colliding new filename with .pdf extension
        const existingNames = db.prepare(
            'SELECT file_name FROM documents WHERE student_id = ? AND deleted_at IS NULL'
        ).all(doc.student_id).map((r) => r.file_name);

        let newFileName = `${baseName}.pdf`;
        let counter = 1;
        while (existingNames.includes(newFileName)) {
            newFileName = `${baseName} (${counter}).pdf`;
            counter++;
        }

        const finalPdfPath = path.join(dir, `${Date.now()}-${newFileName.replace(/[^a-zA-Z0-9.-]/g, '_')}`);
        fs.renameSync(tempPdfPath, finalPdfPath);

        // Insert new PDF document row into database
        const convertedFileSize = fs.existsSync(finalPdfPath) ? fs.statSync(finalPdfPath).size : null;
        const result = db.prepare(`
            INSERT INTO documents (student_id, requirement_id, file_name, file_path, document_type, status, uploaded_by, file_size)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `).run(doc.student_id, doc.requirement_id, newFileName, finalPdfPath, doc.document_type, doc.status, req.user.id, convertedFileSize);

        const newDoc = db.prepare('SELECT * FROM documents WHERE id = ?').get(result.lastInsertRowid);

        // Log activity
        const student = db.prepare('SELECT first_name, last_name FROM students WHERE id = ?').get(doc.student_id);
        const studentName = student ? `${student.first_name} ${student.last_name}` : `Student #${doc.student_id}`;
        logActivity(req.user.id, 'CREATE', 'document', result.lastInsertRowid,
            `Converted Excel document "${doc.file_name}" to PDF "${newFileName}" for ${studentName}`);
        createNotification(null, 'Document Converted', `Document "${doc.file_name}" converted to PDF for ${studentName}.`, 'document', 'document', result.lastInsertRowid);

        res.status(201).json({
            id: result.lastInsertRowid,
            fileName: newFileName,
            document: newDoc,
            message: 'Document converted to PDF successfully',
        });
    } catch (error) {
        console.error('ConvertToPdf Error:', error);
        res.status(500).json({ message: error.message || 'Failed to convert document to PDF' });
    }
};

// ============================================================
// POST /api/documents/bulk-delete — bulk delete documents
// ============================================================
exports.bulkDelete = (req, res) => {
    const { ids } = req.body;
    if (!ids || !Array.isArray(ids) || !ids.length) {
        return res.status(400).json({ message: 'No document IDs provided' });
    }
    try {
        const isTeacher = req.user?.role?.toLowerCase() === 'teacher';
        const teacherId = req.user?.id;
        let deletedCount = 0;

        const getStmt = db.prepare('SELECT file_name, student_id, file_path, document_type FROM documents WHERE id = ?');
        const insertRecentStmt = db.prepare(`
            INSERT INTO recent_deleted (document_id, student_id, file_name, file_path, document_type, deleted_by)
            VALUES (?, ?, ?, ?, ?, ?)
        `);
        const softDeleteStmt = db.prepare('UPDATE documents SET deleted_at = CURRENT_TIMESTAMP WHERE id = ?');

        const transaction = db.transaction(() => {
            for (const id of ids) {
                const doc = getStmt.get(id);
                if (doc) {
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
                        `).get(doc.student_id, teacherId, doc.student_id);
                        if (!hasAccess) continue;
                    }
                    insertRecentStmt.run(id, doc.student_id, doc.file_name, doc.file_path, doc.document_type, req.user?.id);
                    softDeleteStmt.run(id);
                    deletedCount++;
                }
            }
        });

        transaction();

        res.json({ message: `Successfully moved ${deletedCount} documents to recycle bin` });
    } catch (error) {
        console.error('bulkDelete error:', error);
        res.status(500).json({ message: 'Failed to bulk delete documents', error: error.message });
    }
};

// ============================================================
// POST /api/documents/bulk-status — bulk status updates
// ============================================================
exports.bulkStatus = (req, res) => {
    const { ids, status } = req.body;
    if (!ids || !Array.isArray(ids) || !ids.length) {
        return res.status(400).json({ message: 'No document IDs provided' });
    }
    if (!['Completed', 'Archived'].includes(status)) {
        return res.status(400).json({ message: 'Invalid status. Must be Completed or Archived.' });
    }
    try {
        const updatedNames = [];
        const updateStmt = db.prepare('UPDATE documents SET status = ? WHERE id = ?');
        const getStmt = db.prepare('SELECT file_name FROM documents WHERE id = ?');

        const transaction = db.transaction(() => {
            for (const id of ids) {
                const doc = getStmt.get(id);
                if (doc) {
                    updateStmt.run(status, id);
                    updatedNames.push(doc.file_name);
                }
            }
        });

        transaction();

        logActivity(req.user?.id, 'UPDATE', 'document', null,
            `Bulk updated status of ${updatedNames.length} documents to ${status}`);

        res.json({ message: `Successfully updated status of ${updatedNames.length} documents` });
    } catch (error) {
        console.error('bulkStatus error:', error);
        res.status(500).json({ message: 'Failed to bulk update status', error: error.message });
    }
};

// ============================================================
// POST /api/documents/bulk-print — bulk add to print queue
// ============================================================
exports.bulkAddToPrintQueue = (req, res) => {
    const { ids } = req.body;
    const userId = req.user.id;
    if (!ids || !Array.isArray(ids) || !ids.length) {
        return res.status(400).json({ message: 'No document IDs provided' });
    }
    try {
        const isTeacher = req.user?.role?.toLowerCase() === 'teacher';
        let addedCount = 0;

        const checkStmt = db.prepare('SELECT id FROM print_queue WHERE document_id = ? AND user_id = ?');
        const getDocStudentStmt = db.prepare('SELECT student_id FROM documents WHERE id = ?');
        const insertStmt = db.prepare('INSERT INTO print_queue (document_id, user_id) VALUES (?, ?)');

        const transaction = db.transaction(() => {
            for (const id of ids) {
                const existing = checkStmt.get(id, userId);
                if (!existing) {
                    if (isTeacher) {
                        const docStudent = getDocStudentStmt.get(id);
                        if (!docStudent) continue;
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
                        `).get(docStudent.student_id, userId, docStudent.student_id);
                        if (!hasAccess) continue;
                    }
                    insertStmt.run(id, userId);
                    addedCount++;
                }
            }
        });

        transaction();

        res.json({ message: `Successfully added ${addedCount} documents to print list` });
    } catch (error) {
        console.error('bulkAddToPrintQueue error:', error);
        res.status(500).json({ message: 'Failed to bulk add to print queue', error: error.message });
    }
};

// ============================================================
// POST /api/documents/bulk-copy — bulk copy documents
// ============================================================
exports.bulkCopy = (req, res) => {
    const { ids } = req.body;
    const isTeacher = req.user?.role?.toLowerCase() === 'teacher';
    if (!ids || !Array.isArray(ids) || !ids.length) {
        return res.status(400).json({ message: 'No document IDs provided' });
    }
    try {
        let copiedCount = 0;
        const getStmt = db.prepare('SELECT * FROM documents WHERE id = ?');
        const insertStmt = db.prepare(`
            INSERT INTO documents (student_id, requirement_id, file_name, file_path, document_type, status, uploaded_by, file_size)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `);
        const usedNames = new Set();

        for (const id of ids) {
            const doc = getStmt.get(id);
            if (doc) {
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
                    `).get(doc.student_id, req.user.id, doc.student_id);
                    if (!hasAccess) {
                        continue;
                    }
                }
                const originalPath = doc.file_path;
                if (fs.existsSync(originalPath)) {
                    const ext = path.extname(doc.file_name);
                    const baseName = path.basename(doc.file_name, ext);
                    const existingNames = db.prepare(
                        'SELECT file_name FROM documents WHERE student_id = ? AND deleted_at IS NULL'
                    ).all(doc.student_id).map((r) => r.file_name);
                    let counter = 1;
                    let newFileName = `${baseName} (${counter})${ext}`;
                    while (existingNames.includes(newFileName) || usedNames.has(newFileName)) {
                        counter++;
                        newFileName = `${baseName} (${counter})${ext}`;
                    }
                    usedNames.add(newFileName);
                    const dir = path.dirname(originalPath);
                    const newFilePath = path.join(dir, `${Date.now()}-${newFileName.replace(/[^a-zA-Z0-9.-]/g, '_')}`);

                    fs.copyFileSync(originalPath, newFilePath);
                    const copiedFileSize = doc.file_size || (fs.existsSync(newFilePath) ? fs.statSync(newFilePath).size : null);
                    insertStmt.run(doc.student_id, doc.requirement_id, newFileName, newFilePath, doc.document_type, doc.status, req.user.id, copiedFileSize);
                    copiedCount++;
                }
            }
        }

        res.json({ message: `Successfully copied ${copiedCount} documents` });
    } catch (error) {
        console.error('bulkCopy error:', error);
        res.status(500).json({ message: 'Failed to bulk copy documents', error: error.message });
    }
};

// ============================================================
// GET /api/documents/trash — get soft-deleted documents (Recycle Bin)
// ============================================================
exports.getTrashDocuments = (req, res) => {
    try {
        const isTeacher = req.user?.role?.toLowerCase() === 'teacher';
        const teacherId = req.user?.id;

        const teacherJoin = isTeacher 
            ? `JOIN enrollments e ON e.student_id = s.id 
               AND e.id = (
                   SELECT e2.id FROM enrollments e2
                   JOIN academic_years ay_inner ON e2.academic_year_id = ay_inner.id
                   WHERE e2.student_id = s.id
                   ORDER BY ay_inner.year_range DESC, e2.grade_level DESC, e2.id DESC LIMIT 1
               )
               JOIN teacher_sections ts ON e.section_id = ts.section_id AND ts.teacher_id = ?`
            : '';

        const params = isTeacher ? [teacherId] : [];

        const rows = db.prepare(`
            SELECT rd.document_id as id, rd.student_id, rd.file_name, rd.document_type, rd.file_path, rd.deleted_at,
                   s.lrn as student_lrn,
                   s.first_name || ' ' || s.last_name as student_name,
                   d.file_size
            FROM recent_deleted rd
            LEFT JOIN students s ON rd.student_id = s.id
            LEFT JOIN documents d ON rd.document_id = d.id
            ${teacherJoin}
            WHERE rd.document_id IS NOT NULL
            ORDER BY rd.deleted_at DESC
        `).all(...params);

        const mappedDocs = rows.map(d => {
            const deletedTime = new Date(d.deleted_at).getTime();
            const now = Date.now();
            const diffMs = now - deletedTime;
            const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
            const daysRemaining = Math.max(0, 30 - diffDays);
            const rawSize = d.file_size;

            return {
                id: d.id,
                studentId: d.student_id,
                fileName: d.file_name,
                documentType: d.document_type,
                status: 'Completed',
                createdAt: d.deleted_at,
                studentLrn: d.student_lrn,
                studentName: d.student_name,
                deletedAt: d.deleted_at,
                daysRemaining,
                fileSize: rawSize,
                size: rawSize !== null ? formatBytes(rawSize) : 'Unknown',
                filePath: d.file_path
            };
        });

        res.json(mappedDocs);
    } catch (error) {
        console.error('getTrashDocuments error:', error);
        res.status(500).json({ message: 'Failed to fetch trash documents', error: error.message });
    }
};

// ============================================================
// POST /api/documents/:id/restore — restore a soft-deleted document
// ============================================================
exports.restoreDocument = (req, res) => {
    try {
        const doc = db.prepare('SELECT file_name FROM documents WHERE id = ?').get(req.params.id);
        if (!doc) return res.status(404).json({ message: 'Document not found' });

        db.transaction(() => {
            db.prepare("UPDATE documents SET deleted_at = NULL WHERE id = ?").run(req.params.id);
            db.prepare("DELETE FROM recent_deleted WHERE document_id = ?").run(req.params.id);
        })();

        logActivity(req.user?.id, 'UPDATE', 'document', req.params.id,
            `Restored document "${doc.file_name}"`);
        createNotification(null, 'Document Restored', `Document "${doc.file_name}" was restored from Recycle Bin.`, 'document', 'document', req.params.id);

        res.json({ message: 'Document restored successfully' });
    } catch (error) {
        console.error('restoreDocument error:', error);
        res.status(500).json({ message: 'Failed to restore document', error: error.message });
    }
};

// ============================================================
// POST /api/documents/bulk-restore — bulk restore soft-deleted documents
// ============================================================
exports.bulkRestore = (req, res) => {
    const { ids } = req.body;
    if (!ids || !Array.isArray(ids) || !ids.length) {
        return res.status(400).json({ message: 'No document IDs provided' });
    }
    try {
        const restoredNames = [];
        const getStmt = db.prepare('SELECT file_name FROM documents WHERE id = ?');
        const updateStmt = db.prepare("UPDATE documents SET deleted_at = NULL WHERE id = ?");
        const deleteTrashStmt = db.prepare("DELETE FROM recent_deleted WHERE document_id = ?");

        db.transaction(() => {
            for (const id of ids) {
                const doc = getStmt.get(id);
                if (doc) {
                    updateStmt.run(id);
                    deleteTrashStmt.run(id);
                    restoredNames.push(doc.file_name);
                }
            }
        })();

        logActivity(req.user?.id, 'UPDATE', 'document', null,
            `Bulk restored ${restoredNames.length} documents: ${restoredNames.join(', ')}`);

        res.json({ message: `Successfully restored ${restoredNames.length} documents` });
    } catch (error) {
        console.error('bulkRestore error:', error);
        res.status(500).json({ message: 'Failed to bulk restore documents', error: error.message });
    }
};

// ============================================================
// DELETE /api/documents/:id/permanent — permanently delete a document
// ============================================================
exports.permanentDeleteDocument = (req, res) => {
    try {
        const doc = db.prepare('SELECT file_path, file_name FROM documents WHERE id = ?').get(req.params.id);
        if (!doc) return res.status(404).json({ message: 'Document not found' });

        if (fs.existsSync(doc.file_path)) {
            fs.unlinkSync(doc.file_path);
        }

        db.transaction(() => {
            db.prepare('DELETE FROM documents WHERE id = ?').run(req.params.id);
            db.prepare('DELETE FROM recent_deleted WHERE document_id = ?').run(req.params.id);
        })();

        logActivity(req.user?.id, 'DELETE', 'document', req.params.id,
            `Permanently deleted document "${doc.file_name}"`);

        res.json({ message: 'Document permanently deleted' });
    } catch (error) {
        console.error('permanentDeleteDocument error:', error);
        res.status(500).json({ message: 'Failed to permanently delete document', error: error.message });
    }
};

// ============================================================
// POST /api/documents/bulk-permanent-delete — bulk permanently delete documents
// ============================================================
exports.bulkPermanentDelete = (req, res) => {
    const { ids } = req.body;
    if (!ids || !Array.isArray(ids) || !ids.length) {
        return res.status(400).json({ message: 'No document IDs provided' });
    }
    try {
        const deletedNames = [];
        const getStmt = db.prepare('SELECT file_path, file_name FROM documents WHERE id = ?');
        const deleteStmt = db.prepare('DELETE FROM documents WHERE id = ?');
        const deleteTrashStmt = db.prepare('DELETE FROM recent_deleted WHERE document_id = ?');

        db.transaction(() => {
            for (const id of ids) {
                const doc = getStmt.get(id);
                if (doc) {
                    if (fs.existsSync(doc.file_path)) {
                        fs.unlinkSync(doc.file_path);
                    }
                    deleteStmt.run(id);
                    deleteTrashStmt.run(id);
                    deletedNames.push(doc.file_name);
                }
            }
        })();

        logActivity(req.user?.id, 'DELETE', 'document', null,
            `Bulk permanently deleted ${deletedNames.length} documents: ${deletedNames.join(', ')}`);

        res.json({ message: `Successfully permanently deleted ${deletedNames.length} documents` });
    } catch (error) {
        console.error('bulkPermanentDelete error:', error);
        res.status(500).json({ message: 'Failed to bulk permanently delete documents', error: error.message });
    }
};

// ============================================================
// POST /api/documents/print-queue/print — execute print and log history
// ============================================================
exports.executePrintQueue = (req, res) => {
    const userId = req.user.id;
    try {
        const queueItems = db.prepare(`
            SELECT pq.document_id, d.student_id, d.file_name AS document_name,
                   (s.first_name || ' ' || s.last_name) AS student_name
            FROM print_queue pq
            JOIN documents d ON pq.document_id = d.id
            LEFT JOIN students s ON d.student_id = s.id
            WHERE pq.user_id = ?
        `).all(userId);

        if (!queueItems.length) {
            return res.status(400).json({ message: 'Print queue is empty' });
        }

        const insertStmt = db.prepare(`
            INSERT INTO printed_document_history (document_id, student_id, user_id, document_name, student_name)
            VALUES (?, ?, ?, ?, ?)
        `);

        db.transaction(() => {
            for (const item of queueItems) {
                insertStmt.run(
                    item.document_id,
                    item.student_id,
                    userId,
                    item.document_name,
                    item.student_name || 'General'
                );
            }
            db.prepare('DELETE FROM print_queue WHERE user_id = ?').run(userId);
        })();

        logActivity(userId, 'CREATE', 'printed_history', null,
            `Executed batch print for ${queueItems.length} documents and cleared print list`);

        res.json({ message: `Sent ${queueItems.length} documents to printed history log and cleared queue` });
    } catch (error) {
        console.error('executePrintQueue error:', error);
        res.status(500).json({ message: 'Failed to execute print queue', error: error.message });
    }
};

// ============================================================
// Expired Soft Delete Cleanup (30 days)
// ============================================================
const cleanupExpiredDeletedDocuments = () => {
    try {
        const expired = db.prepare(`
            SELECT id, document_id, file_path, file_name 
            FROM recent_deleted 
            WHERE datetime(deleted_at) < datetime('now', '-30 days')
        `).all();

        if (expired.length > 0) {
            console.log(`[Auto Cleanup] Found ${expired.length} expired deleted documents in recent_deleted. Permanently deleting...`);
            const deleteStmt = db.prepare('DELETE FROM documents WHERE id = ?');
            const deleteTrashStmt = db.prepare('DELETE FROM recent_deleted WHERE id = ?');
            
            db.transaction(() => {
                for (const doc of expired) {
                    if (fs.existsSync(doc.file_path)) {
                        fs.unlinkSync(doc.file_path);
                    }
                    deleteStmt.run(doc.document_id);
                    deleteTrashStmt.run(doc.id);
                    console.log(`[Auto Cleanup] Permanently deleted "${doc.file_name}"`);
                }
            })();
        }
    } catch (err) {
        console.error('[Auto Cleanup] Error during document cleanup:', err.message);
    }
};

// Run immediately on backend start, then every 24 hours
cleanupExpiredDeletedDocuments();
setInterval(cleanupExpiredDeletedDocuments, 24 * 60 * 60 * 1000);
