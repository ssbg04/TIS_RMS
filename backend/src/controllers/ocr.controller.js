const fs = require('fs');
const path = require('path');
const ocrParser = require('../services/ocrParser.js');
const geminiOcrService = require('../services/geminiOcrService.js');
const { verifyFileMagicBytes } = require('../utils/fileSecurity');

exports.extractOcrData = async (req, res) => {
    let generatedImagePath = null;

    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No file provided for OCR.' });
        }

        const ext = path.extname(req.file.originalname || '').toLowerCase();
        if (!verifyFileMagicBytes(req.file.path, ext)) {
            try { fs.unlinkSync(req.file.path); } catch (_) {}
            return res.status(400).json({
                message: 'File content does not match its declared extension. Rejected for security.',
            });
        }

        const docType = req.body.docType; // 'SF9' or 'SF10'
        console.log(`[OCR] Received file: ${req.file.originalname} (Type: ${req.file.mimetype})`);

        const isExcel = ext === '.xlsx' || ext === '.xls';

        // ==========================================
        // 1. PRIMARY: GEMINI VISION AI (Images & PDFs)
        // ==========================================
        if (!isExcel && geminiOcrService.isAvailable()) {
            console.log(`[OCR] Gemini Vision AI is available. Attempting smart form extraction...`);
            try {
                const geminiResult = await geminiOcrService.extractDocument(
                    req.file.path,
                    req.file.originalname,
                    req.file.mimetype,
                    docType
                );

                if (geminiResult.ok && geminiResult.data) {
                    console.log(`[OCR] Gemini Vision AI extraction succeeded using model: ${geminiResult.model}`);
                    if (fs.existsSync(req.file.path)) {
                        try { fs.unlinkSync(req.file.path); } catch (_) {}
                    }

                    return res.json({
                        success: true,
                        provider: 'gemini',
                        model: geminiResult.model,
                        extracted: geminiResult.data,
                        rawText: geminiResult.rawText || ''
                    });
                } else {
                    console.warn(`[OCR] Gemini extraction returned not ok (${geminiResult.error}). Falling back to Tesseract OCR...`);
                }
            } catch (geminiErr) {
                console.warn(`[OCR] Gemini extraction error (${geminiErr.message}). Falling back to Tesseract OCR...`);
            }
        } else {
            console.log(`[OCR] GEMINI_API_KEY not configured. Using local Tesseract OCR engine.`);
        }

        // ==========================================
        // 2. FALLBACK: LOCAL TESSERACT OCR
        // ==========================================
        let text = '';
        try {
            text = await ocrParser.extractTextFromFile(req.file.path, req.file.originalname, req.file.mimetype);
        } catch (extractErr) {
            if (extractErr.message && extractErr.message.includes('ENOENT')) {
                const missingErr = process.platform === 'win32'
                    ? 'Tesseract/Ghostscript OCR is not installed or missing from backend folders.'
                    : 'Tesseract/Ghostscript OCR is missing on Linux. Install via: sudo apt-get install -y tesseract-ocr tesseract-ocr-eng ghostscript';
                return res.status(500).json({ 
                    message: 'Missing OCR Program', 
                    error: missingErr 
                });
            }
            throw extractErr;
        } finally {
            if (fs.existsSync(req.file.path)) {
                try { fs.unlinkSync(req.file.path); } catch (_) {}
            }
        }

        // ==========================================
        // ROUTE TO THE CORRECT PARSER
        // ==========================================
        let extractedData = {};
        
        if (docType === 'SF9') {
            extractedData = ocrParser.parseSF9(text);
        } else if (docType === 'SF10') {
            extractedData = ocrParser.parseSF10(text);
        } else {
            // Fallback if somehow docType is missing
            extractedData = ocrParser.parseSF10(text); 
        }

        res.json({
            success: true,
            provider: isExcel ? 'exceljs' : 'tesseract',
            extracted: extractedData,
            rawText: text
        });

    } catch (error) {
        console.error('------- OCR FATAL ERROR -------');
        console.error(error);
        
        if (req.file && fs.existsSync(req.file.path)) {
            try { fs.unlinkSync(req.file.path); } catch (_) {}
        }
        if (generatedImagePath && fs.existsSync(generatedImagePath)) {
            try { fs.unlinkSync(generatedImagePath); } catch (_) {}
        }

        res.status(500).json({ message: 'Failed to process document OCR', error: error.message });
    }
};
