const express = require('express');
const router = express.Router();
const gradeController = require('../controllers/gradeController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

router.post('/enroll', authenticateToken, authorizeRoles('super_admin', 'admin'), gradeController.enrollStudent);
router.get('/enrollment/:enrollmentId', authenticateToken, gradeController.getGradesByEnrollment);
router.post('/update', authenticateToken, authorizeRoles('super_admin', 'admin'), gradeController.updateGrades);
router.get('/sf10/:studentId', authenticateToken, gradeController.getSF10Data);

module.exports = router;
