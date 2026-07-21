<!-- This markdown file is for making a installation for client and server -->

# Server

## folder directory
1. root: F:\SumbrerongBato\tis_rms_server\backend
2. copy the root files including node module for fully standalone to F:\SumbrerongBato\tis_rms_server\backend_build
- root folder have dummy data for testing, do not add data in the backend_build folder

## installer
- use inno setup compiler
- add save folder path for the installer, default to F:\SumbrerongBato\tis_rms_server\installers
- add checkbox for auto startup
- run in the background
- save on specific location in local example C:\TIS_RMS
- add logo icon on the installer
- add uninstaller
- separate with data and without data installer

## OS Dependency Setup (Ghostscript & Tesseract OCR)
The backend automatically detects the operating system on startup:

### 1. Windows Systems
- Uses the bundled binaries located inside the backend directory:
  - `backend/ghostscript/bin`
  - `backend/tesseract`
- No manual package installation required.

### 2. Linux / Ubuntu Systems
- Uses system-installed `ghostscript` and `tesseract-ocr`.
- The backend automatically checks for missing binaries on startup and attempts auto-installation if running as root/sudo.
- **One-line manual setup command for Ubuntu**:
  ```bash
  sudo apt-get update && sudo apt-get install -y ghostscript tesseract-ocr tesseract-ocr-eng libtesseract-dev
  ```

---