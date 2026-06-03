const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

// All routes require authentication + role guard
router.get('/',                  authenticateToken, authorizeRoles('admin'), userController.getUsers);
router.post('/',                 authenticateToken, authorizeRoles('admin'), userController.createUser);
router.put('/:id',               authenticateToken, authorizeRoles('admin'), userController.updateUser);
router.put('/:id/reset-password',authenticateToken, authorizeRoles('admin'), userController.resetPassword);
router.delete('/:id',            authenticateToken, authorizeRoles('admin'), userController.deleteUser);

// Teacher Sections
router.get('/:teacherId/sections', authenticateToken, authorizeRoles('admin'), userController.getTeacherSections);
router.post('/:teacherId/sections',authenticateToken, authorizeRoles('admin'), userController.updateTeacherSections);

// User History (admin only — dashboard access)
router.get('/history', authenticateToken, authorizeRoles('admin'), userController.getUserHistory);

module.exports = router;

