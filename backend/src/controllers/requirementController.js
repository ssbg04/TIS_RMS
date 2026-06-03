const db = require('../config/db');

// ============================================================
// GET /api/requirements — get all document requirements
// ============================================================
exports.getRequirements = (req, res) => {
    const { category, isMandatory, isEnabled, search = '' } = req.query;

    try {
        const conditions = [];
        const params = [];

        if (category) {
            conditions.push('category = ?');
            params.push(category);
        }

        if (isEnabled !== undefined && isEnabled !== '') {
            conditions.push('is_enabled = ?');
            params.push(isEnabled === 'true' ? 1 : 0);
        }

        if (isMandatory !== undefined && isMandatory !== '') {
            conditions.push('is_mandatory = ?');
            params.push(isMandatory === 'true' ? 1 : 0);
        }

        if (search.trim()) {
            conditions.push('(name LIKE ? OR description LIKE ?)');
            params.push(`%${search.trim()}%`, `%${search.trim()}%`);
        }

        const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

        const sql = `
            SELECT id, category || ' - ' || name as name, description, category, is_mandatory, is_enabled, due_date, accepted_file_types, school_levels, created_at, updated_at
            FROM document_requirements
            ${whereClause}
            ORDER BY category ASC, name ASC
        `;

        const requirements = db.prepare(sql).all(params);
        res.json(requirements);
    } catch (error) {
        console.error('getRequirements error:', error);
        res.status(500).json({ message: 'Failed to fetch requirements', error: error.message });
    }
};

// ============================================================
// GET /api/requirements/:id — get single requirement
// ============================================================
exports.getRequirementById = (req, res) => {
    try {
        const requirement = db.prepare('SELECT * FROM document_requirements WHERE id = ?').get(req.params.id);
        if (!requirement) {
            return res.status(404).json({ message: 'Requirement not found' });
        }
        res.json(requirement);
    } catch (error) {
        console.error('getRequirementById error:', error);
        res.status(500).json({ message: 'Failed to fetch requirement', error: error.message });
    }
};

