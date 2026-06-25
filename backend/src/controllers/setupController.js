const db = require('../config/db');

// ============================================================
// ACADEMIC YEAR AUTOMATION
// ============================================================

// Auto-seeds this school year and next if they don't exist,
// and ensures exactly one year (the most recent) stays active.
exports.ensureCurrentAcademicYears = () => {
    try {
        const now = new Date();
        // Philippine school year starts in June; if we're before June, current SY started last year
        const currentStartYear = now.getMonth() >= 5 ? now.getFullYear() : now.getFullYear() - 1;
        const currentYearRange = `${currentStartYear}-${currentStartYear + 1}`;
        const nextYearRange = `${currentStartYear + 1}-${currentStartYear + 2}`;

        const insertYear = db.prepare(
            'INSERT OR IGNORE INTO academic_years (year_range, status) VALUES (?, \'inactive\')'
        );

        // Insert current and next year if missing (as inactive, then we activate current)
        insertYear.run(currentYearRange);
        insertYear.run(nextYearRange);

        // Check if any year is currently active
        const activeYear = db.prepare("SELECT id FROM academic_years WHERE status = 'active'").get();
        if (!activeYear) {
            // Activate the current school year
            const currentRow = db.prepare("SELECT id FROM academic_years WHERE year_range = ?").get(currentYearRange);
            if (currentRow) {
                db.prepare("UPDATE academic_years SET status = 'active' WHERE id = ?").run(currentRow.id);
                console.log(`[AcademicYear] Activated ${currentYearRange}`);
            }
        }

        console.log(`[AcademicYear] Ensured years: ${currentYearRange} (active), ${nextYearRange} (next)`);
    } catch (err) {
        console.error('[AcademicYear] Failed to ensure current academic years:', err.message);
    }
};

// Deactivates all academic years except the given id
const deactivateOtherYears = (activeId) => {
    db.prepare("UPDATE academic_years SET status = 'inactive' WHERE id != ?").run(activeId);
};

// ============================================================
// ACADEMIC YEARS CRUD
// ============================================================

exports.getAllAcademicYears = (req, res) => {
    try {
        const years = db.prepare('SELECT * FROM academic_years ORDER BY year_range DESC').all();
        res.json(years);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch academic years', error: error.message });
    }
};

exports.createAcademicYear = (req, res) => {
    const { yearRange, status } = req.body;
    if (!yearRange || !yearRange.trim()) {
        return res.status(400).json({ message: 'yearRange is required' });
    }
    try {
        // Old academic years for manual adds default to inactive
        const finalStatus = status || 'inactive';
        const result = db.prepare('INSERT INTO academic_years (year_range, status) VALUES (?, ?)')
            .run(yearRange.trim(), finalStatus);
        // If the new year is active, deactivate all others
        if (finalStatus === 'active') {
            deactivateOtherYears(result.lastInsertRowid);
        }
        res.status(201).json({ id: result.lastInsertRowid, message: 'Academic year created successfully' });
    } catch (error) {
        if (error.message && error.message.includes('UNIQUE')) {
            return res.status(409).json({ message: `Academic year "${yearRange}" already exists.` });
        }
        res.status(500).json({ message: 'Failed to create academic year', error: error.message });
    }
};

exports.updateAcademicYear = (req, res) => {
    const { id } = req.params;
    const { yearRange, status } = req.body;
    
    if (!yearRange || !yearRange.trim()) {
        return res.status(400).json({ message: 'yearRange is required' });
    }
    if (status && !['active', 'inactive'].includes(status)) {
        return res.status(400).json({ message: 'Invalid status value. Must be active or inactive' });
    }

    try {
        const year = db.prepare('SELECT id FROM academic_years WHERE id = ?').get(id);
        if (!year) return res.status(404).json({ message: 'Academic year not found' });

        const finalStatus = status || 'inactive';
        db.prepare('UPDATE academic_years SET year_range = ?, status = ? WHERE id = ?')
            .run(yearRange.trim(), finalStatus, id);
        // If activated, deactivate all other years automatically
        if (finalStatus === 'active') {
            deactivateOtherYears(parseInt(id));
        }
        res.json({ message: 'Academic year updated successfully' });
    } catch (error) {
        if (error.message && error.message.includes('UNIQUE')) {
            return res.status(409).json({ message: `Academic year "${yearRange}" already exists.` });
        }
        res.status(500).json({ message: 'Failed to update academic year', error: error.message });
    }
};

exports.deleteAcademicYear = (req, res) => {
    const { id } = req.params;
    try {
        const year = db.prepare('SELECT id FROM academic_years WHERE id = ?').get(id);
        if (!year) return res.status(404).json({ message: 'Academic year not found' });

        db.prepare('DELETE FROM academic_years WHERE id = ?').run(id);
        res.json({ message: 'Academic year deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to delete academic year', error: error.message });
    }
};

