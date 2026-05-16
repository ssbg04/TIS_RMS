const express = require('express');
const router = express.Router();
const folderController = require('../controllers/folderController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

// Public routes (with auth)
router.get('/', authenticateToken, folderController.getFolders);
router.get('/student/:studentId', authenticateToken, folderController.getStudentFolder);
router.post('/sync', authenticateToken, authorizeRoles('super_admin', 'admin'), folderController.syncFolders);

// Admin/Super Admin routes
router.post('/', authenticateToken, authorizeRoles('super_admin', 'admin'), folderController.createFolder);
router.put('/:id', authenticateToken, authorizeRoles('super_admin', 'admin'), folderController.renameFolder);
router.delete('/:id', authenticateToken, authorizeRoles('super_admin', 'admin'), folderController.deleteFolder);

module.exports = router;