// ============================================================
// POST /api/requirements — create new requirement (Super Admin)
// ============================================================
exports.createRequirement = (req, res) => {
    const {
        name,
        description,
        category,
        isMandatory = true,
        isEnabled = true,
        dueDate,
        acceptedFileTypes = 'pdf,jpg,jpeg,png',
        schoolLevels = 'JHS,SHS'
    } = req.body;

    // Validation
    const errors = [];
    if (!name || !name.trim()) errors.push('Name is required');
    if (!category || !['JHS', 'SHS'].includes(category)) errors.push('Category must be JHS or SHS');

    if (errors.length) {
        return res.status(400).json({ message: errors[0], errors });
    }

    // Check duplicate
    const existing = db.prepare('SELECT id FROM document_requirements WHERE name = ? AND category = ?')
        .get(name.trim(), category);
    if (existing) {
        return res.status(409).json({ message: 'A requirement with this name already exists for this category' });
    }

    try {
        const result = db.prepare(`
            INSERT INTO document_requirements (
                name, description, category, is_mandatory, is_enabled,
                due_date, accepted_file_types, school_levels
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
            name.trim(),
            description?.trim() || null,
            category,
            isMandatory ? 1 : 0,
            isEnabled ? 1 : 0,
            dueDate || null,
            acceptedFileTypes,
            schoolLevels
        );

        res.status(201).json({
            id: result.lastInsertRowid,
            message: 'Requirement created successfully'
        });
    } catch (error) {
        console.error('createRequirement error:', error);
        res.status(500).json({ message: 'Failed to create requirement', error: error.message });
    }
};

// ============================================================
// PUT /api/requirements/:id — update requirement (Super Admin)
// ============================================================
exports.updateRequirement = (req, res) => {
    const { id } = req.params;
    const {
        name,
        description,
        category,
        isMandatory,
        isEnabled,
        dueDate,
        acceptedFileTypes,
        schoolLevels
    } = req.body;

    const requirement = db.prepare('SELECT * FROM document_requirements WHERE id = ?').get(id);
    if (!requirement) {
        return res.status(404).json({ message: 'Requirement not found' });
    }

    // Check duplicate if name or category changed
    if ((name && name.trim() !== requirement.name) || (category && category !== requirement.category)) {
        const duplicate = db.prepare('SELECT id FROM document_requirements WHERE name = ? AND category = ? AND id != ?')
            .get(name?.trim() || requirement.name, category || requirement.category, id);
        if (duplicate) {
            return res.status(409).json({ message: 'A requirement with this name already exists for this category' });
        }
    }

    try {
        db.prepare(`
            UPDATE document_requirements SET
                name = COALESCE(?, name),
                description = COALESCE(?, description),
                category = COALESCE(?, category),
                is_mandatory = COALESCE(?, is_mandatory),
                is_enabled = COALESCE(?, is_enabled),
                due_date = ?,
                accepted_file_types = COALESCE(?, accepted_file_types),
                school_levels = COALESCE(?, school_levels),
                updated_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
            WHERE id = ?
        `).run(
            name?.trim(),
            description?.trim(),
            category,
            isMandatory !== undefined ? (isMandatory ? 1 : 0) : null,
            isEnabled !== undefined ? (isEnabled ? 1 : 0) : null,
            dueDate,
            acceptedFileTypes,
            schoolLevels,
            id
        );

        res.json({ message: 'Requirement updated successfully' });
    } catch (error) {
        console.error('updateRequirement error:', error);
        res.status(500).json({ message: 'Failed to update requirement', error: error.message });
    }
};

// ============================================================
// DELETE /api/requirements/:id — delete requirement (Super Admin)
// ============================================================
exports.deleteRequirement = (req, res) => {
    const { id } = req.params;

    const requirement = db.prepare('SELECT * FROM document_requirements WHERE id = ?').get(id);
    if (!requirement) {
        return res.status(404).json({ message: 'Requirement not found' });
    }

    // Check if any documents are linked to this requirement
    const linkedDocs = db.prepare('SELECT COUNT(*) as count FROM documents WHERE requirement_id = ?').get(id);
    if (linkedDocs.count > 0) {
        return res.status(400).json({
            message: 'Cannot delete requirement that has documents attached. Please remove linked documents first.'
        });
    }

    try {
        db.prepare('DELETE FROM document_requirements WHERE id = ?').run(id);
        res.json({ message: 'Requirement deleted successfully' });
    } catch (error) {
        console.error('deleteRequirement error:', error);
        res.status(500).json({ message: 'Failed to delete requirement', error: error.message });
    }
};

// ============================================================
// GET /api/requirements/settings — get requirements for settings panel
// ============================================================
exports.getRequirementsSettings = (req, res) => {
    try {
        // Get JHS requirements
        const jhsRequirements = db.prepare(`
            SELECT * FROM document_requirements
            WHERE category = 'JHS'
            ORDER BY name ASC
        `).all();

        // Get SHS requirements
        const shsRequirements = db.prepare(`
            SELECT * FROM document_requirements
            WHERE category = 'SHS'
            ORDER BY name ASC
        `).all();

        // Get document types for dropdown
        const documentTypes = db.prepare(`
            SELECT DISTINCT category || ' - ' || name as name FROM document_requirements
            ORDER BY name ASC
        `).all();

        res.json({
            jhs: jhsRequirements,
            shs: shsRequirements,
            documentTypes: documentTypes.map(d => d.name)
        });
    } catch (error) {
        console.error('getRequirementsSettings error:', error);
        res.status(500).json({ message: 'Failed to fetch settings', error: error.message });
    }
};

// ============================================================
// PUT /api/requirements/bulk — bulk update requirements (Super Admin)
// ============================================================
exports.bulkUpdateRequirements = (req, res) => {
    const { requirements } = req.body;

    if (!Array.isArray(requirements) || requirements.length === 0) {
        return res.status(400).json({ message: 'Requirements array is required' });
    }

    try {
        const updateStmt = db.prepare(`
            UPDATE document_requirements SET
                is_mandatory = ?,
                is_enabled = ?,
                due_date = ?,
                updated_at = (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
            WHERE id = ?
        `);

        db.transaction(() => {
            for (const req of requirements) {
                if (req.id) {
                    updateStmt.run(
                        req.isMandatory ? 1 : 0,
                        req.isEnabled ? 1 : 0,
                        req.dueDate || null,
                        req.id
                    );
                }
            }
        })();

        res.json({ message: 'Requirements updated successfully' });
    } catch (error) {
        console.error('bulkUpdateRequirements error:', error);
        res.status(500).json({ message: 'Failed to bulk update requirements', error: error.message });
    }
};

// ============================================================
// GET /api/requirements/missing/:studentId — get missing requirements for student
// ============================================================
exports.getMissingRequirements = (req, res) => {
    const { studentId } = req.params;

    try {
        // Get student's current grade level (for highlighting "current level" on the frontend)
        const enrollment = db.prepare(`
            SELECT grade_level FROM enrollments
            WHERE student_id = ?
            ORDER BY id DESC LIMIT 1
        `).get(studentId);

        if (!enrollment) {
            return res.status(404).json({ message: 'Student has no enrollment records' });
        }

        const currentCategory = enrollment.grade_level <= 10 ? 'JHS' : 'SHS';

        // ── Fetch ALL categories so frontend can split into JHS and SHS panels ──
        // Missing = mandatory requirements that have no Completed document yet
        const missing = db.prepare(`
            SELECT dr.id, dr.name, dr.description, dr.category,
                   dr.is_mandatory, dr.is_enabled, dr.due_date,
                   dr.accepted_file_types, dr.school_levels, dr.created_at, dr.updated_at
            FROM document_requirements dr
            WHERE dr.is_mandatory = 1
              AND dr.is_enabled = 1
              AND dr.id NOT IN (
                  SELECT requirement_id FROM documents
                  WHERE student_id = ? AND status IN ('Completed', 'Archived') AND requirement_id IS NOT NULL
              )
            ORDER BY dr.category ASC, dr.name ASC
        `).all(studentId);

        // Verified = requirement has at least one Completed document
        const verified = db.prepare(`
            SELECT DISTINCT dr.id, dr.name, dr.description, dr.category,
                   dr.is_mandatory, dr.is_enabled, dr.due_date,
                   dr.accepted_file_types, dr.school_levels, dr.created_at, dr.updated_at
            FROM document_requirements dr
            JOIN documents d ON d.requirement_id = dr.id
            WHERE d.student_id = ?
              AND d.status IN ('Completed', 'Archived')
            ORDER BY dr.category ASC, dr.name ASC
        `).all(studentId);

        res.json({
            category: currentCategory,
            gradeLevel: enrollment.grade_level,
            missing,
            pending: [],
            verified,
            totalRequired: missing.length + verified.length,
            totalVerified: verified.length
        });
    } catch (error) {
        console.error('getMissingRequirements error:', error);
        res.status(500).json({ message: 'Failed to fetch missing requirements', error: error.message });
    }
};