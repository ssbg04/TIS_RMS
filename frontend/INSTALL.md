# TIS RMS Installation & Deployment Guide

This guide provides instructions for installing and running the **TIS RMS** frontend client on Android and Windows devices.

---

## 1. Android Installation (APK)

The Android application is distributed as size-optimized APKs supporting both 32-bit and 64-bit architectures.

### Choosing the Right APK:

| APK File | Architecture | Description |
| :--- | :--- | :--- |
| **`app-arm64-v8a-release.apk`** | **64-bit ARM** | **Recommended** for modern Android smartphones and tablets (Android 7.0+). Smallest download (~27MB). |
| **`app-armeabi-v7a-release.apk`** | **32-bit ARM** | For older smartphones or 32-bit budget Android devices (~25MB). |
| **`app-release.apk`** | **Universal** | Contains all architectures in a single APK (~72MB). Use if unsure of device CPU architecture. |

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
- **.NET Desktop Runtime 6.0/8.0+** (if leveraging Windows background sync tools).

### Running Portable / Standalone:
1. Extract the release folder or zip archive (`TIS_RMS_Client_Windows_x64.zip`).
2. Open the folder and double-click **`tis_rms_server.exe`** (or `tis_rms_frontend.exe`).
3. (Optional) Right-click `tis_rms_server.exe` -> **Send to** -> **Desktop (create shortcut)**.

### Windows Automated Installer:
- Run `TIS_RMS_Client_Setup.exe` from the `installers/` folder for an automated desktop shortcut and start menu entry.

---

## 3. Server Discovery & Network Connectivity

When launching TIS RMS on either platform:
1. **Local LAN Scan**: The app automatically searches your local subnet on port `18484` for ultra-fast local server response.
2. **Tunnel Domain Fallback**: If you are outside the local network, the app automatically switches to the cloud tunnel domain (`https://tis-rms.cc.cd/api`).
3. **Manual Server Selection**: You can tap the server icon at the top of the Login Screen anytime to specify a custom server IP or domain.
