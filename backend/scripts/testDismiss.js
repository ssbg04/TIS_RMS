const { execFile } = require('child_process');
const util = require('util');
const execFileAsync = util.promisify(execFile);
const fs = require('fs');

const inFile = "F:\\SumbrerongBato\\tis_rms_server\\backend\\data\\students\\MANALOTO_JOSE_243523345234\\SHS Documents\\SHS - Report Card (SF9).xlsx";
const outFile = "F:\\SumbrerongBato\\tis_rms_server\\backend\\data\\students\\MANALOTO_JOSE_243523345234\\SHS Documents\\test_dismiss_success.pdf";

const psCode = `
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class WinAutoCloser {
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder strText, int maxCount);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    public const uint WM_CLOSE = 0x0010;

    public static void DismissActivationDialog(uint targetPid) {
        EnumWindows((hWnd, lParam) => {
            uint procId = 0;
            GetWindowThreadProcessId(hWnd, out procId);
            if (procId == targetPid) {
                StringBuilder sb = new StringBuilder(256);
                GetWindowText(hWnd, sb, 256);
                string title = sb.ToString();
                if (title.Contains("Activation Wizard") || title.Contains("Privacy") || title.Contains("First Things First")) {
                    PostMessage(hWnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
                }
            }
            return true;
        }, IntPtr.Zero);
    }
}
"@ -ErrorAction SilentlyContinue

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

$excelPid = 0
try {
    $hwnd = [IntPtr]$excel.Hwnd
    $outPid = [uint32]0
    [WinAutoCloser]::GetWindowThreadProcessId($hwnd, [ref]$outPid) | Out-Null
    $excelPid = [uint32]$outPid
} catch {}

# Start a background timer / watcher to auto-close any Activation Wizard
$timer = [System.Timers.Timer]::new(300)
$timer.AutoReset = $true
Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
    if ($excelPid -gt 0) {
        [WinAutoCloser]::DismissActivationDialog($excelPid)
    }
} | Out-Null
$timer.Start()

try {
    Write-Host "Opening workbook..."
    $wb = $excel.Workbooks.Open($env:EXCEL_INPUT_PATH, 0, $true)
    Write-Host "Workbook opened: $($wb.Name)"

    Write-Host "Exporting to PDF..."
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
    if ($excelPid -gt 0) {
        Stop-Process -Id $excelPid -Force -ErrorAction SilentlyContinue
    }
}
`;

async function test() {
    try {
        const { stdout, stderr } = await execFileAsync('powershell.exe', ['-NoProfile', '-Command', psCode], {
            env: { ...process.env, EXCEL_INPUT_PATH: inFile, EXCEL_OUTPUT_PATH: outFile },
            timeout: 25000
        });
        console.log('STDOUT:\n', stdout);
        if (stderr) console.warn('STDERR:\n', stderr);
        console.log('PDF Exists:', fs.existsSync(outFile), 'Size:', fs.existsSync(outFile) ? fs.statSync(outFile).size : 0);
        if (fs.existsSync(outFile)) fs.unlinkSync(outFile);
    } catch (e) {
        console.error('FAIL:\n', e.stdout || e.message);
    }
}

test();
