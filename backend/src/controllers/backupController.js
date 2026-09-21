const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const archiver = require('archiver');
const unzipper = require('unzipper');
const db = require('../config/db');

const INFO_FILE = path.resolve('./data/backup_info.json');
const LOGS_FILE = path.resolve('./data/backup_logs.txt');
const SCHEMA_VERSION = '2'; // bump when backup format changes

// ── Logging helpers ──────────────────────────────────────────────────────────
function logActivity(action) {
    const timestamp = new Date().toISOString();
    let info = {};
    if (fs.existsSync(INFO_FILE)) {
        try { info = JSON.parse(fs.readFileSync(INFO_FILE, 'utf8')); } catch (e) {}
    }
    if (action === 'backup') info.lastBackup = timestamp;
    if (action === 'restore') info.lastRestore = timestamp;
    fs.writeFileSync(INFO_FILE, JSON.stringify(info, null, 2));
    fs.appendFileSync(LOGS_FILE, `[${timestamp}] ${action.toUpperCase()} completed successfully.\n`);
}

function safeRemoveDirSync(dirPath) {
    if (!dirPath || !fs.existsSync(dirPath)) return;
    try { fs.rmSync(dirPath, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 }); }
    catch (e) { console.warn(`[Backup] Could not remove ${dirPath}: ${e.message}`); }
}

function safeRemoveFileSync(filePath) {
    if (!filePath || !fs.existsSync(filePath)) return;
    try { fs.unlinkSync(filePath); }
    catch (e) { console.warn(`[Backup] Could not remove ${filePath}: ${e.message}`); }
}

// ── SHA-256 checksum ──────────────────────────────────────────────────────────
function sha256File(filePath) {
    return new Promise((resolve, reject) => {
        const hash = crypto.createHash('sha256');
        const stream = fs.createReadStream(filePath);
        stream.on('data', (chunk) => hash.update(chunk));
        stream.on('end', () => resolve(hash.digest('hex')));
        stream.on('error', reject);
    });
}

// ── Validate SQLite magic bytes ───────────────────────────────────────────────
function isSqliteFile(filePath) {
    try {
        const fd = fs.openSync(filePath, 'r');
        const buffer = Buffer.alloc(16);
        fs.readSync(fd, buffer, 0, 16, 0);
        fs.closeSync(fd);
        return buffer.toString('utf8', 0, 15) === 'SQLite format 3';
    } catch (e) { return false; }
}

// ── GET /api/backup/info ──────────────────────────────────────────────────────
exports.getBackupInfo = (req, res) => {
    let info = { lastBackup: null, lastRestore: null };
    if (fs.existsSync(INFO_FILE)) {
        try { info = JSON.parse(fs.readFileSync(INFO_FILE, 'utf8')); } catch (e) {}
    }
    res.json(info);
};

