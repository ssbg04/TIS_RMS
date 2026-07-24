const fs = require('fs');
const path = require('path');
const AdmZip = require('adm-zip');
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

exports.getBackupInfo = (req, res) => {
    let info = { lastBackup: null, lastRestore: null };
    if (fs.existsSync(INFO_FILE)) {
        try { info = JSON.parse(fs.readFileSync(INFO_FILE, 'utf8')); } catch(e) {}
    }
    res.json(info);
};

exports.downloadBackup = async (req, res) => {
    try {
        const zip = new AdmZip();

        const dataDir = path.resolve('./data');

        // Checkpoint WAL to ensure database file is completely up-to-date and WAL is mostly empty
        db.pragma('wal_checkpoint(TRUNCATE)');

        // Add database files directly
        const dbFile = path.join(dataDir, 'tis_rms.db');
        const walFile = path.join(dataDir, 'tis_rms.db-wal');
        const shmFile = path.join(dataDir, 'tis_rms.db-shm');

        if (fs.existsSync(dbFile)) zip.addLocalFile(dbFile, 'data');
        if (fs.existsSync(walFile)) zip.addLocalFile(walFile, 'data');
        if (fs.existsSync(shmFile)) zip.addLocalFile(shmFile, 'data');

        // Add students folder where documents are saved
        const studentsDir = path.join(dataDir, 'students');
        if (fs.existsSync(studentsDir)) {
            zip.addLocalFolder(studentsDir, 'data/students');
        }

        const zipBuffer = zip.toBuffer();

        const dateStr = new Date().toISOString().split('T')[0];
        const filename = `tis_rms_backup_${dateStr}.zip`;

        res.set({
            'Content-Disposition': `attachment; filename="${filename}"`,
            'Content-Type': 'application/zip',
            'Content-Length': zipBuffer.length
        });

        // Log the backup activity
        logActivity('backup');

        return res.send(zipBuffer);

    } catch (error) {
        console.error('[Backup] Download error:', error);
        res.status(500).json({ message: 'Failed to generate backup', error: error.message });
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
        const hasDb = zipEntries.some(entry => entry.entryName === 'data/tis_rms.db');
        
        if (!hasDb) {
            fs.unlinkSync(zipPath); // clean up
            return res.status(400).json({ message: 'Invalid backup file. Missing data/tis_rms.db.' });
        }

        // We will extract to a temporary folder to ensure we don't partially overwrite things if something fails
        const tempExtractDir = path.resolve(`./temp_restore_${Date.now()}`);
        fs.mkdirSync(tempExtractDir, { recursive: true });

        zip.extractAllTo(tempExtractDir, true);

        const extractedDbPath = path.join(tempExtractDir, 'data', 'tis_rms.db');
        const extractedWalPath = path.join(tempExtractDir, 'data', 'tis_rms.db-wal');
        const extractedShmPath = path.join(tempExtractDir, 'data', 'tis_rms.db-shm');
        const extractedStudentsDir = path.join(tempExtractDir, 'data', 'students');

        if (!fs.existsSync(extractedDbPath)) {
            fs.rmSync(tempExtractDir, { recursive: true, force: true });
            fs.unlinkSync(zipPath);
            return res.status(400).json({ message: 'Extraction failed: Database file not found in extracted contents.' });
        }

        console.log('[Backup] Closing current database connection...');
        // Close DB before overwriting
        db.close();

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
            fs.unlinkSync(currentDbWalPath);
        }

        if (fs.existsSync(extractedShmPath)) {
            fs.copyFileSync(extractedShmPath, currentDbShmPath);
        } else if (fs.existsSync(currentDbShmPath)) {
            fs.unlinkSync(currentDbShmPath);
        }

        console.log('[Backup] Replacing students directory...');
        if (fs.existsSync(extractedStudentsDir)) {
            // Safe copy of students documents
            if (fs.existsSync(currentStudentsDir)) {
                fs.rmSync(currentStudentsDir, { recursive: true, force: true });
            }
            fs.cpSync(extractedStudentsDir, currentStudentsDir, { recursive: true });
        }

        // Cleanup temp directories and uploaded zip file
        fs.rmSync(tempExtractDir, { recursive: true, force: true });
        fs.unlinkSync(zipPath);

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
            fs.unlinkSync(req.file.path);
        }
        res.status(500).json({ message: 'Failed to restore backup', error: error.message });
    }
};
