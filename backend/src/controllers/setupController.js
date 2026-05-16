const db = require('../config/db');

exports.getAllAcademicYears = (req, res) => {
    try {
        const years = db.prepare('SELECT * FROM academic_years ORDER BY year_range DESC').all();
        res.json(years);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch academic years', error: error.message });
    }
};

exports.createAcademicYear = (req, res) => {
    const { yearRange } = req.body;
    try {
        const result = db.prepare('INSERT INTO academic_years (year_range) VALUES (?)').run(yearRange);
        res.status(201).json({ id: result.lastInsertRowid, message: 'Academic year created' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to create academic year', error: error.message });
    }
};

exports.getSectionsByYear = (req, res) => {
    try {
        const sections = db.prepare('SELECT * FROM sections WHERE academic_year_id = ?').all(req.params.yearId);
        res.json(sections);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch sections', error: error.message });
    }
};

exports.createSection = (req, res) => {
    const { name, gradeLevel, academicYearId } = req.body;
    try {
        const result = db.prepare('INSERT INTO sections (name, grade_level, academic_year_id) VALUES (?, ?, ?)')
            .run(name, gradeLevel, academicYearId);
        res.status(201).json({ id: result.lastInsertRowid, message: 'Section created' });
    } catch (error) {
        res.status(500).json({ message: 'Failed to create section', error: error.message });
    }
};
