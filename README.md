# TIS RMS (Records Management System)

A comprehensive, client-server Records Management System designed to streamline document handling, student records management, and automated data extraction.

## 🏗 Architecture Overview

This project is divided into two primary components:

### 1. Frontend (Flutter Windows Application)
A modern, performant desktop application tailored for Windows, built using **Flutter**. 
- **Key Technologies:** Flutter, Riverpod (State Management), Dio (Networking), Syncfusion PDF Viewer.
- **Core Modules:**
  - **Dashboard:** Overview of recent activities and user history.
  - **Document Management:** Upload, preview, and manage student records and documents.
  - **OCR Integration:** Automatically extract data from scanned documents directly into the system.
  - **User & Student Management:** Interface to manage student profiles, teacher records, and administrative settings.
  - **Reports Generation:** Support for standard educational Excel templates (e.g., School Form 10).

### 2. Backend (Node.js REST API)
A robust and lightweight local server providing data persistence and powerful OCR processing capabilities.
- **Key Technologies:** Node.js, Express.js, SQLite (`better-sqlite3`), JWT (Authentication), Multer (File Uploads).
- **Core Features:**
  - **Authentication:** Secure login and session management using `bcrypt` and `jsonwebtoken`.
  - **Local Database:** Utilizes a fast, local SQLite database (`tis_rms.db`) for portability and simple deployment.
  - **OCR & PDF Engine:** Integrates locally bundled **Tesseract OCR** and **Ghostscript** to securely process and extract text from images and PDFs completely offline.
  - **File Handling:** Secure temporary storage and parsing pipeline for incoming files.

## 🚀 Getting Started

### Prerequisites
- Node.js (v18 or higher recommended)
- Flutter SDK (stable channel)
- Visual Studio with C++ workload (for compiling the Windows Flutter app)

### Backend Setup
1. Navigate to the `backend` directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Copy `.example.env` to `.env` and configure your environment variables.
4. Start the server:
   ```bash
   npm start
   ```
   *(For development, you can use `npm run dev` if nodemon is configured)*

### Frontend Setup
1. Navigate to the `frontend` directory:
   ```bash
   cd frontend
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the Windows application:
   ```bash
   flutter run -d windows
   ```
   *(To build the release executable, run `flutter build windows`)*

## 📦 Included Dependencies & Tooling
- **Tesseract & Ghostscript binaries:** The backend repository includes bundled Windows binaries for Tesseract OCR and Ghostscript to guarantee that document processing works out-of-the-box without requiring complex system path configurations.
- **Inno Setup:** Includes an installer script (`TIS_Frontend.iss`) for easily packaging and distributing the compiled Flutter application.
