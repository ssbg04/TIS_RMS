const express = require('express');
const router = express.Router();
const reportsController = require('../controllers/reportsController');
const { authenticateToken } = require('../middleware/auth');

router.get('/academic-years', authenticateToken, reportsController.getAcademicYears);
router.get('/stats', authenticateToken, reportsController.getStats);
router.get('/enrollment-by-grade', authenticateToken, reportsController.getEnrollmentByGrade);
router.get('/document-status', authenticateToken, reportsController.getDocumentStatus);
router.get('/export-data', authenticateToken, reportsController.getExportData);

module.exports = router;
