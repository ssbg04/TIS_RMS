process.env.TZ = 'Asia/Manila';
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

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

const app = express();
const PORT = process.env.PORT || 18484;

// Initialize Database
initSchema();

// Middleware
app.use(cors());
app.use(express.json());
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

app.get(['/', '/api'], (req, res) => {
    res.set('X-TIS-RMS', 'true');
    res.json({ message: 'TIS RMS API is running' });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT} (0.0.0.0)`);
    // Run auto-graduation check on startup and daily
    try {
        const { checkAndRunAutoGraduation } = require('./src/services/autoGraduationService');
        checkAndRunAutoGraduation(1);
        setInterval(() => checkAndRunAutoGraduation(1), 24 * 60 * 60 * 1000);
    } catch (err) {
        console.error('Failed to start auto-graduation schedule:', err.message);
    }

    // Initialize Auto Cloudflare Tunnel activation when internet is connected
    try {
        const { startAutoTunnel } = require('./src/services/tunnelService');
        startAutoTunnel();
    } catch (err) {
        console.error('Failed to start auto tunnel service:', err.message);
    }
});
