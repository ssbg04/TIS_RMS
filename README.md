<div align="center">TIS RMS

Records Management System

A records management system for managing student records, documents, and school forms.

[Landing Page](https://web.tis-rms.cc.cd) · [Documentation](https://docs.tis-rms.cc.cd)

</div>

---

Features

- Document Management — Upload, preview, and organize student documents.
- Student Records — Manage enrollment information, LRN, grade level, strand, and document status.
- OCR Extraction — Extract information from scanned documents using Tesseract OCR.
- Reports — Generate DepEd School Form 10 (SF10) for JHS and SHS.
- Push Notifications — Deliver notifications through Firebase Cloud Messaging.
- Authentication — JWT-based authentication with bcrypt password hashing.
- Windows Service — Run the backend as a persistent Windows service.

---

Architecture

Two components communicating over a local network:

- Frontend — Flutter multi-platform client supporting Windows (desktop) and Android (mobile), built with Riverpod, Dio, Syncfusion PDF Viewer, and Socket.IO.
- Backend — Node.js + Express REST API with a local SQLite database, Tesseract OCR, and Ghostscript bundled for offline document processing.

---

Getting Started

**Prerequisites:** Node.js v18+, Flutter SDK (stable), Visual Studio 2022 with C++ workload.

> Tesseract OCR and Ghostscript are bundled — no extra installation needed.»

Backend

```bash
cd backend
npm install
copy .example.env .env
npm run dev
```

Configure the required environment variables in ".env" before starting the backend.

For production:

```bash
npm start
```

Frontend

```bash
cd frontend
flutter pub get
```

Run on Windows:

```bash
flutter run -d windows
```

Build for Windows:

```bash
flutter build windows
```

Run on Android:

```bash
flutter run -d android
```

Build an Android APK:

```bash
flutter build apk
```

Windows Installer

To build the Windows installer, compile:

```text
frontend/TIS_RMS_Client.iss
```

using Inno Setup.

Alternatively:

```powershell
.\build_release.ps1
```

---

Documentation

For installation guides, system documentation, configuration, and usage instructions, visit the official documentation:

[docs.tis-rms.cc.cd](https://docs.tis-rms.cc.cd)

---

Website

Visit the TIS RMS landing page:

[web.tis-rms.cc.cd](https://web.tis-rms.cc.cd)

---

License

TIS RMS is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).

See the [LICENSE](LICENSE) file for the full license text.

Project

Developed by BSIT3DSB — PLSP.
