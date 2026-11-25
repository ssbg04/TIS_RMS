process.env.TZ = 'Asia/Manila';
const express = require('express');
const http = require('http');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const { initSocket } = require('./src/services/socketService');
require('dotenv').config({ path: path.join(__dirname, '.env'), override: true });
require('dotenv').config({ path: path.join(__dirname, '..', '.env'), override: true });

// ==========================================
// CROSS-PLATFORM SYSTEM SETUP (Ghostscript, Tesseract)
// ==========================================
const { setupSystemEnvironment } = require('./src/config/systemSetup');
setupSystemEnvironment();


const { initSchema } = require('./src/models/schema');
const authRoutes = require('./src/routes/auth');
const studentRoutes = require('./src/routes/students');
const documentRoutes = require('./src/routes/documents');
const dashboardRoutes = require('./src/routes/dashboard');
const setupRoutes = require('./src/routes/setup');
const userRoutes = require('./src/routes/users');
const reportsRoutes = require('./src/routes/reports');
const archivesRoutes = require('./src/routes/archives');
const folderRoutes = require('./src/routes/folders');
const requirementRoutes = require('./src/routes/requirements');
const ocrRoutes = require('./src/routes/ocr.routes.js');
const notificationRoutes = require('./src/routes/notifications');
const backupRoutes = require('./src/routes/backup');
const serverRoutes = require('./src/routes/server.routes');
const settingsRoutes = require('./src/routes/settings');
const templateRoutes = require('./src/routes/templates');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 18484;

// Initialize Socket.IO Real-Time Server
initSocket(server);

// Initialize Database
initSchema();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/students', studentRoutes);
app.use('/api/documents', documentRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/setup', setupRoutes);
app.use('/api/users', userRoutes);
app.use('/api/reports', reportsRoutes);
app.use('/api/archives', archivesRoutes);
app.use('/api/folders', folderRoutes);
app.use('/api/requirements', requirementRoutes);
app.use('/api/ocr', ocrRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/backup', backupRoutes);
app.use('/api/server', serverRoutes);
app.use('/api/settings', settingsRoutes);
app.use('/api/templates', templateRoutes);

// ─── 1. API Domain Routes (/api/*) ─────────────────────────────────────────
// Base API endpoint for client applications and health probes
app.get('/api', (req, res) => {
    res.set('X-TIS-RMS', 'true');
    return res.status(200).json({
        status: 'online',
        service: 'TIS RMS API',
        message: 'TIS RMS API Server is operational',
        version: '1.0.0',
        endpoint: '/api',
        timestamp: new Date().toISOString()
    });
});

// Any unmatched /api/* route returns clean JSON (prevents HTML format error in apps)
app.use('/api', (req, res) => {
    res.set('X-TIS-RMS', 'true');
    return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: `API endpoint '${req.originalUrl}' does not exist.`,
        timestamp: new Date().toISOString()
    });
});

// ─── 2. Web / Browser Domain Routes (/) ────────────────────────────────────
// Browser visitors to root (/) receive the static 404-ish Cloudflare-style page
app.get('/', (req, res) => {
    res.set('X-TIS-RMS', 'true');
    return res.status(200).sendFile(path.join(__dirname, 'index.html'));
});

// All other non-API browser paths also serve the static 404-ish joke page (Express 5 safe catch-all)
app.use((req, res) => {
    res.set('X-TIS-RMS', 'true');
    return res.status(404).sendFile(path.join(__dirname, 'index.html'));
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT} (0.0.0.0)`);
    // Run auto-graduation check on startup and daily
    try {
        const { checkAndRunAutoGraduation } = require('./src/services/autoGraduationService');
        checkAndRunAutoGraduation(1);
        setInterval(() => checkAndRunAutoGraduation(1), 24 * 60 * 60 * 1000);
    } catch (err) {
        console.error('Failed to start auto-graduation schedule:', err.message);
    }

    // Run auto-archiving check on startup, set precision timer, and check every 30 seconds
    try {
        const { checkAndRunAutoArchive, scheduleAutoArchiveTimer } = require('./src/services/autoArchiveService');
        checkAndRunAutoArchive(1);
        scheduleAutoArchiveTimer();
        setInterval(() => checkAndRunAutoArchive(1), 30 * 1000);
    } catch (err) {
        console.error('Failed to start auto-archiving schedule:', err.message);
    }

    // Run teacher document requirement due date reminders check on startup and hourly
    try {
        const { checkAndRunTeacherDueDateReminders } = require('./src/services/teacherReminderService');
        checkAndRunTeacherDueDateReminders();
        setInterval(() => checkAndRunTeacherDueDateReminders(), 60 * 60 * 1000);
    } catch (err) {
        console.error('Failed to start teacher reminder service:', err.message);
    }

    // Initialize Auto Cloudflare Tunnel activation when internet is connected
    try {
        const { startAutoTunnel } = require('./src/services/tunnelService');
        startAutoTunnel();
    } catch (err) {
        console.error('Failed to start auto tunnel service:', err.message);
    }

    // Initialize Password Reset Link Expiration Monitor
    try {
        const { startResetLinkMonitor } = require('./src/services/passwordResetMonitor');
        startResetLinkMonitor();
    } catch (err) {
        console.error('Failed to start password reset link monitor:', err.message);
    }

    // Initialize Firebase Cloud Messaging for Push Notifications
    try {
        require('./src/services/fcmService').init();
    } catch (err) {
        console.error('Failed to initialize FCM service:', err.message);
    }

    // Initialize UDP LAN Discovery Beacon Service (port 18485)
    try {
        const { startDiscoveryBeacon } = require('./src/services/discoveryService');
        startDiscoveryBeacon(PORT);
    } catch (err) {
        console.error('Failed to start UDP discovery beacon service:', err.message);
    }
});
