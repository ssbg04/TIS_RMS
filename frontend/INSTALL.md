# TIS RMS Installation & Deployment Guide

This guide provides instructions for installing, building, and running the **TIS RMS** frontend client on Android and Windows devices.

---

## 1. Android Installation (APK)

The Android application is distributed as size-optimized APKs supporting both 32-bit and 64-bit architectures.

### Choosing the Right APK:

| APK File | Architecture | Description |
| :--- | :--- | :--- |
| **`app-arm64-v8a-release.apk`** | **64-bit ARM** | **Recommended** for modern Android smartphones and tablets (Android 7.0+). Smallest download (~27MB). |
| **`app-armeabi-v7a-release.apk`** | **32-bit ARM** | For older smartphones or 32-bit budget Android devices (~25MB). |
| **`app-release.apk`** | **Universal** | Contains all architectures in a single APK (~72MB). Use if unsure of device CPU architecture. |

### Build Command (Flutter):
```bash
cd frontend
flutter build apk --split-per-abi --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

### Installation Steps:
1. Transfer the selected `.apk` file to your Android phone/tablet (via USB, local network share, or download).
2. Tap the `.apk` file in your file manager.
3. If prompted, enable **"Install unknown apps"** or **"Allow from this source"** in Android Settings.
4. Tap **Install** and open the app.
5. On startup, the app will automatically scan the local Wi-Fi/LAN for the TIS RMS server (port `18484`) or connect to the secure tunnel domain (`https://tis-rms.cc.cd/api`).

---

## 2. Windows Desktop Installation

The Windows client runs natively on Windows 10 and Windows 11 (64-bit).

### Prerequisites:
- **Microsoft Visual C++ 2015–2022 Redistributable (x64)** (usually pre-installed on Windows).
- **Microsoft .NET Desktop Runtime 6.0/8.0+ (x64)** (for background services and desktop interop).

---

### A. Building the Size-Optimized Windows Release

To produce the smallest binary footprint while bundling the necessary engine dependencies:

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

The installer script [`frontend/TIS_RMS_Client.iss`](file:///f:/SumbrerongBato/tis_rms_server/frontend/TIS_RMS_Client.iss) packages the app into a compact standalone setup file (`TIS_RMS_Client_Setup.exe`).

#### Features:
- **Small File Size**: Uses `lzma2/ultra64` solid compression to exclude unneeded development debug `.lib` and `.exp` files.
- **Selectable Destination Path**: Lets the user choose where to install (defaults to `C:\Program Files\TIS RMS Client`).
- **Desktop Shortcut Checkbox**: Optional checkbox on the tasks page to create a desktop shortcut with the official school icon logo.
- **Start Menu & Uninstaller**: Registers a Start Menu program group and includes a clean uninstaller in Windows *Apps & Features* / *Settings*.
- **No Auto-Start**: Does not create unwanted startup registry keys or background launch on boot.
- **Dependency Checks**: Verifies system presence of Visual C++ Redistributable and .NET Desktop Runtime.

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
