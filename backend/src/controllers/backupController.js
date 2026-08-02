const fs = require('fs');
const path = require('path');
const db = require('../config/db'); // Needed to close the database on restore

const INFO_FILE = path.resolve('./data/backup_info.json');
const LOGS_FILE = path.resolve('./data/backup_logs.txt');

function logActivity(action) {
    const timestamp = new Date().toISOString();
    
    // Update JSON info
    let info = {};
    if (fs.existsSync(INFO_FILE)) {
        try { info = JSON.parse(fs.readFileSync(INFO_FILE, 'utf8')); } catch(e) {}
    }
    if (action === 'backup') info.lastBackup = timestamp;
    if (action === 'restore') info.lastRestore = timestamp;
    fs.writeFileSync(INFO_FILE, JSON.stringify(info, null, 2));

    // Append to log text
    const logLine = `[${timestamp}] ${action.toUpperCase()} completed successfully.\n`;
    fs.appendFileSync(LOGS_FILE, logLine);
}

// Safely remove a directory on Windows (retries on EBUSY/EPERM, catches if still locked by Defender/indexing)
function safeRemoveDirSync(dirPath) {
    if (!dirPath || !fs.existsSync(dirPath)) return;
    try {
        fs.rmSync(dirPath, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
    } catch (e) {
        console.warn(`[Backup] Notice: Could not remove directory ${dirPath} immediately (${e.code || e.message}). It will be cleaned up later.`);
    }
}

// Safely remove a file on Windows (retries or catches if locked)
function safeRemoveFileSync(filePath) {
    if (!filePath || !fs.existsSync(filePath)) return;
    try {
        fs.unlinkSync(filePath);
    } catch (e) {
        console.warn(`[Backup] Notice: Could not remove file ${filePath} immediately (${e.code || e.message}).`);
    }
}

exports.getBackupInfo = (req, res) => {
    let info = { lastBackup: null, lastRestore: null };
    if (fs.existsSync(INFO_FILE)) {
        try { info = JSON.parse(fs.readFileSync(INFO_FILE, 'utf8')); } catch(e) {}
    }
    res.json(info);
};

exports.downloadBackup = async (req, res) => {
    let tempDbBackupPath = null;
    try {
        const dataDir = path.resolve('./data');
        if (!fs.existsSync(dataDir)) {
            fs.mkdirSync(dataDir, { recursive: true });
        }

        const dateStr = new Date().toISOString().split('T')[0];
        const filename = `tis_rms_${dateStr}.db`;

        // Create a safe online backup of the SQLite database using better-sqlite3 db.backup()
        tempDbBackupPath = path.join(dataDir, `temp_backup_${Date.now()}_tis_rms.db`);
        console.log('[Backup] Running db.backup() online SQLite backup...');
        await db.backup(tempDbBackupPath);

        // Download directly without zipping
        res.download(tempDbBackupPath, filename, (err) => {
            safeRemoveFileSync(tempDbBackupPath);
            if (err && !res.headersSent) {
                console.error('[Backup] Download send error:', err);
                res.status(500).json({ message: 'Failed to send backup file', error: err.message });
            }
        });

        // Log the backup activity
        logActivity('backup');

    } catch (error) {
        if (tempDbBackupPath) {
            safeRemoveFileSync(tempDbBackupPath);
        }
        console.error('[Backup] Download error:', error);
        if (!res.headersSent) {
            res.status(500).json({ message: 'Failed to generate backup', error: error.message });
        }
    }
};

function isSqliteFile(filePath) {
    try {
        const fd = fs.openSync(filePath, 'r');
        const buffer = Buffer.alloc(16);
        fs.readSync(fd, buffer, 0, 16, 0);
        fs.closeSync(fd);
        return buffer.toString('utf8', 0, 15) === 'SQLite format 3';
    } catch (e) {
        return false;
    }
}

exports.restoreBackup = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No backup file provided.' });
        }

        console.log(`[Backup] Received restore file: ${req.file.originalname}`);

        const filePath = req.file.path;
        const originalName = (req.file.originalname || '').toLowerCase();

        if (!isSqliteFile(filePath) && !originalName.endsWith('.db') && !originalName.endsWith('.sqlite') && !originalName.endsWith('.sqlite3')) {
            safeRemoveFileSync(filePath);
            return res.status(400).json({ message: 'Invalid backup file. Please provide a valid SQLite .db backup file without zipping.' });
        }

        console.log('[Backup] Closing current database connection...');
        // Close DB before overwriting
        try {
            db.close();
        } catch (e) {
            console.warn('[Backup] db.close warning:', e.message);
        }

        const currentDataDir = path.resolve('./data');
        if (!fs.existsSync(currentDataDir)) {
            fs.mkdirSync(currentDataDir, { recursive: true });
        }
        const currentDbPath = path.join(currentDataDir, 'tis_rms.db');
        const currentDbWalPath = path.join(currentDataDir, 'tis_rms.db-wal');
        const currentDbShmPath = path.join(currentDataDir, 'tis_rms.db-shm');

        console.log('[Backup] Overwriting database...');
        fs.copyFileSync(filePath, currentDbPath);

        console.log('[Backup] Cleaning up any existing WAL and SHM files...');
        if (fs.existsSync(currentDbWalPath)) {
            safeRemoveFileSync(currentDbWalPath);
        }
        if (fs.existsSync(currentDbShmPath)) {
            safeRemoveFileSync(currentDbShmPath);
        }

        // Cleanup uploaded file
        if (fs.existsSync(filePath)) {
            safeRemoveFileSync(filePath);
        }

        console.log('[Backup] Restore completed successfully. Shutting down server...');

        // Log the restore activity
        logActivity('restore');

        // Send response first, then exit after a short delay
        res.json({ success: true, message: 'Database restored successfully. Server will shut down now.' });

        setTimeout(() => {
            console.log('Exiting process for restart...');
            process.exit(0);
        }, 2000);

    } catch (error) {
        console.error('[Backup] Restore error:', error);
        if (req.file && fs.existsSync(req.file.path)) {
            safeRemoveFileSync(req.file.path);
        }
        res.status(500).json({ message: 'Failed to restore backup', error: error.message });
    }
};
