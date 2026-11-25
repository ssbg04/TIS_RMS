@echo off
setlocal
cd /d "%~dp0"

echo =========================================================
echo   TIS-RMS Cloudflare Tunnel Security Update
echo =========================================================
echo.

node "scripts\update_tunnel.js" %*

echo.
echo Press any key to exit...
pause >nul

