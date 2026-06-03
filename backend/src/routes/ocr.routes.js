const express = require('express');
const router = express.Router();
const ocrController = require('../controllers/ocr.controller');
const { authenticateToken } = require('../middleware/auth');
const multer = require('multer');

// Setup multer for temp storage
const upload = multer({ dest: 'uploads/temp_ocr/' }); 

router.post('/extract', authenticateToken, upload.single('document'), ocrController.extractOcrData);

module.exports = router;