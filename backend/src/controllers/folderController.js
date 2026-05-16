const db = require('../config/db');
const path = require('path');
const fs = require('fs');

// Configurable student directory root
const STUDENT_DIR_ROOT = process.env.STUDENT_DIR_ROOT
    ? path.resolve(process.env.STUDENT_DIR_ROOT)
    : path.resolve(__dirname, '../../../data/students');

const sanitizeFolderName = (str) =>
    (str || '').replace(/[<>:"/\\|?*\x00-\x1F]/g, '').trim();

// ============================================================
// GET /api/folders — list folders (manual + auto-created)
// ============================================================
exports.getFolders = (req, res) => {
    const { studentId, parentId, search = '' } = req.query;

    try {
        const conditions = [];
        const params = [];

        if (studentId) {
            conditions.push('student_id = ?');
            params.push(studentId);
        }

        if (parentId !== undefined) {
            if (parentId === 'null' || parentId === '') {
                conditions.push('parent_id IS NULL');
            } else {
                conditions.push('parent_id = ?');
                params.push(parseInt(parentId));
            }
        }

        if (search.trim()) {
            conditions.push('name LIKE ?');
            params.push(`%${search.trim()}%`);
        }

        const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

        const sql = `
            SELECT f.*,
                   s.lrn, s.first_name, s.last_name,
                   u.username as created_by_username,
                   (SELECT COUNT(*) FROM documents d WHERE d.student_id = f.student_id) as document_count
            FROM document_folders f
            LEFT JOIN students s ON f.student_id = s.id
            LEFT JOIN users u ON f.created_by = u.id
            ${whereClause}
            ORDER BY f.name ASC
        `;

        const folders = db.prepare(sql).all(params);
        res.json(folders);
    } catch (error) {
        console.error('getFolders error:', error);
        res.status(500).json({ message: 'Failed to fetch folders', error: error.message });
    }
};

// ============================================================
// POST /api/folders — create manual folder
// ============================================================
exports.createFolder = (req, res) => {
    const { name, parentId, studentId, category } = req.body;
    const userId = req.user.id;

    if (!name || !name.trim()) {
        return res.status(400).json({ message: 'Folder name is required' });
    }

    // Validate: either studentId or parentId must be provided
    if (!studentId && !parentId) {
        return res.status(400).json({ message: 'Either student_id or parent_id is required' });
    }

    // Check for duplicate folder name in same scope
    let duplicateCheckSql = '';
    let duplicateParams = [];

    if (studentId) {
        duplicateCheckSql = 'SELECT id FROM document_folders WHERE name = ? AND student_id = ? AND parent_id IS NULL';
        duplicateParams = [name.trim(), studentId];
    } else if (parentId) {
        duplicateCheckSql = 'SELECT id FROM document_folders WHERE name = ? AND parent_id = ?';
        duplicateParams = [name.trim(), parentId];
    }

    const existing = db.prepare(duplicateCheckSql).get(...duplicateParams);
    if (existing) {
        return res.status(409).json({ message: 'A folder with this name already exists in this location' });
    }

    try {
        // Create in database
        const result = db.prepare(`
            INSERT INTO document_folders (name, parent_id, student_id, category, created_by)
            VALUES (?, ?, ?, ?, ?)
        `).run(
            name.trim(),
            parentId ? parseInt(parentId) : null,
            studentId ? parseInt(studentId) : null,
            category || null,
            userId
        );

        // Optionally create physical folder if it relates to a student
        if (studentId) {
            const student = db.prepare('SELECT lrn, first_name, last_name FROM students WHERE id = ?').get(studentId);
            if (student) {
                const folderName = `${sanitizeFolderName(student.last_name)}_${sanitizeFolderName(student.first_name)}_${student.lrn}`;
                const basePath = path.join(STUDENT_DIR_ROOT, folderName);

                // Create category subfolder if category provided
                let folderPath = basePath;
                if (category) {
                    folderPath = path.join(basePath, sanitizeFolderName(category));
                }

                // Create parent path first
                if (!fs.existsSync(basePath)) {
                    fs.mkdirSync(basePath, { recursive: true });
                }

                if (!fs.existsSync(folderPath)) {
                    fs.mkdirSync(folderPath, { recursive: true });
                }
            }
        }

        res.status(201).json({
            id: result.lastInsertRowid,
            message: 'Folder created successfully'
        });
    } catch (error) {
        console.error('createFolder error:', error);
        res.status(500).json({ message: 'Failed to create folder', error: error.message });
    }
};

// ============================================================
// PUT /api/folders/:id — rename folder
// ============================================================
exports.renameFolder = (req, res) => {
    const { id } = req.params;
    const { name } = req.body;

    if (!name || !name.trim()) {
        return res.status(400).json({ message: 'New folder name is required' });
    }

    const folder = db.prepare('SELECT * FROM document_folders WHERE id = ?').get(id);
    if (!folder) {
        return res.status(404).json({ message: 'Folder not found' });
    }

    // Check for duplicate in same scope
    let duplicateCheckSql = '';
    let duplicateParams = [];

    if (folder.parent_id) {
        duplicateCheckSql = 'SELECT id FROM document_folders WHERE name = ? AND parent_id = ? AND id != ?';
        duplicateParams = [name.trim(), folder.parent_id, id];
    } else if (folder.student_id) {
        duplicateCheckSql = 'SELECT id FROM document_folders WHERE name = ? AND student_id = ? AND parent_id IS NULL AND id != ?';
        duplicateParams = [name.trim(), folder.student_id, id];
    }

    if (duplicateCheckSql) {
        const existing = db.prepare(duplicateCheckSql).get(...duplicateParams);
        if (existing) {
            return res.status(409).json({ message: 'A folder with this name already exists in this location' });
        }
    }

    try {
        db.prepare(`
            UPDATE document_folders SET name = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?
        `).run(name.trim(), id);

        res.json({ message: 'Folder renamed successfully' });
    } catch (error) {
        console.error('renameFolder error:', error);
        res.status(500).json({ message: 'Failed to rename folder', error: error.message });
    }
};

// ============================================================
// DELETE /api/folders/:id — delete folder
// ============================================================
exports.deleteFolder = (req, res) => {
    const { id } = req.params;

    const folder = db.prepare('SELECT * FROM document_folders WHERE id = ?').get(id);
    if (!folder) {
        return res.status(404).json({ message: 'Folder not found' });
    }

    // Check if folder has children
    const children = db.prepare('SELECT COUNT(*) as count FROM document_folders WHERE parent_id = ?').get(id);
    if (children.count > 0) {
        return res.status(400).json({ message: 'Cannot delete folder with subfolders' });
    }

    try {
        db.prepare('DELETE FROM document_folders WHERE id = ?').run(id);
        res.json({ message: 'Folder deleted successfully' });
    } catch (error) {
        console.error('deleteFolder error:', error);
        res.status(500).json({ message: 'Failed to delete folder', error: error.message });
    }
};

// ============================================================
// GET /api/folders/student/:studentId — get student document folder
// ============================================================
exports.getStudentFolder = (req, res) => {
    const { studentId } = req.params;

    try {
        const student = db.prepare('SELECT * FROM students WHERE id = ?').get(studentId);
        if (!student) {
            return res.status(404).json({ message: 'Student not found' });
        }

        // Get or create student folder record
        let folder = db.prepare(`
            SELECT * FROM document_folders
            WHERE student_id = ? AND parent_id IS NULL
        `).get(studentId);

        if (!folder) {
            // Auto-create folder record
            const folderName = `${student.last_name}_${student.first_name}_${student.lrn}`;
            const result = db.prepare(`
                INSERT INTO document_folders (name, student_id, category, created_by)
                VALUES (?, ?, 'root', NULL)
            `).run(folderName, studentId);

            folder = {
                id: result.lastInsertRowid,
                name: folderName,
                student_id: studentId,
                category: 'root'
            };
        }

        // Get all subfolders for this student
        const subfolders = db.prepare(`
            SELECT * FROM document_folders
            WHERE student_id = ? AND parent_id IS NOT NULL
            ORDER BY name ASC
        `).all(studentId);

        // Get physical folder contents
        const folderPath = path.join(STUDENT_DIR_ROOT,
            `${sanitizeFolderName(student.last_name)}_${sanitizeFolderName(student.first_name)}_${student.lrn}`);

        let physicalFolders = [];
        let physicalFiles = [];

        if (fs.existsSync(folderPath)) {
            const entries = fs.readdirSync(folderPath, { withFileTypes: true });
            physicalFolders = entries
                .filter(e => e.isDirectory())
                .map(e => ({ name: e.name, isDirectory: true }));
            physicalFiles = entries
                .filter(e => e.isFile())
                .map(e => ({ name: e.name, isDirectory: false }));
        }

        res.json({
            ...folder,
            student: {
                id: student.id,
                lrn: student.lrn,
                firstName: student.first_name,
                lastName: student.last_name
            },
            subfolders,
            physicalFolders,
            physicalFiles,
            folderPath
        });
    } catch (error) {
        console.error('getStudentFolder error:', error);
        res.status(500).json({ message: 'Failed to get student folder', error: error.message });
    }
};

// ============================================================
// POST /api/folders/sync — sync DB folders with physical storage
// ============================================================
exports.syncFolders = (req, res) => {
    const { studentId } = req.body;

    try {
        const student = db.prepare('SELECT * FROM students WHERE id = ?').get(studentId);
        if (!student) {
            return res.status(404).json({ message: 'Student not found' });
        }

        const folderPath = path.join(STUDENT_DIR_ROOT,
            `${sanitizeFolderName(student.last_name)}_${sanitizeFolderName(student.first_name)}_${student.lrn}`);

        if (!fs.existsSync(folderPath)) {
            fs.mkdirSync(folderPath, { recursive: true });
        }

        // Read physical folders
        const entries = fs.readdirSync(folderPath, { withFileTypes: true });
        const physicalDirs = entries.filter(e => e.isDirectory()).map(e => e.name);

        // Get existing DB folders for this student
        const existingFolders = db.prepare(`
            SELECT name FROM document_folders
            WHERE student_id = ? AND parent_id IS NOT NULL
        `).all(studentId);
        const dbFolderNames = new Set(existingFolders.map(f => f.name));

        // Add missing folders to DB
        const newFolders = [];
        for (const dirName of physicalDirs) {
            if (!dbFolderNames.has(dirName)) {
                // Determine category from folder name or use folder name
                const category = dirName;
                db.prepare(`
                    INSERT INTO document_folders (name, student_id, category, created_by)
                    VALUES (?, ?, ?, NULL)
                `).run(dirName, studentId, category);
                newFolders.push(dirName);
            }
        }

        res.json({
            message: 'Folders synced successfully',
            newFolders,
            totalFolders: physicalDirs.length
        });
    } catch (error) {
        console.error('syncFolders error:', error);
        res.status(500).json({ message: 'Failed to sync folders', error: error.message });
    }
};