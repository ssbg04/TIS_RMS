@echo off
setlocal EnableDelayedExpansion
:: ============================================================
::  TIS RMS - NSSM Service Installer
::  Installs Node.js backend as a Windows Service using NSSM.
::  Also fixes ghost Cloudflared service and firewall rules.
::  Run as Administrator (right-click -> Run as administrator)
:: ============================================================

NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo [ERROR] This script must be run as Administrator.
    echo Right-click the file and choose "Run as administrator"
    pause
    exit /b 1
)

:: ── Config ────────────────────────────────────────────────────
set BACKEND_DIR=F:\SumbrerongBato\tis_rms_server\backend
set NSSM=%BACKEND_DIR%\bin\nssm.exe
set CLOUDFLARED=%BACKEND_DIR%\bin\cloudflared.exe
set SERVICE_NAME=TIS.RMS.ServerService
set LOG_DIR=%BACKEND_DIR%\logs
set NODE_PORT=18484

echo.
echo ============================================================
echo   TIS RMS - NSSM Service Installer
echo ============================================================
echo.

:: ── 0. Verify NSSM exists ────────────────────────────────────
IF NOT EXIST "%NSSM%" (
    echo [ERROR] nssm.exe not found at: %NSSM%
    pause
    exit /b 1
)
echo [OK] NSSM found: %NSSM%

:: ── 1. Find node.exe ─────────────────────────────────────────
echo.
echo [1/7] Locating node.exe...
set NODE_EXE=

:: Check bundled node first
IF EXIST "%BACKEND_DIR%\node.exe"                        set NODE_EXE=%BACKEND_DIR%\node.exe
IF NOT DEFINED NODE_EXE IF EXIST "C:\Program Files\nodejs\node.exe"       set NODE_EXE=C:\Program Files\nodejs\node.exe
IF NOT DEFINED NODE_EXE IF EXIST "C:\Program Files (x86)\nodejs\node.exe" set NODE_EXE=C:\Program Files (x86)\nodejs\node.exe

:: Try PATH lookup
IF NOT DEFINED NODE_EXE (
    for /f "delims=" %%i in ('where node.exe 2^>nul') do (
        IF NOT DEFINED NODE_EXE set NODE_EXE=%%i
    )
)

IF NOT DEFINED NODE_EXE (
    echo [ERROR] node.exe not found. Install Node.js from https://nodejs.org first.
    pause
    exit /b 1
)
echo      [OK] Found: %NODE_EXE%

:: ── 2. Remove ghost Cloudflared Windows Service ──────────────
echo.
echo [2/7] Checking for ghost Cloudflared Windows service...
sc query Cloudflared >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo      Found! Stopping and removing...
    sc stop Cloudflared >nul 2>&1
    timeout /t 3 /nobreak >nul
    sc delete Cloudflared >nul 2>&1
    echo      [OK] Ghost Cloudflared service removed.
) ELSE (
    echo      [OK] No ghost service found.
)

:: ── 3. Stop and remove existing TIS RMS service (clean reinstall) ──
echo.
echo [3/7] Removing existing "%SERVICE_NAME%" service (if any)...
sc query "%SERVICE_NAME%" >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo      Stopping existing service...
    "%NSSM%" stop "%SERVICE_NAME%" >nul 2>&1
    timeout /t 3 /nobreak >nul
    "%NSSM%" remove "%SERVICE_NAME%" confirm >nul 2>&1
    echo      [OK] Old service removed.
) ELSE (
    echo      [OK] No existing service to remove.
)

:: ── 4. Create logs directory ──────────────────────────────────
echo.
echo [4/7] Creating logs directory...
IF NOT EXIST "%LOG_DIR%" mkdir "%LOG_DIR%"
echo      [OK] %LOG_DIR%

:: ── 5. Install service via NSSM ───────────────────────────────
echo.
echo [5/7] Installing "%SERVICE_NAME%" via NSSM...

"%NSSM%" install "%SERVICE_NAME%" "%NODE_EXE%"
"%NSSM%" set "%SERVICE_NAME%" AppDirectory "%BACKEND_DIR%"
"%NSSM%" set "%SERVICE_NAME%" AppParameters "index.js"

