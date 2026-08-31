@echo off
setlocal enabledelayedexpansion

:: NOTE: This script is an emergency fallback runner.
:: Cloudflare Tunnel is primarily managed automatically by Node.js (tunnelService.js).

title TIS RMS Cloudflare Tunnel
echo =========================================================
echo   Starting TIS RMS Cloudflare Tunnel
echo =========================================================
echo.

set BIN_DIR=%~dp0bin
set CLOUDFLARED_EXE=%BIN_DIR%\cloudflared.exe
set ENV_FILE=%~dp0.env

:: 1. Download cloudflared if missing
if not exist "%CLOUDFLARED_EXE%" (
    if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
    echo [INFO] Downloading cloudflared executable...
    curl.exe -L -o "%CLOUDFLARED_EXE%" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
)

if not exist "%CLOUDFLARED_EXE%" (
    echo [ERROR] cloudflared executable not found at "%CLOUDFLARED_EXE%".
    pause
    exit /b 1
)

:: 2. Load token from .env if available
if not defined CLOUDFLARE_TUNNEL_TOKEN (
    if exist "%ENV_FILE%" (
        for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
            if /i "%%A"=="CLOUDFLARE_TUNNEL_TOKEN" set CLOUDFLARE_TUNNEL_TOKEN=%%B
        )
    )
)

:: Clean token
if defined CLOUDFLARE_TUNNEL_TOKEN (
    set CLOUDFLARE_TUNNEL_TOKEN=%CLOUDFLARE_TUNNEL_TOKEN:"=%
    set CLOUDFLARE_TUNNEL_TOKEN=%CLOUDFLARE_TUNNEL_TOKEN:'=%
)

:: 3. Run tunnel using token
if defined CLOUDFLARE_TUNNEL_TOKEN (
    echo [INFO] Connecting to configured Cloudflare Named Tunnel...
    "%CLOUDFLARED_EXE%" tunnel run --token !CLOUDFLARE_TUNNEL_TOKEN!
) else (
    echo [ERROR] CLOUDFLARE_TUNNEL_TOKEN was not found in environment or .env file.
    echo Please set CLOUDFLARE_TUNNEL_TOKEN in .env to connect the tunnel.
)

pause