// ── GET /api/backup/download ──────────────────────────────────────────────────
exports.downloadBackup = async (req, res) => {
    const tempDbPath = path.resolve('./data', `temp_backup_${Date.now()}_tis_rms.db`);

    try {
        const dataDir = path.resolve('./data');
        if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });

        const dateStr = new Date().toISOString().split('T')[0];
        const zipFileName = `tis_rms_backup_${dateStr}.zip`;

        // 1. Online SQLite backup
        console.log('[Backup] Running online SQLite backup…');
        await db.backup(tempDbPath);

        // 2. Build manifest with checksums
        const dbChecksum = await sha256File(tempDbPath);

        const manifest = {
            schema_version: SCHEMA_VERSION,
            created_at: new Date().toISOString(),
            db_checksum_sha256: dbChecksum,
            includes: ['tis_rms.db', 'students/', 'templates/'],
        };

        // 3. Stream ZIP to response
        res.setHeader('Content-Disposition', `attachment; filename="${zipFileName}"`);
        res.setHeader('Content-Type', 'application/zip');

        const archive = archiver('zip', { zlib: { level: 6 } });
        archive.on('warning', (err) => {
            if (err.code !== 'ENOENT') throw err;
            console.warn('[Backup] archiver warning:', err.message);
        });
        archive.on('error', (err) => {
            console.error('[Backup] archiver error:', err);
            if (!res.headersSent) res.status(500).json({ message: 'Backup archive failed', error: err.message });
        });
        archive.pipe(res);

        // DB file
        archive.file(tempDbPath, { name: 'tis_rms.db' });

        // Students directory
        const studentsDir = process.env.STUDENT_DIR_ROOT
            ? path.resolve(process.env.STUDENT_DIR_ROOT)
            : path.resolve('./data/students');
        if (fs.existsSync(studentsDir)) {
            archive.directory(studentsDir, 'students');
        }

        // Templates directory
        const templatesDir = process.env.TEMPLATES_DIR
            ? path.resolve(process.env.TEMPLATES_DIR)
            : path.resolve('./data/templates');
        if (fs.existsSync(templatesDir)) {
            archive.directory(templatesDir, 'templates');
        }

        // Manifest
        archive.append(JSON.stringify(manifest, null, 2), { name: 'manifest.json' });

        await archive.finalize();

        // Cleanup temp DB after stream finishes
        res.on('finish', () => {
            safeRemoveFileSync(tempDbPath);
            logActivity('backup');
        });

    } catch (error) {
        safeRemoveFileSync(tempDbPath);
        console.error('[Backup] Download error:', error);
        if (!res.headersSent) {
            res.status(500).json({ message: 'Failed to generate backup', error: error.message });
        }
    }
};

