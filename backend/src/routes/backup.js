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

const upload = multer({
    dest: tempUploadsDir,
    limits: { fileSize: 500 * 1024 * 1024 } // allow up to 500 MB backup zip files
});

router.get('/info', authenticateToken, authorizeRoles('admin', 'superadmin'), backupController.getBackupInfo);
router.get('/download', authenticateToken, authorizeRoles('admin', 'superadmin'), backupController.downloadBackup);
router.post('/restore', authenticateToken, authorizeRoles('admin', 'superadmin'), (req, res, next) => {
    console.log('[Backup] Incoming restore request from client, starting file upload...');
    next();
}, upload.single('backup'), backupController.restoreBackup);

module.exports = router;
