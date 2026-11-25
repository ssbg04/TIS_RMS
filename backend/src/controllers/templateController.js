const db = require('../config/db');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// ── Storage root for template files ──────────────────────────────────────────
const TEMPLATES_DIR = process.env.TEMPLATES_DIR
    ? path.resolve(process.env.TEMPLATES_DIR)
    : path.resolve(__dirname, '../../../data/templates');

if (!fs.existsSync(TEMPLATES_DIR)) {
    fs.mkdirSync(TEMPLATES_DIR, { recursive: true });
}

// ── Multer config ─────────────────────────────────────────────────────────────
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        const templateId = req.params.id || req.body.templateId || 'new';
        const dir = path.join(TEMPLATES_DIR, String(templateId));
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        req._templateUploadDir = dir;
        cb(null, dir);
    },
    filename: (req, file, cb) => {
        const ext = path.extname(file.originalname);
        const base = path.basename(file.originalname, ext).replace(/[<>:"/\\|?*\x00-\x1F]/g, '').trim();
        const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
        cb(null, `${ts}_${base}${ext}`);
    },
});
const upload = multer({ storage });
exports.uploadMiddleware = upload.single('file');

// ── Helper: log activity ──────────────────────────────────────────────────────
const logActivity = (userId, action, entityType, entityId, description) => {
    try {
        db.prepare(
            'INSERT INTO activity_log (user_id, action, entity_type, entity_id, description) VALUES (?, ?, ?, ?, ?)'
        ).run(userId ?? null, action, entityType, entityId ?? null, description);
    } catch (_) {}
};

// ── GET /api/templates ────────────────────────────────────────────────────────
exports.getTemplates = (req, res) => {
    try {
        const { requirementId, isActive } = req.query;
        const conditions = [];
        const params = [];

        if (requirementId) {
            conditions.push('t.requirement_id = ?');
            params.push(requirementId);
        }
        if (isActive !== undefined && isActive !== '') {
            conditions.push('t.is_active = ?');
            params.push(isActive === 'true' ? 1 : 0);
        }

        const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

        const templates = db.prepare(`
            SELECT
                t.id, t.requirement_id, t.name, t.description, t.is_active,
                t.created_by, t.created_at, t.updated_at,
                r.name AS requirement_name,
                r.category AS requirement_category,
                (SELECT COUNT(*) FROM template_versions tv WHERE tv.template_id = t.id) AS version_count,
                (SELECT tv2.id FROM template_versions tv2 WHERE tv2.template_id = t.id AND tv2.is_current = 1 LIMIT 1) AS current_version_id,
                (SELECT tv2.version_number FROM template_versions tv2 WHERE tv2.template_id = t.id AND tv2.is_current = 1 LIMIT 1) AS current_version_number,
                (SELECT tv2.file_name FROM template_versions tv2 WHERE tv2.template_id = t.id AND tv2.is_current = 1 LIMIT 1) AS current_file_name
            FROM document_templates t
            LEFT JOIN document_requirements r ON t.requirement_id = r.id
            ${where}
            ORDER BY t.name ASC
        `).all(params);

        res.json(templates);
    } catch (err) {
        console.error('getTemplates error:', err);
        res.status(500).json({ message: 'Failed to fetch templates', error: err.message });
    }
};

// ── GET /api/templates/:id ────────────────────────────────────────────────────
exports.getTemplateById = (req, res) => {
    try {
        const template = db.prepare(`
            SELECT
                t.id, t.requirement_id, t.name, t.description, t.is_active,
                t.created_by, t.created_at, t.updated_at,
                r.name AS requirement_name, r.category AS requirement_category
            FROM document_templates t
            LEFT JOIN document_requirements r ON t.requirement_id = r.id
            WHERE t.id = ?
        `).get(req.params.id);

        if (!template) return res.status(404).json({ message: 'Template not found' });

        const versions = db.prepare(`
            SELECT tv.id, tv.version_number, tv.file_name, tv.file_size, tv.is_current,
                   tv.uploaded_by, tv.created_at,
                   u.first_name || ' ' || u.last_name AS uploaded_by_name
            FROM template_versions tv
            LEFT JOIN users u ON tv.uploaded_by = u.id
            WHERE tv.template_id = ?
            ORDER BY tv.version_number DESC
        `).all(req.params.id);

        res.json({ ...template, versions });
    } catch (err) {
        console.error('getTemplateById error:', err);
        res.status(500).json({ message: 'Failed to fetch template', error: err.message });
    }
};

