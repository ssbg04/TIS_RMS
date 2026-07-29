@echo off
:: ============================================================================
:: TIS_RMS Backend - Interactive Windows Service Control CLI
:: ============================================================================
SETLOCAL EnableDelayedExpansion

title TIS RMS Server Manager CLI

SET SERVICE_NAME=TIS_RMSServer
SET BACKEND_DIR=%~dp0..
pushd "%BACKEND_DIR%"
SET BACKEND_DIR=%CD%
popd

:: Check for Administrator Privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Running without Administrator privileges.
    echo Some actions (Install, Uninstall, Start, Stop) may fail if user isn't Admin.
    echo.
)

:MENU
cls
echo ============================================================================
echo                     TIS RMS SERVER - WINDOWS SERVICE CONTROL
echo ============================================================================
echo Service Name: %SERVICE_NAME%
echo Backend Path: %BACKEND_DIR%
echo ----------------------------------------------------------------------------
echo Current Status:
sc query %SERVICE_NAME% | findstr /I "STATE"
echo ============================================================================
echo.
echo   [1] Start Service          (net start %SERVICE_NAME%)
echo   [2] Stop Service           (net stop %SERVICE_NAME%)
echo   [3] Restart Service        (nssm restart %SERVICE_NAME%)
echo   [4] Service Status Details (sc query %SERVICE_NAME%)
echo   [5] Install Service        (Run install_service.bat)
echo   [6] Uninstall Service      (Run uninstall_service.bat)
echo   [7] View Service Logs      (Open stdout/stderr log files)
echo   [8] Exit
echo.
SET /P CHOICE="Enter your choice [1-8]: "

IF "%CHOICE%"=="1" GOTO START_SVC
IF "%CHOICE%"=="2" GOTO STOP_SVC
IF "%CHOICE%"=="3" GOTO RESTART_SVC
IF "%CHOICE%"=="4" GOTO STATUS_SVC
IF "%CHOICE%"=="5" GOTO INSTALL_SVC
IF "%CHOICE%"=="6" GOTO UNINSTALL_SVC
IF "%CHOICE%"=="7" GOTO LOGS_SVC
IF "%CHOICE%"=="8" GOTO END

echo Invalid choice. Try again.
timeout /t 2 >nul
GOTO MENU

:START_SVC
echo Starting %SERVICE_NAME%...
net start %SERVICE_NAME%
pause
GOTO MENU

:STOP_SVC
echo Stopping %SERVICE_NAME%...
net stop %SERVICE_NAME%
pause
GOTO MENU

:RESTART_SVC
echo Restarting %SERVICE_NAME%...
net stop %SERVICE_NAME% >nul 2>&1
net start %SERVICE_NAME%
pause
GOTO MENU

:STATUS_SVC
cls
echo ============================================================================
echo Detailed Status for %SERVICE_NAME%:
echo ============================================================================
sc query %SERVICE_NAME%
echo.
pause
GOTO MENU

:INSTALL_SVC
call "%~dp0install_service.bat"
GOTO MENU

:UNINSTALL_SVC
call "%~dp0uninstall_service.bat"
GOTO MENU

:LOGS_SVC
cls
echo ============================================================================
echo Service Log Files:
echo ============================================================================
IF EXIST "%BACKEND_DIR%\logs\service_out.log" (
    echo Opening stdout log: %BACKEND_DIR%\logs\service_out.log
    start "" notepad "%BACKEND_DIR%\logs\service_out.log"
) ELSE (
    echo [INFO] Stdout log not created yet.
)

IF EXIST "%BACKEND_DIR%\logs\service_err.log" (
    echo Opening stderr log: %BACKEND_DIR%\logs\service_err.log
    start "" notepad "%BACKEND_DIR%\logs\service_err.log"
) ELSE (
    echo [INFO] Stderr log not created yet.
)
pause
GOTO MENU

:END
exit /b 0
