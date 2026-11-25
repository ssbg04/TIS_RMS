param (
    [Parameter(Mandatory=$true)]
    [string]$InputPath,

    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

if (-not ([System.Management.Automation.PSTypeName]'Win32ExcelHelper').Type) {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32ExcelHelper {
        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    }
"@ -ErrorAction SilentlyContinue
}

$excel = $null
$wb = $null
$excelPid = 0

try {
    $resolvedInput = [System.IO.Path]::GetFullPath($InputPath)
    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)

    $outputDir = [System.IO.Path]::GetDirectoryName($resolvedOutput)
    if (-not (Test-Path -LiteralPath $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    if (Test-Path -LiteralPath $resolvedOutput) {
        Remove-Item -LiteralPath $resolvedOutput -Force
    }

    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $excel.ScreenUpdating = $false

    # Capture Excel Process ID for 100% clean shutdown
    try {
        $hwnd = [IntPtr]$excel.Hwnd
        $outPid = [uint32]0
        [Win32ExcelHelper]::GetWindowThreadProcessId($hwnd, [ref]$outPid) | Out-Null
        $excelPid = [int]$outPid
    } catch {}

    # Open workbook read-only
    $wb = $excel.Workbooks.Open($resolvedInput, 0, $true)

    # 0 = xlTypePDF
    $wb.ExportAsFixedFormat(0, $resolvedOutput)

    # Allow background spooler to finish writing PDF
    $closed = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 150
        try {
            $wb.Close($false)
            $closed = $true
            break
        } catch {}
    }
    if (-not $closed) {
        try { $wb.Close($false) } catch {}
    }
    try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wb) | Out-Null } catch {}
    $wb = $null

    try { $excel.Quit() } catch {}
    try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null } catch {}
    $excel = $null

    if (-not (Test-Path -LiteralPath $resolvedOutput)) {
        throw "Export completed but output PDF was not found at: $resolvedOutput"
    }

    Write-Output "SUCCESS: $resolvedOutput"
} catch {
    Write-Error $_.Exception.Message
    exit 1
} finally {
    if ($wb -ne $null) {
        try { $wb.Close($false) } catch {}
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wb) | Out-Null } catch {}
    }
    if ($excel -ne $null) {
        try { $excel.Quit() } catch {}
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null } catch {}
    }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    # Guarantee process terminates
    if ($excelPid -gt 0) {
        Start-Sleep -Milliseconds 200
        Stop-Process -Id $excelPid -Force -ErrorAction SilentlyContinue
    }
}