// ── GET /api/templates/:id/versions ──────────────────────────────────────────
exports.getTemplateVersions = (req, res) => {
    try {
        const versions = db.prepare(`
            SELECT tv.id, tv.version_number, tv.file_name, tv.file_size, tv.is_current,
                   tv.uploaded_by, tv.created_at,
                   u.first_name || ' ' || u.last_name AS uploaded_by_name
            FROM template_versions tv
            LEFT JOIN users u ON tv.uploaded_by = u.id
            WHERE tv.template_id = ?
            ORDER BY tv.version_number DESC
        `).all(req.params.id);

        res.json(versions);
    } catch (err) {
        console.error('getTemplateVersions error:', err);
        res.status(500).json({ message: 'Failed to fetch versions', error: err.message });
    }
};

// ── POST /api/templates ───────────────────────────────────────────────────────
exports.createTemplate = (req, res) => {
    const { name, description, requirementId, isActive = true } = req.body;
    if (!name || !name.trim()) {
        return res.status(400).json({ message: 'Template name is required' });
    }

    try {
        const result = db.prepare(`
            INSERT INTO document_templates (requirement_id, name, description, is_active, created_by)
            VALUES (?, ?, ?, ?, ?)
        `).run(
            requirementId ?? null,
            name.trim(),
            description?.trim() ?? null,
            isActive ? 1 : 0,
            req.user?.id ?? null
        );

        const templateId = result.lastInsertRowid;

        // If a file was uploaded, create Version 1
        if (req.file) {
            // Move file from 'new' dir to real template dir
            const newDir = path.join(TEMPLATES_DIR, String(templateId));
            if (!fs.existsSync(newDir)) fs.mkdirSync(newDir, { recursive: true });
            const destPath = path.join(newDir, req.file.filename);
            fs.renameSync(req.file.path, destPath);

            const fileSize = fs.existsSync(destPath) ? fs.statSync(destPath).size : null;

            db.prepare(`
                INSERT INTO template_versions (template_id, version_number, file_name, file_path, file_size, uploaded_by, is_current)
                VALUES (?, 1, ?, ?, ?, ?, 1)
            `).run(templateId, req.file.originalname, destPath, fileSize, req.user?.id ?? null);
        }

        logActivity(req.user?.id, 'CREATE', 'template', templateId, `Created template: ${name}`);
        res.status(201).json({ id: templateId, message: 'Template created successfully' });
    } catch (err) {
        console.error('createTemplate error:', err);
        if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
        res.status(500).json({ message: 'Failed to create template', error: err.message });
    }
};

// ── PATCH /api/templates/:id ──────────────────────────────────────────────────
exports.updateTemplate = (req, res) => {
    const { name, description, requirementId, isActive } = req.body;
    try {
        const existing = db.prepare('SELECT id FROM document_templates WHERE id = ?').get(req.params.id);
        if (!existing) return res.status(404).json({ message: 'Template not found' });

        const fields = [];
        const params = [];

        if (name !== undefined) { fields.push('name = ?'); params.push(name.trim()); }
        if (description !== undefined) { fields.push('description = ?'); params.push(description?.trim() ?? null); }
        if (requirementId !== undefined) { fields.push('requirement_id = ?'); params.push(requirementId ?? null); }
        if (isActive !== undefined) { fields.push('is_active = ?'); params.push(isActive ? 1 : 0); }

        if (fields.length === 0) return res.status(400).json({ message: 'No fields to update' });

        fields.push("updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now')");
        params.push(req.params.id);

        db.prepare(`UPDATE document_templates SET ${fields.join(', ')} WHERE id = ?`).run(...params);
        logActivity(req.user?.id, 'UPDATE', 'template', req.params.id, `Updated template id ${req.params.id}`);
        res.json({ message: 'Template updated successfully' });
    } catch (err) {
        console.error('updateTemplate error:', err);
        res.status(500).json({ message: 'Failed to update template', error: err.message });
    }
};

