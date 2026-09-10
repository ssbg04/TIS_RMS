const express = require('express');
const router  = express.Router();
const archiveController = require('../controllers/archiveController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

// All routes require authentication
router.get('/', authenticateToken, archiveController.getArchivedStudents);

// New document-centric endpoints
router.get('/documents', authenticateToken, archiveController.getArchivedDocuments);
router.get('/student-folders', authenticateToken, archiveController.getArchivedStudentFolders);

// Restore restricted to admin
router.post('/:id/restore', authenticateToken, authorizeRoles('admin'), archiveController.restoreArchive);

module.exports = router;
