# TIS RMS Installation & Deployment Guide

This guide provides instructions for installing, building, and running the **TIS RMS** frontend client on Android and Windows devices.

---

## 1. Android Installation (Universal APK)

The Android application is distributed as a single universal APK supporting both **32-bit (armeabi-v7a)** and **64-bit (arm64-v8a, x86_64)** devices.

### Universal APK:

| APK File | Architecture | Description |
| :--- | :--- | :--- |
| **`TIS_RMS_Android_Universal.apk`** | **Universal (32-bit & 64-bit)** | Single standalone installer compatible with all modern and legacy Android devices (Android 7.0+). |

### Build Command (Flutter):
```bash
cd frontend
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```
*Output APK located in `frontend/build/app/outputs/flutter-apk/app-release.apk`.*

### Installation Steps:
1. Transfer `TIS_RMS_Android_Universal.apk` to your Android device (via USB, local network share, or download).
2. Tap the `.apk` file in your file manager.
3. If prompted, enable **"Install unknown apps"** or **"Allow from this source"** in Android Settings.
4. Tap **Install** and open the app.
5. On startup, the app will automatically scan the local Wi-Fi/LAN for the TIS RMS server (port `18484`) or connect to the secure tunnel domain (`https://tis-rms.cc.cd/api`).

---

## 2. Windows Desktop Installation

The Windows client runs natively on Windows 10 and Windows 11 (64-bit).

### Prerequisites:
- **Microsoft Visual C++ 2015–2022 Redistributable (x64)** (usually pre-installed on Windows).
- **Microsoft .NET Desktop Runtime 6.0/8.0+ (x64)** (automatically detected and installed by setup if missing).

---

### A. Building the Size-Optimized Windows Release

```powershell
cd frontend

# 1. Clean previous build artifacts
flutter clean
flutter pub get

# 2. Compile release build with tree shaking and symbols splitting
flutter build windows --release --obfuscate --split-debug-info=build/windows/symbols
```

*Output binaries will be placed in `build\windows\x64\runner\Release\`.*

---

### B. Compiling the Windows Inno Setup Installer (`TIS_RMS_Client.iss`)

The installer script [`frontend/TIS_RMS_Client.iss`](file:///f:/SumbrerongBato/tis_rms_server/frontend/TIS_RMS_Client.iss) packages the app into an ultra-compact standalone setup file (`TIS_RMS_Client_Setup.exe` ~**16.7 MB**).

#### Features:
- **Small File Size (16.7 MB)**: Uses `lzma2/ultra64` solid 64MB dictionary compression.
- **Automated .NET Runtime Setup**: Automatically checks for and installs Microsoft .NET Desktop Runtime silently if missing.
- **Selectable Destination Path**: Lets the user choose where to install (defaults to `C:\Program Files\TIS RMS Client`).
- **Desktop Shortcut Checkbox**: Optional checkbox on the tasks page to create a desktop shortcut with the official school icon logo.
- **Start Menu & Uninstaller**: Registers a Start Menu program group and includes a clean uninstaller in Windows *Apps & Features* / *Settings*.
- **No Auto-Start**: Does not create startup registry keys or background launch on boot.

#### Compiling with Inno Setup CLI:
```powershell
# Using Inno Setup Command Line Compiler (ISCC)
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" frontend\TIS_RMS_Client.iss
```
*The compiled installer will be saved to `installers/TIS_RMS_Client_Setup.exe`.*

---

### C. Running Portable / Standalone (Without Installing):

1. Navigate to `build\windows\x64\runner\Release\` or extract `TIS_RMS_Client_Windows_x64.zip`.
2. Double-click **`frontend.exe`**.
3. (Optional) Right-click `frontend.exe` -> **Send to** -> **Desktop (create shortcut)**.

---

## 3. Server Discovery & Network Connectivity

When launching TIS RMS on either platform:
1. **Local LAN Scan**: The app automatically searches your local subnet on port `18484` for ultra-fast local server response.
2. **Tunnel Domain Fallback**: If you are outside the local network, the app automatically switches to the cloud tunnel domain (`https://tis-rms.cc.cd/api`).
3. **Manual Server Selection**: You can tap the server icon at the top of the Login Screen anytime to specify a custom server IP or domain.
