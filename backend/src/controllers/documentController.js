const db = require('../config/db');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { createNotification } = require('./notificationController');

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


const STUDENT_DIR_ROOT = process.env.STUDENT_DIR_ROOT
    ? path.resolve(process.env.STUDENT_DIR_ROOT)
    : path.resolve(__dirname, '../../../data/students');

const sanitizeFolderName = (str) =>
    (str || '').replace(/[<>:"/\\|?*\x00-\x1F]/g, '').trim();

// Configure Multer
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        // We expect studentId in req.body
        const { studentId, documentType } = req.body;

        let uploadPath = process.env.UPLOAD_PATH ? path.resolve(process.env.UPLOAD_PATH) : path.resolve(__dirname, '../../../data/uploads');

        if (studentId) {
            try {
                const student = db.prepare('SELECT lrn, first_name, last_name FROM students WHERE id = ?').get(studentId);
                if (student) {
                    const folderName = `${sanitizeFolderName(student.last_name)}_${sanitizeFolderName(student.first_name)}_${student.lrn}`;
                    uploadPath = path.join(STUDENT_DIR_ROOT, folderName);

                    if (documentType) {
                        uploadPath = path.join(uploadPath, sanitizeFolderName(documentType));
                    }
                }
            } catch (err) {
                console.error('Error fetching student for upload path:', err);
            }
        }

        if (!fs.existsSync(uploadPath)) {
            fs.mkdirSync(uploadPath, { recursive: true });
        }
        cb(null, uploadPath);
    },
    filename: (req, file, cb) => {
        cb(null, `${Date.now()}-${file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_')}`);
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

    try {
        const reqId = requirementId && requirementId !== 'null' ? requirementId : null;

        const result = db.prepare(`
            INSERT INTO documents (student_id, requirement_id, file_name, file_path, document_type, status, uploaded_by)
            VALUES (?, ?, ?, ?, ?, 'Completed', ?)
        `).run(studentId, reqId, file.originalname, file.path, documentType, req.user.id);

        // Log activity
        const student = db.prepare('SELECT first_name, last_name FROM students WHERE id = ?').get(studentId);
        const studentName = student ? `${student.first_name} ${student.last_name}` : `Student #${studentId}`;
        logActivity(req.user.id, 'CREATE', 'document', result.lastInsertRowid,
            `Uploaded "${file.originalname}" (${documentType}) for ${studentName}`);

        createNotification(null, 'Document Uploaded', `Document "${file.originalname}" (${documentType}) has been uploaded for ${studentName}.`, 'document');

        res.status(201).json({ id: result.lastInsertRowid, message: 'Document uploaded successfully' });
    } catch (error) {
        console.error('Upload Error:', error);
        res.status(500).json({ message: 'Failed to upload document', error: error.message });
    }
};


exports.viewDocument = (req, res) => {
    try {
        const doc = db.prepare('SELECT file_path, file_name FROM documents WHERE id = ?').get(req.params.id);
        if (!doc) return res.status(404).json({ message: 'Document not found' });

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
            const like = `%${search.trim()}%`;
            conditions.push(`(s.lrn LIKE ? OR s.first_name LIKE ? OR s.last_name LIKE ? OR d.file_name LIKE ?)`);
            params.push(like, like, like, like);
        }

        if (status.trim() && status !== 'All Statuses') {
            conditions.push(`d.status = ?`);
            params.push(status.trim());
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

        const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

        const joins = `
            LEFT JOIN students s ON d.student_id = s.id
            LEFT JOIN enrollments e ON e.student_id = s.id 
                AND e.id = (SELECT id FROM enrollments WHERE student_id = s.id ORDER BY grade_level DESC, id DESC LIMIT 1)
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
                d.id, d.student_id, d.file_name, d.document_type, d.status, d.created_at, d.file_path,
                s.lrn as student_lrn,
                s.first_name || ' ' || s.last_name as student_name
            FROM documents d
            ${joins}
            ${whereClause}
            ORDER BY d.created_at DESC
            LIMIT ? OFFSET ?
        `;

        const documents = db.prepare(fetchSql).all([...params, limitNum, offset]);

        const mappedDocs = documents.map(d => ({
            id: d.id,
            studentId: d.student_id,
            fileName: d.file_name,
            documentType: d.document_type,
            status: d.status,
            createdAt: d.created_at,
            studentLrn: d.student_lrn,
            studentName: d.student_name,
            size: 'Unknown', // Not storing size in DB right now
            filePath: d.file_path
        }));

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

exports.getDocumentsByStudent = (req, res) => {
    try {
        const documents = db.prepare(`
            SELECT d.*, dr.name as requirement_name,
                   s.lrn as student_lrn,
                   s.first_name || ' ' || s.last_name as student_name
            FROM documents d
            LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
            LEFT JOIN students s ON d.student_id = s.id
            WHERE d.student_id = ? AND d.deleted_at IS NULL
        `).all(req.params.studentId);

        const mappedDocs = documents.map(d => ({
            id: d.id,
            studentId: d.student_id,
            fileName: d.file_name,
            documentType: d.document_type,
            status: d.status,
            createdAt: d.created_at,
            studentLrn: d.student_lrn,
            studentName: d.student_name,
            size: 'Unknown',
            filePath: d.file_path,
            requirementName: d.requirement_name
        }));

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

// ============================================================
// POST /api/documents/print-queue — add document to print queue
// ============================================================
exports.addToPrintQueue = (req, res) => {
    const { documentId } = req.body;
    const userId = req.user.id;

    if (!documentId) return res.status(400).json({ message: 'Document ID is required' });

    try {
        const document = db.prepare('SELECT id FROM documents WHERE id = ?').get(documentId);
        if (!document) return res.status(404).json({ message: 'Document not found' });

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

        const originalPath = doc.file_path;
        if (!fs.existsSync(originalPath)) {
            return res.status(404).json({ message: 'Physical file not found' });
        }

        const ext = path.extname(doc.file_name);
        const baseName = path.basename(doc.file_name, ext);
        const newFileName = `${baseName} - Copy${ext}`;

        const dir = path.dirname(originalPath);
        const newFilePath = path.join(dir, `${Date.now()}-${newFileName.replace(/[^a-zA-Z0-9.-]/g, '_')}`);

        // Copy file on disk
        fs.copyFileSync(originalPath, newFilePath);

        // Insert into DB
        const result = db.prepare(`
            INSERT INTO documents (student_id, requirement_id, file_name, file_path, document_type, status, uploaded_by)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `).run(doc.student_id, doc.requirement_id, newFileName, newFilePath, doc.document_type, doc.status, req.user.id);

        // Log activity
        const student = db.prepare('SELECT first_name, last_name FROM students WHERE id = ?').get(doc.student_id);
        const studentName = student ? `${student.first_name} ${student.last_name}` : `Student #${doc.student_id}`;
        logActivity(req.user.id, 'CREATE', 'document', result.lastInsertRowid,
            `Copied document "${doc.file_name}" as "${newFileName}" for ${studentName}`);

        res.status(201).json({ id: result.lastInsertRowid, fileName: newFileName, message: 'Document copied successfully' });
    } catch (error) {
        console.error('Copy Error:', error);
        res.status(500).json({ message: 'Failed to copy document', error: error.message });
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
        const deletedNames = [];
        const getStmt = db.prepare('SELECT file_name, student_id, file_path, document_type FROM documents WHERE id = ?');
        const softDeleteStmt = db.prepare("UPDATE documents SET deleted_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?");
        const insertTrashStmt = db.prepare(`
            INSERT INTO recent_deleted (document_id, student_id, file_name, file_path, document_type, deleted_by)
            VALUES (?, ?, ?, ?, ?, ?)
        `);

        const transaction = db.transaction(() => {
            for (const id of ids) {
                const doc = getStmt.get(id);
                if (doc) {
                    insertTrashStmt.run(id, doc.student_id, doc.file_name, doc.file_path, doc.document_type, req.user?.id);
                    softDeleteStmt.run(id);
                    deletedNames.push(doc.file_name);
                }
            }
        });

        transaction();

        logActivity(req.user?.id, 'DELETE', 'document', null,
            `Moved ${deletedNames.length} documents to Recycle Bin: ${deletedNames.join(', ')}`);

        res.json({ message: `Successfully moved ${deletedNames.length} documents to Recycle Bin` });
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
        let addedCount = 0;
        const checkStmt = db.prepare('SELECT id FROM print_queue WHERE document_id = ? AND user_id = ?');
        const insertStmt = db.prepare('INSERT INTO print_queue (document_id, user_id) VALUES (?, ?)');

        const transaction = db.transaction(() => {
            for (const id of ids) {
                const existing = checkStmt.get(id, userId);
                if (!existing) {
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
    if (!ids || !Array.isArray(ids) || !ids.length) {
        return res.status(400).json({ message: 'No document IDs provided' });
    }
    try {
        let copiedCount = 0;
        const getStmt = db.prepare('SELECT * FROM documents WHERE id = ?');
        const insertStmt = db.prepare(`
            INSERT INTO documents (student_id, requirement_id, file_name, file_path, document_type, status, uploaded_by)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `);

        for (const id of ids) {
            const doc = getStmt.get(id);
            if (doc) {
                const originalPath = doc.file_path;
                if (fs.existsSync(originalPath)) {
                    const ext = path.extname(doc.file_name);
                    const baseName = path.basename(doc.file_name, ext);
                    const newFileName = `${baseName} - Copy${ext}`;
                    const dir = path.dirname(originalPath);
                    const newFilePath = path.join(dir, `${Date.now()}-${newFileName.replace(/[^a-zA-Z0-9.-]/g, '_')}`);

                    fs.copyFileSync(originalPath, newFilePath);
                    insertStmt.run(doc.student_id, doc.requirement_id, newFileName, newFilePath, doc.document_type, doc.status, req.user.id);
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
        const rows = db.prepare(`
            SELECT rd.document_id as id, rd.student_id, rd.file_name, rd.document_type, rd.file_path, rd.deleted_at,
                   s.lrn as student_lrn,
                   s.first_name || ' ' || s.last_name as student_name
            FROM recent_deleted rd
            LEFT JOIN students s ON rd.student_id = s.id
            WHERE rd.document_id IS NOT NULL
            ORDER BY rd.deleted_at DESC
        `).all();

        const mappedDocs = rows.map(d => {
            const deletedTime = new Date(d.deleted_at).getTime();
            const now = Date.now();
            const diffMs = now - deletedTime;
            const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
            const daysRemaining = Math.max(0, 30 - diffDays);

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
                size: 'Unknown',
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
