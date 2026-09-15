const fs = require('fs');
const path = require('path');
const { execFile, exec, execSync } = require('child_process');
const util = require('util');
const execFileAsync = util.promisify(execFile);
const execAsync = util.promisify(exec);

/**
 * In-memory PowerShell script for native Windows Excel COM conversion.
 * Features:
 * 1. Win32Helper: Automatically dismisses modal popups (Activation Wizard, Privacy, Sign In,
 *    etc.) so they never block headless COM conversion. Uses $Global: scope so the
 *    Register-ObjectEvent runspace can actually read the Excel PID.
 * 2. Pre-flight scan: Before Excel's PID is known, scans ALL visible windows for known
 *    dialog titles so startup dialogs are caught immediately.
 * 3. Reads paths from environment variables (EXCEL_INPUT_PATH / EXCEL_OUTPUT_PATH) to
 *    safely handle spaces, brackets, and parentheses (e.g., "(SF9)").
 * 4. Exact PID tracking + Stop-Process to guarantee no zombie EXCEL.EXE stays alive.
 */
const PS_EXCEL_COM_CONVERTER = `
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class Win32Helper {
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder strText, int maxCount);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    public const uint WM_CLOSE = 0x0010;
    public const uint WM_KEYDOWN = 0x0100;

    public static void DismissKnownDialogs(uint targetPid) {
        EnumWindows((hWnd, lParam) => {
            if (!IsWindowVisible(hWnd)) return true;
            uint procId = 0;
            GetWindowThreadProcessId(hWnd, out procId);
            // If targetPid is 0 (not yet known), scan ALL windows; otherwise restrict to Excel
            if (targetPid != 0 && procId != targetPid) return true;
            StringBuilder sb = new StringBuilder(512);
            GetWindowText(hWnd, sb, 512);
            string title = sb.ToString();
            if (title.Contains("Activation") || title.Contains("Privacy") ||
                title.Contains("First Things First") || title.Contains("Sign In") ||
                title.Contains("License") || title.Contains("Office") ||
                title.Contains("Get Started") || title.Contains("New features")) {
                PostMessage(hWnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
                SendMessage(hWnd, WM_KEYDOWN, (IntPtr)0x1B, IntPtr.Zero); // Escape
                SendMessage(hWnd, WM_KEYDOWN, (IntPtr)0x0D, IntPtr.Zero); // Enter
            }
            return true;
        }, IntPtr.Zero);
    }
}
"@ -ErrorAction SilentlyContinue

# IMPORTANT: Use $Global: scope so the Register-ObjectEvent runspace can read the PID.
# A plain $excelPid variable is invisible inside event handler action blocks.
$Global:ExcelComPid = [uint32]0

$timer = [System.Timers.Timer]::new(250)
$timer.AutoReset = $true
Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
    [Win32Helper]::DismissKnownDialogs($Global:ExcelComPid)
} | Out-Null
$timer.Start()

$excel = $null
$wb = $null

try {
    Write-Host "Starting Excel COM..."
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false

    # Capture Excel PID so the timer narrows its window search
    try {
        $hwnd = [IntPtr]$excel.Hwnd
        $outPid = [uint32]0
        [Win32Helper]::GetWindowThreadProcessId($hwnd, [ref]$outPid) | Out-Null
        $Global:ExcelComPid = $outPid
        Write-Host "Excel PID: $($Global:ExcelComPid)"
    } catch {
        Write-Host "Could not resolve Excel PID; scanning all windows."
    }

    # Give the timer several cycles to dismiss any activation/startup dialogs
    Start-Sleep -Milliseconds 600

    Write-Host "Opening workbook: $env:EXCEL_INPUT_PATH"
    $wb = $excel.Workbooks.Open($env:EXCEL_INPUT_PATH, 0, $true)
    Write-Host "Workbook opened: $($wb.Name)"

    Write-Host "Exporting to PDF: $env:EXCEL_OUTPUT_PATH"
    $wb.ExportAsFixedFormat(0, $env:EXCEL_OUTPUT_PATH)
    Write-Host "Export complete!"

    $wb.Close($false)
    $excel.Quit()
    Write-Output "ALL_SUCCESS"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
} finally {
    $timer.Stop()
    $timer.Dispose()
    if ($excel) { try { $excel.Quit() } catch {} }
    $cleanupPid = $Global:ExcelComPid
    if ($cleanupPid -gt 0) {
        Stop-Process -Id $cleanupPid -Force -ErrorAction SilentlyContinue
    }
    $Global:ExcelComPid = [uint32]0
}
`;

/**
 * Service for converting documents (Excel, etc.) to PDF.
 * Uses a prioritized dual-engine approach:
 * 1. Native Microsoft Excel COM Automation (Windows only - fastest, 1:1 identical layout).
 * 2. Headless LibreOffice CLI (Windows/Linux fallback - cross-platform, free).
 */
class LibreOfficeService {
    /**
     * Checks if MS Excel COM automation can potentially be used on this system.
     * @returns {boolean}
     */
    static isExcelComAvailable() {
        return process.platform === 'win32';
    }

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
                path.join(__dirname, '..', '..', '..', 'bin', 'LibreOfficewqe', 'program', 'soffice.com'),
                path.join(__dirname, '..', '..', '..', 'bin', 'LibreOfficewqe', 'program', 'soffice.exe'),
                path.join(__dirname, '..', '..', '..', 'bin', 'soffice.exe'),
                path.join(__dirname, '..', '..', 'bin', 'LibreOffice', 'program', 'soffice.com'),
                path.join(__dirname, '..', '..', 'bin', 'LibreOffice', 'program', 'soffice.exe'),
                path.join(__dirname, '..', '..', 'bin', 'LibreOfficewqe', 'program', 'soffice.com'),
                path.join(__dirname, '..', '..', 'bin', 'LibreOfficewqe', 'program', 'soffice.exe'),
                path.join(__dirname, '..', '..', 'bin', 'soffice.exe'),
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