// ── POST /api/backup/restore ──────────────────────────────────────────────────
exports.restoreBackup = async (req, res) => {
    let tempExtractDir = null;

    try {
        if (!req.file) return res.status(400).json({ message: 'No backup file provided.' });

        const filePath = req.file.path;
        const originalName = (req.file.originalname || '').toLowerCase();
        const isZip = originalName.endsWith('.zip');
        const isDb = originalName.endsWith('.db') || originalName.endsWith('.sqlite') || originalName.endsWith('.sqlite3');

        if (!isZip && !isDb) {
            safeRemoveFileSync(filePath);
            return res.status(400).json({ message: 'Invalid backup file. Provide a .zip backup (recommended) or a legacy .db file.' });
        }

        // ── Legacy DB-only restore ────────────────────────────────────────────
        if (isDb) {
            if (!isSqliteFile(filePath)) {
                safeRemoveFileSync(filePath);
                return res.status(400).json({ message: 'Invalid SQLite file.' });
            }
            console.log('[Backup] Legacy DB-only restore…');
            const safetyPath = path.resolve('./data', `pre_restore_${Date.now()}.db`);
            await db.backup(safetyPath);

            db.close();
            fs.copyFileSync(filePath, path.resolve('./data/tis_rms.db'));
            ['.db-wal', '.db-shm'].forEach(ext => {
                const p = path.resolve('./data/tis_rms' + ext);
                if (fs.existsSync(p)) safeRemoveFileSync(p);
            });
            safeRemoveFileSync(filePath);
            logActivity('restore');
            res.json({ success: true, message: 'Database restored (legacy mode — no file restore). Server will restart.', warning: 'Student and template files were not included in this backup.' });
            setTimeout(() => process.exit(0), 2000);
            return;
        }

        // ── ZIP restore ───────────────────────────────────────────────────────
        console.log('[Backup] ZIP restore started…');
        tempExtractDir = path.resolve('./data', `temp_restore_${Date.now()}`);
        fs.mkdirSync(tempExtractDir, { recursive: true });

        // 1. Extract
        await fs.createReadStream(filePath)
            .pipe(unzipper.Extract({ path: tempExtractDir }))
            .promise();

        // 2. Read + validate manifest
        const manifestPath = path.join(tempExtractDir, 'manifest.json');
        if (!fs.existsSync(manifestPath)) {
            safeRemoveDirSync(tempExtractDir);
            safeRemoveFileSync(filePath);
            return res.status(400).json({ message: 'Invalid backup: missing manifest.json.' });
        }
        const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
        console.log(`[Backup] Manifest: schema_version=${manifest.schema_version}, created_at=${manifest.created_at}`);

        // 3. Verify DB checksum
        const extractedDbPath = path.join(tempExtractDir, 'tis_rms.db');
        if (!fs.existsSync(extractedDbPath)) {
            safeRemoveDirSync(tempExtractDir);
            safeRemoveFileSync(filePath);
            return res.status(400).json({ message: 'Invalid backup: tis_rms.db not found in archive.' });
        }
        if (!isSqliteFile(extractedDbPath)) {
            safeRemoveDirSync(tempExtractDir);
            safeRemoveFileSync(filePath);
            return res.status(400).json({ message: 'Backup database file is not a valid SQLite file.' });
        }
        if (manifest.db_checksum_sha256) {
            const actualChecksum = await sha256File(extractedDbPath);
            if (actualChecksum !== manifest.db_checksum_sha256) {
                safeRemoveDirSync(tempExtractDir);
                safeRemoveFileSync(filePath);
                return res.status(400).json({ message: 'Backup integrity check failed: database checksum mismatch.' });
            }
            console.log('[Backup] DB checksum verified ✓');
        }

        // 4. Safety backup of current installation
        const safetyPath = path.resolve('./data', `pre_restore_${Date.now()}.db`);
        console.log(`[Backup] Creating safety backup → ${safetyPath}`);
        await db.backup(safetyPath);

        // 5. Close DB + overwrite
        console.log('[Backup] Closing DB and restoring…');
        db.close();
        fs.copyFileSync(extractedDbPath, path.resolve('./data/tis_rms.db'));
        ['.db-wal', '.db-shm'].forEach(ext => {
            const p = path.resolve('./data/tis_rms' + ext);
            if (fs.existsSync(p)) safeRemoveFileSync(p);
        });

        // 6. Restore student files (merge)
        const extractedStudentsDir = path.join(tempExtractDir, 'students');
        if (fs.existsSync(extractedStudentsDir)) {
            const studentsDir = process.env.STUDENT_DIR_ROOT
                ? path.resolve(process.env.STUDENT_DIR_ROOT)
                : path.resolve('./data/students');
            console.log(`[Backup] Restoring student files → ${studentsDir}`);
            fs.cpSync(extractedStudentsDir, studentsDir, { recursive: true, force: true });
        }

        // 7. Restore template files (merge)
        const extractedTemplatesDir = path.join(tempExtractDir, 'templates');
        if (fs.existsSync(extractedTemplatesDir)) {
            const templatesDir = process.env.TEMPLATES_DIR
                ? path.resolve(process.env.TEMPLATES_DIR)
                : path.resolve('./data/templates');
            console.log(`[Backup] Restoring template files → ${templatesDir}`);
            fs.cpSync(extractedTemplatesDir, templatesDir, { recursive: true, force: true });
        }

        // 8. Cleanup
        safeRemoveDirSync(tempExtractDir);
        safeRemoveFileSync(filePath);

        logActivity('restore');

        res.json({ success: true, message: 'Backup restored successfully (DB + files). Server will restart.' });
        setTimeout(() => {
            console.log('[Backup] Restarting after restore…');
            process.exit(0);
        }, 2000);

    } catch (error) {
        console.error('[Backup] Restore error:', error);
        if (tempExtractDir) safeRemoveDirSync(tempExtractDir);
        if (req.file?.path && fs.existsSync(req.file.path)) safeRemoveFileSync(req.file.path);
        if (!res.headersSent) {
            res.status(500).json({ message: 'Failed to restore backup', error: error.message });
        }
    }
};
