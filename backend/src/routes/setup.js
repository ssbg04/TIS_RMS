const express = require('express');
const router = express.Router();
const setupController = require('../controllers/setupController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

router.get('/academic-years', authenticateToken, setupController.getAllAcademicYears);
router.post('/academic-years', authenticateToken, authorizeRoles('super_admin', 'admin'), setupController.createAcademicYear);
router.get('/academic-years/:yearId/sections', authenticateToken, setupController.getSectionsByYear);
router.post('/sections', authenticateToken, authorizeRoles('super_admin', 'admin'), setupController.createSection);

module.exports = router;
