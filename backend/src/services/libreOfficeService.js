const fs = require('fs');
const path = require('path');
const { execFile, execSync } = require('child_process');
const util = require('util');
const execFileAsync = util.promisify(execFile);

/**
 * Service for converting documents (Excel, etc.) to PDF using Headless LibreOffice.
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
                path.join(__dirname, '..', '..', 'bin', 'LibreOffice', 'program', 'soffice.exe'),
                path.join(__dirname, '..', '..', 'bin', 'soffice.exe'),
                'C:\\Program Files\\LibreOffice\\program\\soffice.exe',
                'C:\\Program Files (x86)\\LibreOffice\\program\\soffice.exe',
            ];

            for (const candidate of candidatePaths) {
                if (fs.existsSync(candidate)) {
                    return candidate;
                }
            }

            // Try where.exe in system PATH
            try {
                const output = execSync('where.exe soffice', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] });
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
    static isAvailable() {
        return this.getExecutablePath() !== null;
    }

    /**
     * Converts an Excel file (or compatible document) to PDF.
     * Preserves all worksheets / tabs, cell formatting, colors, borders, and layouts.
     * 
     * @param {string} inputFilePath - Absolute path to the source Excel file
     * @param {string} outputDir - Directory where the converted PDF should be stored
     * @returns {Promise<{ pdfPath: string, pdfFileName: string }>}
     */
    static async convertToPdf(inputFilePath, outputDir) {
        if (!fs.existsSync(inputFilePath)) {
            throw new Error(`Source file not found at: ${inputFilePath}`);
        }

        const sofficeBin = this.getExecutablePath();
        if (!sofficeBin) {
            const isWindows = process.platform === 'win32';
            const installHint = isWindows
                ? 'Please install LibreOffice from https://www.libreoffice.org or run "winget install TheDocumentFoundation.LibreOffice", or set LIBREOFFICE_PATH in .env.'
                : 'Please install LibreOffice using "sudo apt-get install -y libreoffice" or set LIBREOFFICE_PATH in .env.';
            throw new Error(`LibreOffice (soffice) executable was not found on the server. ${installHint}`);
        }

        if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir, { recursive: true });
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

        // Run headless LibreOffice conversion
        const args = [
            '--headless',
            '--invisible',
            '--nologo',
            '--nodefault',
            '--nofirststartwizard',
            '--convert-to',
            'pdf',
            '--outdir',
            outputDir,
            inputFilePath,
        ];

        console.log(`[LibreOfficeService] Executing conversion: "${sofficeBin}" ${args.join(' ')}`);

        try {
            const { stdout, stderr } = await execFileAsync(sofficeBin, args, {
                timeout: 60000, // 60s timeout
                maxBuffer: 10 * 1024 * 1024,
            });

            if (stdout) console.log(`[LibreOfficeService] stdout: ${stdout.trim()}`);
            if (stderr) console.warn(`[LibreOfficeService] stderr: ${stderr.trim()}`);

            if (!fs.existsSync(expectedPdfPath)) {
                throw new Error(`LibreOffice finished but output PDF was not found at "${expectedPdfPath}". Output: ${stdout || stderr || 'None'}`);
            }

            return {
                pdfPath: expectedPdfPath,
                pdfFileName: expectedPdfName,
            };
        } catch (err) {
            console.error('[LibreOfficeService] Conversion failed:', err);
            throw new Error(`Failed to convert document to PDF: ${err.message}`);
        }
    }
}

module.exports = LibreOfficeService;
