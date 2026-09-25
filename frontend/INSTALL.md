# TIS RMS Installation & Deployment Guide

This guide provides instructions for installing, building, and running the **TIS RMS** frontend client on Android and Windows devices.

---

## 1. Android Installation (Split & Universal APKs)

The Android application is distributed in architecture-specific split APKs (for smaller download size and faster performance) as well as a universal APK:

### Available APKs:

| APK File | Architecture | Description |
| :--- | :--- | :--- |
| **`TIS_RMS_64_v<version>.apk`** | **64-bit ARM (`arm64-v8a`)** | **Recommended.** Best performance and smallest size (~40% smaller) for modern Android phones and tablets. |
| **`TIS_RMS_32bit_v<version>.apk`** | **32-bit ARM (`armeabi-v7a`)** | Optimized for older or entry-level 32-bit Android devices. |
| **`TIS_RMS_Universal_v<version>.apk`** | **Universal (32-bit & 64-bit)** | Single standalone installer containing all native architectures (runs on all Android 7.0+ devices). |

### Build Commands (Flutter):

#### A. Build Split APKs (Generates 32-bit & 64-bit standalone APKs):
```bash
cd frontend
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols
```
*Outputs located in `frontend/build/app/outputs/flutter-apk/`:*
- `app-arm64-v8a-release.apk` &rarr; **`TIS_RMS_64_v<version>.apk`**
- `app-armeabi-v7a-release.apk` &rarr; **`TIS_RMS_32bit_v<version>.apk`**

#### B. Build Universal APK (Contains all architectures):
```bash
cd frontend
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```
*Output located in `frontend/build/app/outputs/flutter-apk/`:*
- `app-release.apk` &rarr; **`TIS_RMS_Universal_v<version>.apk`**

### Installation Steps:
1. Transfer the matching APK (`TIS_RMS_64_v<version>.apk` for modern devices, `TIS_RMS_32bit_v<version>.apk` for older devices, or `TIS_RMS_Universal_v<version>.apk`) to your Android device (via USB, local network share, or download).
2. Tap the `.apk` file in your file manager.
3. If prompted, enable **"Install unknown apps"** or **"Allow from this source"** in Android Settings.
4. Tap **Install** and open the app.
5. On startup, the app will automatically scan the local Wi-Fi/LAN for the TIS RMS server (port `18484`) or connect to the secure tunnel domain (`https://tis-rms.cc.cd/api`).

---

## 2. Windows Desktop Installation

The Windows client runs natively on Windows 10 and Windows 11 (64-bit).

### Prerequisites:
- **Microsoft Visual C++ 2015–2022 Redistributable (x64)** (Core runtime libraries `vcruntime140_1.dll`, `msvcp140.dll`, etc. are bundled directly with the release binaries; the installer also automatically installs the full redistributable if missing).
- **Microsoft .NET Desktop Runtime 6.0/8.0+ (x64)** (automatically detected and installed silently by setup if missing).

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

The installer script [`frontend/TIS_RMS_Client.iss`](file:///d:/Capstone/TIS_RIS_Server_Manager/TIS_RMS/frontend/TIS_RMS_Client.iss) packages the app into an ultra-compact standalone setup file (`TIS_RMS_Client_Setup_v<version>.exe` ~**16.7 MB**).

#### Features:
- **Small File Size (~17 MB)**: Uses `lzma2/ultra64` solid 64MB dictionary compression.
- **Bundled VC++ Runtime DLLs**: Packages MSVC CRT libraries (`vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll`, etc.) directly into the application folder to prevent missing DLL crashes.
- **Automated VC++ & .NET Runtime Setup**: Checks system registry and automatically installs Microsoft Visual C++ 2015-2022 Redistributable and Microsoft .NET Desktop Runtime silently if missing.
- **Selectable Destination Path**: Lets the user choose where to install (defaults to `C:\Program Files\TIS RMS Client`).
- **Desktop Shortcut Checkbox**: Optional checkbox on the tasks page to create a desktop shortcut with the official school icon logo.
- **Start Menu & Uninstaller**: Registers a Start Menu program group and includes a clean uninstaller in Windows *Apps & Features* / *Settings*.
- **No Auto-Start**: Does not create startup registry keys or background launch on boot.

#### Compiling with Inno Setup CLI:
```powershell
# Using Inno Setup Command Line Compiler (ISCC)
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" frontend\TIS_RMS_Client.iss
```
*The compiled installer will be saved to `installers/TIS_RMS_Client_Setup_v<version>.exe` (e.g., `installers/TIS_RMS_Client_Setup_v1.0.0.exe`).*

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
