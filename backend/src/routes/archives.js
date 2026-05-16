const express = require('express');
const router  = express.Router();
const archiveController = require('../controllers/archiveController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

// All routes require authentication
router.get('/', authenticateToken, archiveController.getArchivedStudents);

// Restore and Purge restricted to super_admin & admin
router.post('/:id/restore', authenticateToken, authorizeRoles('super_admin', 'admin'), archiveController.restoreArchive);
router.delete('/:id', authenticateToken, authorizeRoles('super_admin', 'admin'), archiveController.purgeArchive);

module.exports = router;
