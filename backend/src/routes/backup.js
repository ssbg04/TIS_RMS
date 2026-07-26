const express = require('express');
const router = express.Router();
const backupController = require('../controllers/backupController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');
const multer = require('multer');
const fs = require('fs');
const path = require('path');

const tempUploadsDir = path.resolve('./temp_backup');
if (!fs.existsSync(tempUploadsDir)) {
    fs.mkdirSync(tempUploadsDir, { recursive: true });
}

const maxBackupSizeMB = parseInt(process.env.MAX_BACKUP_SIZE_MB || '2048', 10);
const upload = multer({
    dest: tempUploadsDir,
    limits: { fileSize: maxBackupSizeMB * 1024 * 1024 } // allow up to 2 GB (2048 MB) by default
});

router.get('/info', authenticateToken, authorizeRoles('admin', 'superadmin'), backupController.getBackupInfo);
router.get('/download', authenticateToken, authorizeRoles('admin', 'superadmin'), backupController.downloadBackup);
router.post('/restore', authenticateToken, authorizeRoles('admin', 'superadmin'), (req, res, next) => {
    console.log('[Backup] Incoming restore request from client, starting file upload...');
    next();
}, upload.single('backup'), backupController.restoreBackup);

module.exports = router;
