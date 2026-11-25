@echo off
:: ============================================================
::  TIS RMS - NSSM Service Uninstaller
::  Run as Administrator
:: ============================================================

NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Run as Administrator.
    pause
    exit /b 1
)

set BACKEND_DIR=F:\SumbrerongBato\tis_rms_server\backend
set NSSM=%BACKEND_DIR%\bin\nssm.exe
set SERVICE_NAME=TIS.RMS.ServerService

echo.
echo Stopping and removing "%SERVICE_NAME%"...
"%NSSM%" stop "%SERVICE_NAME%" >nul 2>&1
timeout /t 3 /nobreak >nul
"%NSSM%" remove "%SERVICE_NAME%" confirm

echo.
echo [OK] Service removed. Node.js will no longer start on boot.
echo      You can re-install anytime by running install_service.bat
echo.
pause
