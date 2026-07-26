const fs = require('fs');
const path = require('path');
const AdmZip = require('adm-zip');
const archiver = require('archiver');
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
    try {
        const dataDir = path.resolve('./data');

        // Checkpoint WAL to ensure database file is completely up-to-date and WAL is mostly empty
        try {
            db.pragma('wal_checkpoint(TRUNCATE)');
        } catch (e) {
            console.warn('[Backup] wal_checkpoint warning:', e.message);
        }

        const dateStr = new Date().toISOString().split('T')[0];
        const filename = `tis_rms_backup_${dateStr}.zip`;

        res.set({
            'Content-Disposition': `attachment; filename="${filename}"`,
            'Content-Type': 'application/zip'
        });

        // Use archiver with maximum DEFLATE compression (level 9)
        const archive = new archiver.ZipArchive({
            zlib: { level: 9 } // level 9 gives maximum compression ratio
        });

        archive.on('error', (err) => {
            console.error('[Backup] Archiver error:', err);
            if (!res.headersSent) {
                res.status(500).json({ message: 'Failed to generate backup', error: err.message });
            }
        });

        // Pipe compressed zip directly to HTTP response stream
        archive.pipe(res);

        // Add database files directly
        const dbFile = path.join(dataDir, 'tis_rms.db');
        const walFile = path.join(dataDir, 'tis_rms.db-wal');
        const shmFile = path.join(dataDir, 'tis_rms.db-shm');

        if (fs.existsSync(dbFile)) archive.file(dbFile, { name: 'data/tis_rms.db' });
        if (fs.existsSync(walFile)) archive.file(walFile, { name: 'data/tis_rms.db-wal' });
        if (fs.existsSync(shmFile)) archive.file(shmFile, { name: 'data/tis_rms.db-shm' });

        // Add students folder where documents are saved
        const studentsDir = path.join(dataDir, 'students');
        if (fs.existsSync(studentsDir)) {
            archive.directory(studentsDir, 'data/students');
        }

        // Finalize archive to complete streaming
        await archive.finalize();

        // Log the backup activity
        logActivity('backup');

    } catch (error) {
        console.error('[Backup] Download error:', error);
        if (!res.headersSent) {
            res.status(500).json({ message: 'Failed to generate backup', error: error.message });
        }
    }
};

exports.restoreBackup = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No backup file provided.' });
        }

        console.log(`[Backup] Received restore file: ${req.file.originalname}`);

        const zipPath = req.file.path;
        const zip = new AdmZip(zipPath);

        // Verify the contents of the zip first
        const zipEntries = zip.getEntries();
        const hasDb = zipEntries.some(entry => {
            const normalized = entry.entryName.replace(/\\/g, '/');
            return normalized.endsWith('tis_rms.db');
        });
        
        if (!hasDb) {
            safeRemoveFileSync(zipPath); // clean up
            return res.status(400).json({ message: 'Invalid backup file. Could not find tis_rms.db in zip.' });
        }

        // Clean up any old temporary restore directories from previous runs
        try {
            const rootDir = path.resolve('./');
            const entries = fs.readdirSync(rootDir, { withFileTypes: true });
            for (const entry of entries) {
                if (entry.isDirectory() && entry.name.startsWith('temp_restore_')) {
                    safeRemoveDirSync(path.join(rootDir, entry.name));
                }
            }
        } catch (e) {
            console.warn('[Backup] Notice checking old temp directories:', e.message);
        }

        // We will extract to a temporary folder to ensure we don't partially overwrite things if something fails
        const tempExtractDir = path.resolve(`./temp_restore_${Date.now()}`);
        fs.mkdirSync(tempExtractDir, { recursive: true });

        zip.extractAllTo(tempExtractDir, true);

        function findFileRecursively(dir, filename) {
            if (!fs.existsSync(dir)) return null;
            const entries = fs.readdirSync(dir, { withFileTypes: true });
            for (const entry of entries) {
                const fullPath = path.join(dir, entry.name);
                if (entry.isDirectory()) {
                    const found = findFileRecursively(fullPath, filename);
                    if (found) return found;
                } else if (entry.name === filename) {
                    return fullPath;
                }
            }
            return null;
        }

        function findDirRecursively(dir, dirname) {
            if (!fs.existsSync(dir)) return null;
            const entries = fs.readdirSync(dir, { withFileTypes: true });
            for (const entry of entries) {
                const fullPath = path.join(dir, entry.name);
                if (entry.isDirectory()) {
                    if (entry.name === dirname) return fullPath;
                    const found = findDirRecursively(fullPath, dirname);
                    if (found) return found;
                }
            }
            return null;
        }

        const extractedDbPath = findFileRecursively(tempExtractDir, 'tis_rms.db');
        const extractedWalPath = findFileRecursively(tempExtractDir, 'tis_rms.db-wal');
        const extractedShmPath = findFileRecursively(tempExtractDir, 'tis_rms.db-shm');
        const extractedStudentsDir = findDirRecursively(tempExtractDir, 'students');

        if (!extractedDbPath || !fs.existsSync(extractedDbPath)) {
            safeRemoveDirSync(tempExtractDir);
            safeRemoveFileSync(zipPath);
            return res.status(400).json({ message: 'Extraction failed: Database file not found in extracted contents.' });
        }

        console.log('[Backup] Closing current database connection...');
        // Close DB before overwriting
        try {
            db.close();
        } catch (e) {
            console.warn('[Backup] db.close warning:', e.message);
        }

        const currentDataDir = path.resolve('./data');
        const currentDbPath = path.join(currentDataDir, 'tis_rms.db');
        const currentDbWalPath = path.join(currentDataDir, 'tis_rms.db-wal');
        const currentDbShmPath = path.join(currentDataDir, 'tis_rms.db-shm');
        const currentStudentsDir = path.join(currentDataDir, 'students');

        console.log('[Backup] Overwriting database...');
        fs.copyFileSync(extractedDbPath, currentDbPath);

        console.log('[Backup] Replacing WAL and SHM files...');
        if (fs.existsSync(extractedWalPath)) {
            fs.copyFileSync(extractedWalPath, currentDbWalPath);
        } else if (fs.existsSync(currentDbWalPath)) {
            safeRemoveFileSync(currentDbWalPath);
        }

        if (fs.existsSync(extractedShmPath)) {
            fs.copyFileSync(extractedShmPath, currentDbShmPath);
        } else if (fs.existsSync(currentDbShmPath)) {
            safeRemoveFileSync(currentDbShmPath);
        }

        console.log('[Backup] Replacing students directory...');
        if (fs.existsSync(extractedStudentsDir)) {
            // Safe copy of students documents
            if (fs.existsSync(currentStudentsDir)) {
                safeRemoveDirSync(currentStudentsDir);
            }
            fs.cpSync(extractedStudentsDir, currentStudentsDir, { recursive: true });
        }

        // Cleanup temp directories and uploaded zip file
        safeRemoveDirSync(tempExtractDir);
        safeRemoveFileSync(zipPath);

        console.log('[Backup] Restore completed successfully. Shutting down server...');

        // Log the restore activity
        // Note: because we overwrite the data folder, if the info file was in the zip, it got overwritten.
        // So we log the restore *after* replacing the files so it's persisted correctly.
        logActivity('restore');

        // Send response first, then exit after a short delay
        res.json({ success: true, message: 'Database and files restored successfully. Server will shut down now.' });

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
