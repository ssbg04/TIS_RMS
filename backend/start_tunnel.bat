@echo off
title TIS RMS Cloudflare Tunnel
echo =========================================================
echo   Starting TIS RMS Cloudflare Tunnel on port 18484
echo =========================================================
echo.

if not exist "%~dp0bin\cloudflared.exe" (
    echo [INFO] Downloading cloudflared executable...
    curl.exe -L -o "%~dp0bin\cloudflared.exe" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
)

echo [INFO] Connecting to Cloudflare global network...
echo [INFO] Look for the 'https://*.trycloudflare.com' URL below:
echo.
"%~dp0bin\cloudflared.exe" tunnel --url http://localhost:18484
pause
