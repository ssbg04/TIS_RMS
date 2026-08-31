@echo off
:: Check for Admin Privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo =========================================================================
    echo   [ATTENTION] Administrator privileges required!
    echo   Please right-click this file and select "Run as administrator".
    echo =========================================================================
    echo.
    pause
    exit /b 1
)

echo =========================================================================
echo   Fixing Cloudflare Tunnel: Removing Conflicting Windows Background Service
echo =========================================================================
echo.

echo [1/3] Stopping existing Cloudflared service...
net stop Cloudflared >nul 2>&1
sc stop Cloudflared >nul 2>&1

echo [2/3] Uninstalling old Cloudflared Windows service...
"%~dp0bin\cloudflared.exe" service uninstall >nul 2>&1
sc delete Cloudflared >nul 2>&1

echo [3/3] Terminating any stale background cloudflared processes...
taskkill /F /IM cloudflared.exe >nul 2>&1

echo.
echo =========================================================================
echo   [SUCCESS] Conflicting service removed!
echo   The TIS RMS server / start_tunnel will now handle the tunnel cleanly
echo   without any 502 Bad Gateway or socket collisions.
echo =========================================================================
echo.
pause
