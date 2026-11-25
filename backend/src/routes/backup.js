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

const os = require('os');

function isLocalHostOrServerIP(ip) {
    if (!ip) return false;
    const cleanIp = ip.replace(/^.*:/, ''); // strip ipv6 prefix like ::ffff:
    if (cleanIp === '127.0.0.1' || cleanIp === '::1' || cleanIp === 'localhost') {
        return true;
    }
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const iface of (interfaces[name] || [])) {
            if (iface.address === cleanIp) {
                return true;
            }
        }
    }
    return false;
}

function requireServerHostOnly(req, res, next) {
    const ip = req.ip || req.connection?.remoteAddress || req.socket?.remoteAddress;
    if (isLocalHostOrServerIP(ip)) {
        return next();
    }
    console.warn(`[Backup] Blocked backup/restore attempt from remote IP: ${ip}`);
    return res.status(403).json({
        message: 'Access denied: Backup and Restore operations can only be performed from the TIS RMS server machine.'
    });
}

router.get('/info', authenticateToken, authorizeRoles('admin', 'superadmin'), backupController.getBackupInfo);
router.get('/download', authenticateToken, authorizeRoles('admin', 'superadmin'), requireServerHostOnly, backupController.downloadBackup);
router.post('/restore', authenticateToken, authorizeRoles('admin', 'superadmin'), requireServerHostOnly, (req, res, next) => {
    console.log('[Backup] Incoming restore request from client, starting file upload...');
    next();
}, upload.single('backup'), backupController.restoreBackup);

module.exports = router;
