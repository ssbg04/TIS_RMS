process.env.TZ = 'Asia/Manila';
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
require('dotenv').config();

// ==========================================
// BUNDLED BINARIES FOR OCR (Ghostscript, Tesseract)
// ==========================================
const gsPath = path.join(__dirname, 'ghostscript', 'bin');
const tessPath = path.join(__dirname, 'tesseract');
process.env.PATH = `${gsPath}${path.delimiter}${tessPath}${path.delimiter}${process.env.PATH}`;


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

app.get('/', (req, res) => {
    res.json({ message: 'TIS RMS API is running' });
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
