const fs = require('fs');
const path = require('path');
const { exec, execSync } = require('child_process');
const util = require('util');
const ExcelJS = require('exceljs');
const execAsync = util.promisify(exec);

/**
 * Service for converting documents (Excel, etc.) to PDF using Headless LibreOffice.
 *
 * Features:
 * 1. Headless LibreOffice CLI: Completely isolated, sandboxed execution with zero GUI
 *    popups, no COM object dependencies, and no risk of desktop/IDE interference.
 * 2. Automatic Long Bond Paper (Folio 8.5" x 13") formatting via ExcelJS preprocessing.
 * 3. Removes static/shrunk zoom percentages so tables fit 100% of printable page width.
 */
class LibreOfficeService {
    /**
     * Finds the path to the LibreOffice / soffice executable.
     * @returns {string|null}
     */
    static getExecutablePath() {
        // 1. Explicit environment variable
        if (process.env.LIBREOFFICE_PATH && fs.existsSync(process.env.LIBREOFFICE_PATH)) {
            return process.env.LIBREOFFICE_PATH;
        }

        const isWindows = process.platform === 'win32';

        if (isWindows) {
            const candidatePaths = [
                path.join(__dirname, '..', '..', '..', 'bin', 'LibreOffice', 'program', 'soffice.com'),
                path.join(__dirname, '..', '..', '..', 'bin', 'LibreOffice', 'program', 'soffice.exe'),
                path.join(__dirname, '..', '..', 'bin', 'LibreOffice', 'program', 'soffice.com'),
                path.join(__dirname, '..', '..', 'bin', 'LibreOffice', 'program', 'soffice.exe'),
                'C:\\Program Files\\LibreOffice\\program\\soffice.com',
                'C:\\Program Files\\LibreOffice\\program\\soffice.exe',
                'C:\\Program Files (x86)\\LibreOffice\\program\\soffice.com',
                'C:\\Program Files (x86)\\LibreOffice\\program\\soffice.exe',
            ];

            for (const candidate of candidatePaths) {
                if (fs.existsSync(candidate)) {
                    return candidate;
                }
            }

            try {
                const output = execSync('where.exe soffice.com soffice.exe', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] });
                const firstLine = output.trim().split(/\r?\n/)[0];
                if (firstLine && fs.existsSync(firstLine)) {
                    return firstLine;
                }
            } catch (_) {}
        } else {
            const candidatePaths = [
                '/usr/bin/soffice',
                '/usr/bin/libreoffice',
                '/usr/local/bin/soffice',
                '/Applications/LibreOffice.app/Contents/MacOS/soffice',
            ];

            for (const candidate of candidatePaths) {
                if (fs.existsSync(candidate)) {
                    return candidate;
                }
            }

            try {
                const output = execSync('which soffice || which libreoffice', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] });
                const firstLine = output.trim().split(/\r?\n/)[0];
                if (firstLine && fs.existsSync(firstLine)) {
                    return firstLine;
                }
            } catch (_) {}
        }

        return null;
    }

    /**
     * Checks if LibreOffice is available on the system.
     * @returns {boolean}
     */
    static isLibreOfficeAvailable() {
        return this.getExecutablePath() !== null;
    }

    /**
     * Checks if the conversion engine is available.
     * @returns {boolean}
     */
    static isAvailable() {
        return this.isLibreOfficeAvailable();
    }

    /**
     * Preprocesses an Excel file using ExcelJS to configure all visible worksheets:
     * 1. Paper size = 14 (Folio 8.5" x 13" / Long Bond Paper standard).
     * 2. Removes any static/shrunken zoom scale (e.g. scale: 36%) so fitToPage takes effect.
     * 3. Sets fitToWidth = 1 so content fills the entire page width.
     * 4. Centers content horizontally with compact 0.25" margins.
     *
     * @param {string} inputFilePath - Source Excel path
     * @param {string} outputDir - Directory to store temporary prepared Excel file
     * @returns {Promise<string>} - Path to prepared Excel file (or original if not applicable)
     */
    static async prepareWorkbookForLongBond(inputFilePath, outputDir) {
        const ext = path.extname(inputFilePath).toLowerCase();
        if (ext !== '.xlsx') {
            return inputFilePath;
        }

        try {
            const wb = new ExcelJS.Workbook();
            await wb.xlsx.readFile(inputFilePath);
            let modified = false;

            wb.eachSheet((ws) => {
                if (ws.state === 'hidden' || ws.state === 'veryHidden') return;
                if (!ws.pageSetup) ws.pageSetup = {};

                // OpenXML standard Folio: 8.5 x 13 in (Philippine Long Bond Paper)
                ws.pageSetup.paperSize = 14;

                // Remove hardcoded/shrunken zoom scale so fitToPage takes effect
                delete ws.pageSetup.scale;

                ws.pageSetup.fitToPage = true;
                ws.pageSetup.fitToWidth = 1;
                if (!ws.pageSetup.fitToHeight) {
                    ws.pageSetup.fitToHeight = 1;
                }

                // Center horizontally
                ws.pageSetup.horizontalCentered = true;

                modified = true;
            });

            if (modified) {
                const prepFileName = `__prep_${Date.now()}_${path.basename(inputFilePath)}`;
                const prepFilePath = path.join(outputDir, prepFileName);
                await wb.xlsx.writeFile(prepFilePath);
                return prepFilePath;
            }
        } catch (err) {
            console.warn('[DocumentConverter] Workbook preprocessing skipped:', err.message);
        }

        return inputFilePath;
    }

    /**
     * Converts an Excel file to PDF using headless LibreOffice.
     * 
     * @param {string} inputFilePath - Absolute path to source Excel file
     * @param {string} outputDir - Directory where converted PDF should be stored
     * @param {string} expectedPdfPath - Expected final PDF destination path
     * @returns {Promise<void>}
     */
    static async convertWithLibreOffice(inputFilePath, outputDir, expectedPdfPath) {
        const sofficeBin = this.getExecutablePath();
        if (!sofficeBin) {
            throw new Error('LibreOffice (soffice) was not found on the server.');
        }

        const normalizedBin = path.normalize(sofficeBin).replace(/\\/g, '/');
        const normalizedOut = path.normalize(outputDir).replace(/\\/g, '/');
        const normalizedIn = path.normalize(inputFilePath).replace(/\\/g, '/');

        const command = `"${normalizedBin}" --headless --invisible --nologo --nodefault --nofirststartwizard --convert-to pdf --outdir "${normalizedOut}" "${normalizedIn}"`;
        console.log(`[DocumentConverter:LibreOffice] Executing: ${command}`);

        const { stdout, stderr } = await execAsync(command, {
            timeout: 60000,
            maxBuffer: 10 * 1024 * 1024,
        });

        if (stdout) console.log(`[DocumentConverter:LibreOffice] stdout: ${stdout.trim()}`);
        if (stderr) console.warn(`[DocumentConverter:LibreOffice] stderr: ${stderr.trim()}`);

        // LibreOffice names output PDF after input file basename
        const generatedPdfName = `${path.basename(inputFilePath, path.extname(inputFilePath))}.pdf`;
        const generatedPdfPath = path.join(outputDir, generatedPdfName);

        if (generatedPdfPath !== expectedPdfPath && fs.existsSync(generatedPdfPath)) {
            if (fs.existsSync(expectedPdfPath)) {
                try { fs.unlinkSync(expectedPdfPath); } catch (_) {}
            }
            fs.renameSync(generatedPdfPath, expectedPdfPath);
        }

        if (!fs.existsSync(expectedPdfPath)) {
            throw new Error(`LibreOffice finished but output PDF was not found at "${expectedPdfPath}".`);
        }
    }

    /**
     * Converts an Excel file (or compatible document) to PDF using Headless LibreOffice.
     * 
     * @param {string} inputFilePath - Absolute path to the source Excel file
     * @param {string} outputDir - Directory where the converted PDF should be stored
     * @returns {Promise<{ pdfPath: string, pdfFileName: string, engine: string }>}
     */
    static async convertToPdf(inputFilePath, outputDir) {
        if (!fs.existsSync(inputFilePath)) {
            throw new Error(`Source file not found at: ${inputFilePath}`);
        }

        if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir, { recursive: true });
        }

        if (!this.isLibreOfficeAvailable()) {
            const isWindows = process.platform === 'win32';
            const helpMessage = isWindows
                ? 'LibreOffice was not found. Please ensure LibreOffice is located in backend/bin/LibreOffice or install it from https://www.libreoffice.org.'
                : 'LibreOffice was not found. Please install LibreOffice using "sudo apt-get install -y libreoffice".';
            throw new Error(helpMessage);
        }

        const ext = path.extname(inputFilePath);
        const baseName = path.basename(inputFilePath, ext);
        const expectedPdfName = `${baseName}.pdf`;
        const expectedPdfPath = path.join(outputDir, expectedPdfName);

        // Remove any stale pre-existing file with the same temporary output name
        if (fs.existsSync(expectedPdfPath)) {
            try {
                fs.unlinkSync(expectedPdfPath);
            } catch (_) {}
        }

        // Preprocess workbook with ExcelJS to set paperSize = 14 (Folio 8.5x13) & fit-to-page
        let preparedPath = inputFilePath;
        let isTempPrepared = false;
        try {
            preparedPath = await this.prepareWorkbookForLongBond(inputFilePath, outputDir);
            isTempPrepared = (preparedPath !== inputFilePath);
        } catch (prepErr) {
            console.warn('[DocumentConverter] Could not pre-process workbook:', prepErr.message);
        }

        try {
            await this.convertWithLibreOffice(preparedPath, outputDir, expectedPdfPath);
            console.log(`[DocumentConverter] Successfully converted "${baseName}" using Headless LibreOffice.`);
            return {
                pdfPath: expectedPdfPath,
                pdfFileName: expectedPdfName,
                engine: 'LIBREOFFICE',
            };
        } finally {
            // Clean up temporary prepared workbook if created
            if (isTempPrepared && fs.existsSync(preparedPath)) {
                try { fs.unlinkSync(preparedPath); } catch (_) {}
            }
        }
    }
}

module.exports = LibreOfficeService;
module.exports.DocumentConverterService = LibreOfficeService;
