const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

// All routes require authentication + role guard
router.get('/', authenticateToken, authorizeRoles('super_admin', 'admin'), userController.getUsers);
router.post('/', authenticateToken, authorizeRoles('super_admin'), userController.createUser);
router.put('/:id', authenticateToken, authorizeRoles('super_admin'), userController.updateUser);
router.put('/:id/reset-password', authenticateToken, authorizeRoles('super_admin'), userController.resetPassword);
router.delete('/:id', authenticateToken, authorizeRoles('super_admin'), userController.deleteUser);

module.exports = router;