            // Try where.exe in system PATH
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
     * Checks if any conversion engine (Excel COM or LibreOffice) is available.
     * @returns {boolean}
     */
    static isAvailable() {
        return this.isExcelComAvailable() || this.isLibreOfficeAvailable();
    }

    /**
     * Converts an Excel file to PDF using native Windows Excel COM automation.
     * Paths are passed via environment variables to avoid parentheses/space quoting issues.
     * Auto-dismisses activation wizard modal prompts.
     * 
     * @param {string} inputFilePath - Absolute path to source Excel file
     * @param {string} outputPdfPath - Absolute path where the PDF should be written
     * @returns {Promise<void>}
     */
    static async convertWithExcelCom(inputFilePath, outputPdfPath) {
        console.log(`[DocumentConverter] Attempting conversion via MS Excel COM: "${inputFilePath}"`);

        const args = [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            PS_EXCEL_COM_CONVERTER,
        ];

        const { stdout, stderr } = await execFileAsync('powershell.exe', args, {
            env: {
                ...process.env,
                EXCEL_INPUT_PATH: inputFilePath,
                EXCEL_OUTPUT_PATH: outputPdfPath,
            },
            timeout: 35000,
            maxBuffer: 10 * 1024 * 1024,
        });

        if (stdout) console.log(`[DocumentConverter:ExcelCOM] ${stdout.trim()}`);
        if (stderr) console.warn(`[DocumentConverter:ExcelCOM] ${stderr.trim()}`);

        if (!fs.existsSync(outputPdfPath)) {
            throw new Error(`Excel COM completed but output PDF was not found at "${outputPdfPath}".`);
        }
    }

    /**
     * Converts an Excel file to PDF using headless LibreOffice.
     * Uses exec with quoted forward-slash paths to preserve spaces and avoid Windows backslash issues.
     * 
     * @param {string} inputFilePath - Absolute path to source Excel file
     * @param {string} outputDir - Directory where converted PDF should be stored
     * @param {string} expectedPdfPath - Expected final PDF destination path
     * @returns {Promise<void>}
     */
    static async convertWithLibreOffice(inputFilePath, outputDir, expectedPdfPath) {
        const sofficeBin = this.getExecutablePath();
        if (!sofficeBin) {
            const isWindows = process.platform === 'win32';
            const installHint = isWindows
                ? 'Install Microsoft Excel or LibreOffice (https://www.libreoffice.org).'
                : 'Install LibreOffice ("sudo apt-get install -y libreoffice").';
            throw new Error(`LibreOffice (soffice) was not found on the server. ${installHint}`);
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

        if (!fs.existsSync(expectedPdfPath)) {
            throw new Error(`LibreOffice finished but output PDF was not found at "${expectedPdfPath}".`);
        }
    }

    /**
     * Converts an Excel file (or compatible document) to PDF.
     * Prioritizes MS Excel COM (if available on Windows), then falls back to LibreOffice.
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

        let lastError = null;

        // ── Engine 1: Microsoft Excel COM (Windows only) ────────────────────────
        if (process.platform === 'win32' && this.isExcelComAvailable()) {
            try {
                await this.convertWithExcelCom(inputFilePath, expectedPdfPath);
                console.log(`[DocumentConverter] Successfully converted "${baseName}" using MS Excel COM.`);
                return {
                    pdfPath: expectedPdfPath,
                    pdfFileName: expectedPdfName,
                    engine: 'MS_EXCEL',
                };
            } catch (comErr) {
                lastError = comErr;
                console.warn(`[DocumentConverter] MS Excel COM conversion failed or not activated (${comErr.message}). Falling back to LibreOffice...`);
            }
        }

        // ── Engine 2: Headless LibreOffice Fallback ─────────────────────────────
        if (this.isLibreOfficeAvailable()) {
            try {
                await this.convertWithLibreOffice(inputFilePath, outputDir, expectedPdfPath);
                console.log(`[DocumentConverter] Successfully converted "${baseName}" using LibreOffice.`);
                return {
                    pdfPath: expectedPdfPath,
                    pdfFileName: expectedPdfName,
                    engine: 'LIBREOFFICE',
                };
            } catch (loErr) {
                lastError = loErr;
                console.error('[DocumentConverter] LibreOffice conversion failed:', loErr);
            }
        }

        // ── Neither engine succeeded ───────────────────────────────────────────
        const isWindows = process.platform === 'win32';
        const helpMessage = isWindows
            ? 'No working Excel-to-PDF conversion engine available. Please ensure Microsoft Excel is activated or install LibreOffice from https://www.libreoffice.org.'
            : 'No working Excel-to-PDF conversion engine available. Please install LibreOffice using "sudo apt-get install -y libreoffice".';

        const detail = lastError ? ` Reason: ${lastError.message}` : '';
        throw new Error(`${helpMessage}${detail}`);
    }
}

module.exports = LibreOfficeService;
module.exports.DocumentConverterService = LibreOfficeService;
