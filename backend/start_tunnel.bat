@echo off
setlocal enabledelayedexpansion

echo =========================================================
echo   TIS RMS Cloudflare Tunnel — EMERGENCY FALLBACK
echo =========================================================
echo.
echo  *** WARNING ***
echo  This script is an EMERGENCY / MANUAL FALLBACK ONLY.
echo  Cloudflare Tunnel is managed automatically by the
echo  Node.js backend (tunnelService.js).
echo.
echo  DO NOT run this script while the TIS RMS backend service
echo  or "node index.js" is running — doing so will create two
echo  cloudflared processes for the same tunnel, which can
echo  cause unpredictable behaviour.
echo.
echo  Only run this script if:
echo    - The backend is fully stopped, AND
echo    - You need to manually verify the tunnel works, OR
echo    - You are debugging cloudflared in isolation.
echo.
echo  The token must be set in backend\.env as:
echo    CLOUDFLARE_TUNNEL_TOKEN=your_token_here
echo.
echo  The token must NOT be hard-coded in this file.
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

:: 2. Load token from .env — NEVER hard-code the token in this file
if not defined CLOUDFLARE_TUNNEL_TOKEN (
    if exist "%ENV_FILE%" (
        for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
            if /i "%%A"=="CLOUDFLARE_TUNNEL_TOKEN" set CLOUDFLARE_TUNNEL_TOKEN=%%B
        )
    )
)

:: Clean token (strip quotes and whitespace)
if defined CLOUDFLARE_TUNNEL_TOKEN (
    set CLOUDFLARE_TUNNEL_TOKEN=%CLOUDFLARE_TUNNEL_TOKEN:"=%
    set CLOUDFLARE_TUNNEL_TOKEN=%CLOUDFLARE_TUNNEL_TOKEN:'=%
)

:: 3. Run tunnel using token from .env (never from this file)
if defined CLOUDFLARE_TUNNEL_TOKEN (
    echo [INFO] Connecting via token loaded from .env...
    echo [INFO] (Token is not displayed for security)
    echo.
    "%CLOUDFLARED_EXE%" tunnel --no-autoupdate run --token !CLOUDFLARE_TUNNEL_TOKEN!
) else (
    echo [ERROR] CLOUDFLARE_TUNNEL_TOKEN was not found in environment or .env file.
    echo Please set CLOUDFLARE_TUNNEL_TOKEN in backend\.env to connect the tunnel.
    echo Never put the real token directly in this .bat file.
)

pause