// ── POST /api/templates/:id/upload-version ────────────────────────────────────
exports.uploadTemplateVersion = (req, res) => {
    if (!req.file) return res.status(400).json({ message: 'No file uploaded' });

    try {
        const templateId = parseInt(req.params.id, 10);
        const template = db.prepare('SELECT id FROM document_templates WHERE id = ?').get(templateId);
        if (!template) {
            fs.unlinkSync(req.file.path);
            return res.status(404).json({ message: 'Template not found' });
        }

        // Get next version number
        const lastVersion = db.prepare(
            'SELECT MAX(version_number) AS max_v FROM template_versions WHERE template_id = ?'
        ).get(templateId);
        const nextVersion = (lastVersion?.max_v ?? 0) + 1;

        // Move file to correct location
        const destDir = path.join(TEMPLATES_DIR, String(templateId));
        if (!fs.existsSync(destDir)) fs.mkdirSync(destDir, { recursive: true });
        const destPath = path.join(destDir, req.file.filename);
        if (req.file.path !== destPath) fs.renameSync(req.file.path, destPath);

        const fileSize = fs.existsSync(destPath) ? fs.statSync(destPath).size : null;

        db.transaction(() => {
            // Unset current flag on previous versions
            db.prepare('UPDATE template_versions SET is_current = 0 WHERE template_id = ?').run(templateId);
            // Insert new version
            db.prepare(`
                INSERT INTO template_versions (template_id, version_number, file_name, file_path, file_size, uploaded_by, is_current)
                VALUES (?, ?, ?, ?, ?, ?, 1)
            `).run(templateId, nextVersion, req.file.originalname, destPath, fileSize, req.user?.id ?? null);
            // Update template updated_at
            db.prepare("UPDATE document_templates SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?").run(templateId);
        })();

        logActivity(req.user?.id, 'CREATE', 'template_version', templateId,
            `Uploaded version ${nextVersion} for template id ${templateId}`);
        res.status(201).json({ message: `Template version ${nextVersion} uploaded successfully`, version_number: nextVersion });
    } catch (err) {
        console.error('uploadTemplateVersion error:', err);
        if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
        res.status(500).json({ message: 'Failed to upload template version', error: err.message });
    }
};

// ── GET /api/templates/:id/download ──────────────────────────────────────────
// Downloads the current (latest) version of the template file
exports.downloadTemplate = (req, res) => {
    try {
        const version = db.prepare(`
            SELECT tv.file_path, tv.file_name
            FROM template_versions tv
            WHERE tv.template_id = ? AND tv.is_current = 1
            LIMIT 1
        `).get(req.params.id);

        if (!version) return res.status(404).json({ message: 'No current template version found' });
        if (!fs.existsSync(version.file_path)) {
            return res.status(404).json({ message: 'Template file not found on disk' });
        }

        res.download(version.file_path, version.file_name);
    } catch (err) {
        console.error('downloadTemplate error:', err);
        res.status(500).json({ message: 'Failed to download template', error: err.message });
    }
};

// ── GET /api/template-versions/:versionId/download ───────────────────────────
exports.downloadTemplateVersion = (req, res) => {
    try {
        const version = db.prepare(
            'SELECT file_path, file_name FROM template_versions WHERE id = ?'
        ).get(req.params.versionId);

        if (!version) return res.status(404).json({ message: 'Template version not found' });
        if (!fs.existsSync(version.file_path)) {
            return res.status(404).json({ message: 'File not found on disk' });
        }

        res.download(version.file_path, version.file_name);
    } catch (err) {
        console.error('downloadTemplateVersion error:', err);
        res.status(500).json({ message: 'Failed to download template version', error: err.message });
    }
};

// ── DELETE /api/templates/:id ─────────────────────────────────────────────────
exports.deleteTemplate = (req, res) => {
    try {
        const template = db.prepare('SELECT id, name FROM document_templates WHERE id = ?').get(req.params.id);
        if (!template) return res.status(404).json({ message: 'Template not found' });

        // Remove all version files from disk
        const versions = db.prepare('SELECT file_path FROM template_versions WHERE template_id = ?').all(req.params.id);
        for (const v of versions) {
            if (v.file_path && fs.existsSync(v.file_path)) {
                try { fs.unlinkSync(v.file_path); } catch (_) {}
            }
        }

        db.prepare('DELETE FROM document_templates WHERE id = ?').run(req.params.id);
        logActivity(req.user?.id, 'DELETE', 'template', req.params.id, `Deleted template: ${template.name}`);
        res.json({ message: 'Template deleted' });
    } catch (err) {
        console.error('deleteTemplate error:', err);
        res.status(500).json({ message: 'Failed to delete template', error: err.message });
    }
};
