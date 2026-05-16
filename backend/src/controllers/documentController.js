const db = require('../config/db');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

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
        const allowedMimeTypes = ['application/pdf', 'image/jpeg', 'image/png', 'image/jpg'];
        if (allowedMimeTypes.includes(file.mimetype)) {
            cb(null, true);
        } else {
            cb(new Error('Invalid file format. Only PDF, JPG, and PNG are allowed.'), false);
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
            VALUES (?, ?, ?, ?, ?, 'Pending', ?)
        `).run(studentId, reqId, file.originalname, file.path, documentType, req.user.id);

        res.status(201).json({ id: result.lastInsertRowid, message: 'Document uploaded successfully' });
    } catch (error) {
        console.error('Upload Error:', error);
        res.status(500).json({ message: 'Failed to upload document', error: error.message });
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
        schoolYear = ''
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
            conditions.push(`d.document_type = ?`);
            params.push(documentType.trim());
        }

        if (gradeLevel.trim()) {
            conditions.push(`e.grade_level = ?`);
            params.push(gradeLevel.trim());
        }

        if (schoolYear.trim()) {
            conditions.push(`ay.year_range = ?`);
            params.push(schoolYear.trim());
        }

        const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

        const joins = `
            LEFT JOIN students s ON d.student_id = s.id
            LEFT JOIN enrollments e ON s.id = e.student_id
            LEFT JOIN academic_years ay ON e.academic_year_id = ay.id
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

exports.getDocumentsByStudent = (req, res) => {
    try {
        const documents = db.prepare(`
            SELECT d.*, dr.name as requirement_name 
            FROM documents d
            LEFT JOIN document_requirements dr ON d.requirement_id = dr.id
            WHERE d.student_id = ?
        `).all(req.params.studentId);
        res.json(documents);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch documents', error: error.message });
    }
};

exports.updateStatus = (req, res) => {
    const { status } = req.body;
    if (!['Pending', 'Verified', 'Draft', 'Archived', 'Rejected'].includes(status)) {
        return res.status(400).json({ message: 'Invalid status' });
    }
    try {
        db.prepare('UPDATE documents SET status = ? WHERE id = ?').run(status, req.params.id);
        res.json({ message: 'Document status updated' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to update status', error: error.message });
    }
};

exports.deleteDocument = (req, res) => {
    try {
        const document = db.prepare('SELECT file_path FROM documents WHERE id = ?').get(req.params.id);
        if (!document) return res.status(404).json({ message: 'Document not found' });

        // Delete file from disk
        if (fs.existsSync(document.file_path)) {
            fs.unlinkSync(document.file_path);
        }

        db.prepare('DELETE FROM documents WHERE id = ?').run(req.params.id);
        res.json({ message: 'Document deleted successfully' });
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
