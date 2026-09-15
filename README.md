<div align="center">

# TIS RMS

### Records Management System

**A full-stack, offline-capable platform for managing student records, documents, and OCR-powered data extraction in Philippine educational institutions.**

<br/>

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-18+-339933?style=for-the-badge&logo=node.js&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Windows](https://img.shields.io/badge/Windows-Desktop-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![Android](https://img.shields.io/badge/Android-Mobile-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Version](https://img.shields.io/github/v/tag/ssbg04/TIS_RMS?style=for-the-badge&label=version&color=4CAF50)

</div>

---

## ✨ Features

- 📂 **Document Management** — Upload, preview, and organize student documents (PDFs & images)
- 🎓 **Student Records** — Track enrollment status, LRN, grade level, strand, and document completion
- 🔍 **OCR Extraction** — Extract data from scanned documents via bundled Tesseract OCR (fully offline)
- 📊 **Reports** — Generate DepEd School Form 10 (SF10) for JHS & SHS using bundled Excel templates
- 🔔 **Push Notifications** — Real-time alerts via Firebase Cloud Messaging
- 🔐 **Authentication** — JWT-based sessions with bcrypt password hashing
- 🛠️ **Windows Service** — Backend can run as a persistent Windows Service via NSSM

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

## 📜 License

Developed by **BSIT3DSB** — PLSP.

<div align="center">
  <sub>Built with ❤️ using Flutter &amp; Node.js · TIS Records Management System</sub>
</div>
