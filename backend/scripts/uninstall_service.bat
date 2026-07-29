@echo off
:: ============================================================================
:: TIS_RMS Backend - Windows Service Uninstaller
:: ============================================================================
SETLOCAL EnableDelayedExpansion

title TIS RMS Server - Remove Windows Service

:: Check for Administrator Privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This script requires Administrator privileges.
    echo Please right-click uninstall_service.bat and select "Run as administrator".
    echo.
    pause
    exit /b 1
)

SET SERVICE_NAME=TIS_RMSServer
SET BACKEND_DIR=%~dp0..
pushd "%BACKEND_DIR%"
SET BACKEND_DIR=%CD%
popd

echo ============================================================================
echo Uninstalling %SERVICE_NAME%...
echo ============================================================================

:: Check for NSSM
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
    "%NSSM_EXE%" stop %SERVICE_NAME% >nul 2>&1
    "%NSSM_EXE%" remove %SERVICE_NAME% confirm
) ELSE (
    net stop %SERVICE_NAME% >nul 2>&1
    sc delete %SERVICE_NAME%
)

echo.
echo ============================================================================
echo [SUCCESS] Service %SERVICE_NAME% removed.
echo ============================================================================
echo.
pause
