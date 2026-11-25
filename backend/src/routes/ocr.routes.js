const express = require('express');
const router = express.Router();
const path = require('path');
const ocrController = require('../controllers/ocr.controller');
const { authenticateToken } = require('../middleware/auth');
const multer = require('multer');
const {
    ALLOWED_OCR_EXTENSIONS,
    ALLOWED_OCR_MIME_TYPES,
} = require('../utils/fileSecurity');

// Setup multer for temp storage with strict extension, MIME, and size limits
const upload = multer({
    dest: 'uploads/temp_ocr/',
    limits: { fileSize: 15 * 1024 * 1024 }, // 15MB max
    fileFilter: (req, file, cb) => {
        const ext = path.extname(file.originalname || '').toLowerCase();
        if (ALLOWED_OCR_MIME_TYPES.has(file.mimetype) && ALLOWED_OCR_EXTENSIONS.has(ext)) {
            cb(null, true);
        } else {
            cb(new Error('Invalid OCR file format. Supported: PDF, JPG, PNG, WEBP, BMP, XLSX, XLS.'), false);
        }
    },
});

router.post(
    '/extract',
    authenticateToken,
    (req, res, next) => {
        upload.single('document')(req, res, (err) => {
            if (err) {
                return res.status(400).json({ message: err.message });
            }
            next();
        });
    },
    ocrController.extractOcrData
);

module.exports = router;