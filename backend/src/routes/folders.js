const express = require('express');
const router = express.Router();
const folderController = require('../controllers/folderController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

// Public routes (with auth)
router.get('/', authenticateToken, folderController.getFolders);
router.get('/student/:studentId', authenticateToken, folderController.getStudentFolder);
router.post('/sync', authenticateToken, authorizeRoles('admin'), folderController.syncFolders);

// Admin & Teacher routes
router.post('/', authenticateToken, authorizeRoles('admin', 'teacher'), folderController.createFolder);
router.put('/:id', authenticateToken, authorizeRoles('admin', 'teacher'), folderController.renameFolder);
router.delete('/:id', authenticateToken, authorizeRoles('admin', 'teacher'), folderController.deleteFolder);

module.exports = router;