const express = require('express');
const router = express.Router();
const setupController = require('../controllers/setupController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

// ==========================================
// ACADEMIC YEARS
// ==========================================
router.get('/academic-years', authenticateToken, setupController.getAllAcademicYears);
router.post('/academic-years', authenticateToken, authorizeRoles('admin'), setupController.createAcademicYear);
router.put('/academic-years/:id', authenticateToken, authorizeRoles('admin'), setupController.updateAcademicYear);
router.delete('/academic-years/:id', authenticateToken, authorizeRoles('admin'), setupController.deleteAcademicYear);

// ==========================================
// SECTIONS
// ==========================================
router.get('/sections', authenticateToken, setupController.getAllSections);
router.get('/academic-years/:yearId/sections', authenticateToken, setupController.getSectionsByYear);
router.post('/sections', authenticateToken, authorizeRoles('admin'), setupController.createSection);
router.put('/sections/:id', authenticateToken, authorizeRoles('admin'), setupController.updateSection);
router.delete('/sections/:id', authenticateToken, authorizeRoles('admin'), setupController.deleteSection);

// ==========================================
// GRADE LEVELS
// ==========================================
router.get('/grade-levels', authenticateToken, setupController.getAllGradeLevels);
router.post('/grade-levels', authenticateToken, authorizeRoles('admin'), setupController.createGradeLevel);
router.put('/grade-levels/:id', authenticateToken, authorizeRoles('admin'), setupController.updateGradeLevel);
router.delete('/grade-levels/:id', authenticateToken, authorizeRoles('admin'), setupController.deleteGradeLevel);

module.exports = router;