:: Logging
"%NSSM%" set "%SERVICE_NAME%" AppStdout "%LOG_DIR%\server.log"
"%NSSM%" set "%SERVICE_NAME%" AppStderr "%LOG_DIR%\server.log"
"%NSSM%" set "%SERVICE_NAME%" AppRotateFiles 1
"%NSSM%" set "%SERVICE_NAME%" AppRotateBytes 5242880

:: Auto-start on boot
"%NSSM%" set "%SERVICE_NAME%" Start SERVICE_AUTO_START

:: Restart on crash: 5s, 10s, 30s
"%NSSM%" set "%SERVICE_NAME%" AppExit Default Restart
"%NSSM%" set "%SERVICE_NAME%" AppRestartDelay 5000

:: Display name and description
"%NSSM%" set "%SERVICE_NAME%" DisplayName "TIS RMS Backend Server"
"%NSSM%" set "%SERVICE_NAME%" Description "TIS Record Management System - Node.js Backend API Server with Cloudflare Tunnel"

:: Shutdown: send Ctrl+C then wait 10s before kill
"%NSSM%" set "%SERVICE_NAME%" AppStopMethodSkip 0
"%NSSM%" set "%SERVICE_NAME%" AppStopMethodConsole 5000
"%NSSM%" set "%SERVICE_NAME%" AppStopMethodWindow 0
"%NSSM%" set "%SERVICE_NAME%" AppStopMethodThreads 5000

echo      [OK] Service installed.

:: ── 6. Configure firewall rules ───────────────────────────────
echo.
echo [6/7] Configuring Windows Firewall...

:: cloudflared.exe - all profiles
netsh advfirewall firewall delete rule name="TIS-RMS-Cloudflared" >nul 2>&1
netsh advfirewall firewall add rule name="TIS-RMS-Cloudflared" dir=in  action=allow program="%CLOUDFLARED%" enable=yes profile=any >nul 2>&1
netsh advfirewall firewall add rule name="TIS-RMS-Cloudflared" dir=out action=allow program="%CLOUDFLARED%" enable=yes profile=any >nul 2>&1

:: Node port - all profiles
netsh advfirewall firewall delete rule name="TIS-RMS-NodeServer-Inbound"  >nul 2>&1
netsh advfirewall firewall delete rule name="TIS-RMS-NodeServer-Outbound" >nul 2>&1
netsh advfirewall firewall add rule name="TIS-RMS-NodeServer-Inbound"  dir=in  action=allow protocol=TCP localport=%NODE_PORT% enable=yes profile=any >nul 2>&1
netsh advfirewall firewall add rule name="TIS-RMS-NodeServer-Outbound" dir=out action=allow protocol=TCP localport=%NODE_PORT% enable=yes profile=any >nul 2>&1

:: URL ACL reservation (allows non-admin binding)
netsh http add urlacl url=http://+:%NODE_PORT%/ user=Everyone >nul 2>&1

echo      [OK] Firewall rules set for all network profiles (Public/Private/Domain).

:: ── 7. Start the service ──────────────────────────────────────
echo.
echo [7/7] Starting service...
"%NSSM%" start "%SERVICE_NAME%"
timeout /t 4 /nobreak >nul

:: Verify
sc query "%SERVICE_NAME%" | findstr /i "RUNNING" >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo      [OK] Service is RUNNING.
) ELSE (
    echo      [WARN] Service may still be starting up. Check status in the Server Manager app.
)

:: ── Done ──────────────────────────────────────────────────────
echo.
echo ============================================================
echo   Installation Complete!
echo.
echo   Service Name : %SERVICE_NAME%
echo   Node.js      : %NODE_EXE%
echo   Backend Dir  : %BACKEND_DIR%
echo   Logs         : %LOG_DIR%\server.log
echo   Port         : %NODE_PORT%
echo   Auto-Start   : Yes (starts on Windows boot)
echo.
echo   The WPF Server Manager can now Start/Stop/Restart the
echo   service using the Service page.
echo.
echo   To uninstall later, run:  uninstall_service.bat
echo ============================================================
echo.
pause