// ============================================================
// SECTIONS CRUD
// ============================================================

exports.getAllSections = (req, res) => {
    try {
        const sections = db.prepare(`
            SELECT s.*, ay.year_range as academic_year_range
            FROM sections s
            LEFT JOIN academic_years ay ON s.academic_year_id = ay.id
            ORDER BY ay.year_range DESC, s.grade_level ASC, s.name ASC
        `).all();
        res.json(sections);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch sections', error: error.message });
    }
};

exports.getSectionsByYear = (req, res) => {
    try {
        const sections = db.prepare('SELECT * FROM sections WHERE academic_year_id = ? ORDER BY grade_level ASC, name ASC').all(req.params.yearId);
        res.json(sections);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch sections', error: error.message });
    }
};

exports.createSection = (req, res) => {
    const { name, gradeLevel, academicYearId } = req.body;
    if (!name || !name.trim() || !gradeLevel || !academicYearId) {
        return res.status(400).json({ message: 'name, gradeLevel, and academicYearId are required' });
    }
    try {
        const result = db.prepare('INSERT INTO sections (name, grade_level, academic_year_id) VALUES (?, ?, ?)')
            .run(name.trim(), gradeLevel, academicYearId);
        res.status(201).json({ id: result.lastInsertRowid, message: 'Section created successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to create section', error: error.message });
    }
};

exports.updateSection = (req, res) => {
    const { id } = req.params;
    const { name, gradeLevel, academicYearId } = req.body;

    if (!name || !name.trim() || !gradeLevel || !academicYearId) {
        return res.status(400).json({ message: 'name, gradeLevel, and academicYearId are required' });
    }

    try {
        const section = db.prepare('SELECT id FROM sections WHERE id = ?').get(id);
        if (!section) return res.status(404).json({ message: 'Section not found' });

        db.prepare('UPDATE sections SET name = ?, grade_level = ?, academic_year_id = ? WHERE id = ?')
            .run(name.trim(), gradeLevel, academicYearId, id);
        res.json({ message: 'Section updated successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to update section', error: error.message });
    }
};

exports.deleteSection = (req, res) => {
    const { id } = req.params;
    try {
        const section = db.prepare('SELECT id FROM sections WHERE id = ?').get(id);
        if (!section) return res.status(404).json({ message: 'Section not found' });

        db.prepare('DELETE FROM sections WHERE id = ?').run(id);
        res.json({ message: 'Section deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to delete section', error: error.message });
    }
};

// ============================================================
// GRADE LEVELS CRUD
// ============================================================

exports.getAllGradeLevels = (req, res) => {
    try {
        const grades = db.prepare('SELECT * FROM grade_levels ORDER BY level ASC').all();
        res.json(grades);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch grade levels', error: error.message });
    }
};

exports.createGradeLevel = (req, res) => {
    const { level, name } = req.body;
    if (!level || !name || !name.trim()) {
        return res.status(400).json({ message: 'level (integer) and name are required' });
    }
    try {
        const result = db.prepare('INSERT INTO grade_levels (level, name) VALUES (?, ?)')
            .run(level, name.trim());
        res.status(201).json({ id: result.lastInsertRowid, message: 'Grade level created successfully' });
    } catch (error) {
        if (error.message && error.message.includes('UNIQUE')) {
            return res.status(409).json({ message: `Grade level ${level} already exists.` });
        }
        res.status(500).json({ message: 'Failed to create grade level', error: error.message });
    }
};

// PUT /api/setup/grade-levels/:id
exports.updateGradeLevel = (req, res) => {
    const { id } = req.params;
    const { level, name } = req.body;

    if (!level || !name || !name.trim()) {
        return res.status(400).json({ message: 'level (integer) and name are required' });
    }

    try {
        const grade = db.prepare('SELECT id FROM grade_levels WHERE id = ?').get(id);
        if (!grade) return res.status(404).json({ message: 'Grade level not found' });

        db.prepare('UPDATE grade_levels SET level = ?, name = ? WHERE id = ?')
            .run(level, name.trim(), id);
        res.json({ message: 'Grade level updated successfully' });
    } catch (error) {
        if (error.message && error.message.includes('UNIQUE')) {
            return res.status(409).json({ message: `Grade level ${level} already exists.` });
        }
        res.status(500).json({ message: 'Failed to update grade level', error: error.message });
    }
};

// DELETE /api/setup/grade-levels/:id
exports.deleteGradeLevel = (req, res) => {
    const { id } = req.params;
    try {
        const grade = db.prepare('SELECT id FROM grade_levels WHERE id = ?').get(id);
        if (!grade) return res.status(404).json({ message: 'Grade level not found' });

        db.prepare('DELETE FROM grade_levels WHERE id = ?').run(id);
        res.json({ message: 'Grade level deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to delete grade level', error: error.message });
    }
};
