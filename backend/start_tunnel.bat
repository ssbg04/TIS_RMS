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

echo [INFO] Connecting to Cloudflare Tunnel...
"%~dp0bin\cloudflared.exe" tunnel run --token eyJhIjoiZWRhMWQ4ZTc1MzNjMjBiMDcyNmM0ZGU1OWE5YTMxYzgiLCJ0IjoiZjJhOGYyYmMtMWE1YS00MmNmLWJjZTUtZWMzYzAxNzY4M2IyIiwicyI6Ik9EUXpZMkUyT0RNdE0yVmxNaTAwTjJVMUxXRmlZVFl0TkRKak1HSmpOR0l4WTJReSJ9
pause
