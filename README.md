<div align="center">

# TIS RMS

### Records Management System

A records management system for managing student records, documents, and school forms.

</div>

---

## Features

- **Document Management** — Upload, preview, and organize student documents.
- **Student Records** — Manage enrollment information, LRN, grade level, strand, and document status.
- **OCR Extraction** — Extract information from scanned documents using Tesseract OCR.
- **Reports** — Generate DepEd School Form 10 (SF10) for JHS and SHS.
- **Push Notifications** — Deliver notifications through Firebase Cloud Messaging.
- **Authentication** — JWT-based authentication with bcrypt password hashing.
- **Windows Service** — Run the backend as a persistent Windows service.

---

## 🏗️ Architecture

Two components communicating over a local network:

- **Frontend** — Flutter multi-platform client supporting **Windows** (desktop) and **Android** (mobile), built with Riverpod, Dio, Syncfusion PDF Viewer, and Socket.IO
- **Backend** — Node.js + Express REST API with a local SQLite database, Tesseract OCR, and Ghostscript bundled for offline document processing

---

## 🚀 Getting Started

**Prerequisites:** Node.js v18+, Flutter SDK (stable), Visual Studio 2022 with C++ workload.

> Tesseract OCR and Ghostscript are bundled — no extra installation needed.

### Backend
```bash
cd backend
npm install
copy .example.env .env   # configure port, JWT secret, etc.
npm run dev              # or: npm start
```

### Frontend
```bash
cd frontend
flutter pub get

# Windows
flutter run -d windows
flutter build windows

# Android
flutter run -d android
flutter build apk
```

To build a Windows installer, compile `frontend/TIS_RMS_Client.iss` with **Inno Setup**, or run:
```powershell
.\build_release.ps1
```

---

## License

TIS_RMS is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).

See the [LICENSE](LICENSE) file for the full license text.

Developed by **BSIT3DSB** — PLSP.

<div align="center">
  <sub>Built with ❤️ using Flutter &amp; Node.js · TIS Records Management System</sub>
</div>
