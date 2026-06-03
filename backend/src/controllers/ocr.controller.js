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
        
        let imagePathToScan = req.file.path;
        let isPdf = req.file.mimetype === 'application/pdf';

        // ==========================================
        // 1. PDF TO IMAGE CONVERSION (Native Ghostscript)
        // ==========================================
        if (isPdf) {
            console.log('[OCR] PDF detected. Spawning Ghostscript natively to convert to PNG...');
            
            const saveDirectory = path.resolve('./uploads/temp_ocr/');
            if (!fs.existsSync(saveDirectory)) {
                fs.mkdirSync(saveDirectory, { recursive: true });
            }

            const outputPngPath = path.join(saveDirectory, `temp_ocr_${Date.now()}.png`);

            // Execute Ghostscript directly to avoid GraphicsMagick registry issues on Windows
            const gsArgs = [
                '-dQUIET', '-dPARANOIDSAFER', '-dBATCH', '-dNOPAUSE', '-dNOPROMPT',
                '-sDEVICE=png16m', // Output format
                '-dTextAlphaBits=4', '-dGraphicsAlphaBits=4', // Anti-aliasing
                '-r300', // 300 DPI resolution
                '-dFirstPage=1', '-dLastPage=1', // Only convert the first page
                `-sOutputFile=${outputPngPath}`,
                req.file.path // Input PDF file
            ];

            try {
                // Try gswin64c first, if it fails, fallback to gs
                await execFileAsync('gswin64c', gsArgs);
            } catch (err) {
                if (err.code === 'ENOENT') {
                    // Fallback to gs or gswin32c if gswin64c doesn't exist
                    try {
                        await execFileAsync('gs', gsArgs);
                    } catch (fallbackErr) {
                        await execFileAsync('gswin32c', gsArgs);
                    }
                } else {
                    throw err;
                }
            }
            
            console.log('[OCR] Ghostscript successfully generated PNG:', outputPngPath);
            imagePathToScan = outputPngPath;
            generatedImagePath = outputPngPath;
        }

        // ==========================================
        // 2. READ FILE INTO BUFFER
        // ==========================================
        // 3. RUN NATIVE TESSERACT EXECUTABLE
        // ==========================================
        console.log('[OCR] Starting Native Tesseract Engine...');
        
        // Ensure TESSDATA_PREFIX is set to the tesseract folder so it finds eng.traineddata
        const tessEnv = { ...process.env, TESSDATA_PREFIX: path.join(__dirname, '..', '..', 'tesseract', 'tessdata') };
        
        const { stdout } = await execFileAsync('tesseract', [
            imagePathToScan,
            'stdout', // Output to standard output instead of a file
            '-l', 'eng'
        ], { env: tessEnv, maxBuffer: 1024 * 1024 * 10 }); // 10MB buffer just in case
        
        const text = stdout;

        console.log('[OCR] Tesseract scan complete. Processing regex...');

        // Clean up immediately after reading
        if (fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
        if (generatedImagePath && fs.existsSync(generatedImagePath)) fs.unlinkSync(generatedImagePath);

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