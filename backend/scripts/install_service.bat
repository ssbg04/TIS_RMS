@echo off
:: ============================================================================
:: TIS_RMS Backend - Windows Service Installer (NSSM / SC)
:: ============================================================================
SETLOCAL EnableDelayedExpansion

title TIS RMS Server - Windows Service Setup

:: Check for Administrator Privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This script requires Administrator privileges.
    echo Please right-click install_service.bat and select "Run as administrator".
    echo.
    pause
    exit /b 1
)

SET SERVICE_NAME=TIS_RMSServer
SET DISPLAY_NAME=TIS RMS Server Manager Service
SET DESCRIPTION=Backend Node.js service for TIS RMS (School Record Management System).
SET BACKEND_DIR=%~dp0..
pushd "%BACKEND_DIR%"
SET BACKEND_DIR=%CD%
popd

echo ============================================================================
echo Installing %DISPLAY_NAME% (%SERVICE_NAME%)...
echo Directory: %BACKEND_DIR%
echo ============================================================================

:: Locate Node.js executable
FOR /F "tokens=*" %%g IN ('where node 2^>nul') DO (
    SET NODE_EXE=%%g
    GOTO :NODE_FOUND
)

:NODE_FOUND
IF "%NODE_EXE%"=="" (
    IF EXIST "C:\Program Files\nodejs\node.exe" (
        SET "NODE_EXE=C:\Program Files\nodejs\node.exe"
    ) ELSE (
        echo [ERROR] Node.js not found in PATH or standard location.
        echo Please install Node.js before proceeding.
        pause
        exit /b 1
    )
)

echo [OK] Using Node.js at: %NODE_EXE%

:: Ensure logs directory exists
IF NOT EXIST "%BACKEND_DIR%\logs" mkdir "%BACKEND_DIR%\logs"

:: Check if NSSM executable exists in backend or PATH
SET NSSM_EXE=
IF EXIST "%BACKEND_DIR%\bin\nssm.exe" (
    SET "NSSM_EXE=%BACKEND_DIR%\bin\nssm.exe"
) ELSE (
    FOR /F "tokens=*" %%g IN ('where nssm 2^>nul') DO (
        SET NSSM_EXE=%%g
        GOTO :NSSM_FOUND
    )
)

:NSSM_FOUND

IF NOT "%NSSM_EXE%"=="" (
    echo [OK] Using NSSM binary at: %NSSM_EXE%
    
    :: Stop and remove existing service if present
    "%NSSM_EXE%" stop %SERVICE_NAME% >nul 2>&1
    "%NSSM_EXE%" remove %SERVICE_NAME% confirm >nul 2>&1
    
    :: Install service using NSSM
    "%NSSM_EXE%" install %SERVICE_NAME% "%NODE_EXE%" "\"%BACKEND_DIR%\index.js\""
    "%NSSM_EXE%" set %SERVICE_NAME% AppDirectory "%BACKEND_DIR%"
    "%NSSM_EXE%" set %SERVICE_NAME% DisplayName "%DISPLAY_NAME%"
    "%NSSM_EXE%" set %SERVICE_NAME% Description "%DESCRIPTION%"
    "%NSSM_EXE%" set %SERVICE_NAME% Start SERVICE_AUTO_START
    "%NSSM_EXE%" set %SERVICE_NAME% AppStdout "%BACKEND_DIR%\logs\service_out.log"
    "%NSSM_EXE%" set %SERVICE_NAME% AppStderr "%BACKEND_DIR%\logs\service_err.log"
    "%NSSM_EXE%" set %SERVICE_NAME% AppRotateFiles 1
    "%NSSM_EXE%" set %SERVICE_NAME% AppRotateBytes 10485760
    
    :: Start the service
    echo Starting service %SERVICE_NAME%...
    "%NSSM_EXE%" start %SERVICE_NAME%
    
) ELSE (
    echo [INFO] NSSM executable not found. Using Windows Service Control (sc.exe) fallback...
    
    :: Use PowerShell to create/register Windows Service if nssm is not present
    powershell -Command "New-Service -Name '%SERVICE_NAME%' -BinaryPathName '\"%NODE_EXE%\" \"%BACKEND_DIR%\index.js\"' -DisplayName '%DISPLAY_NAME%' -Description '%DESCRIPTION%' -StartupType Automatic" >nul 2>&1
    
    sc start %SERVICE_NAME% >nul 2>&1
)

echo.
echo ============================================================================
echo [SUCCESS] %SERVICE_NAME% installed successfully!
echo Service status:
sc query %SERVICE_NAME% | findstr /I "STATE"
echo ============================================================================
echo.
pause
