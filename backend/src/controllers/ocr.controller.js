const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');
const util = require('util');
const execFileAsync = util.promisify(execFile);
const ocrParser = require('../services/ocrParser.js');

exports.extractOcrData = async (req, res) => {
    let generatedImagePath = null;

    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No file provided for OCR.' });
        }

        const docType = req.body.docType; // 'SF9' or 'SF10'
        console.log(`[OCR] Received file: ${req.file.originalname} (Type: ${req.file.mimetype})`);
        
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
            extracted: extractedData,
            rawText: text
        });

    } catch (error) {
        console.error('------- OCR FATAL ERROR -------');
        console.error(error);
        
        if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
        if (generatedImagePath && fs.existsSync(generatedImagePath)) fs.unlinkSync(generatedImagePath);

        res.status(500).json({ message: 'Failed to process document OCR', error: error.message });
    }
};
