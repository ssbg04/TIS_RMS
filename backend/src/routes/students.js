const express = require('express');
const router  = express.Router();
const studentController = require('../controllers/studentController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

// All routes require authentication
router.get('/',    authenticateToken, studentController.getAllStudents);
router.get('/:id', authenticateToken, studentController.getStudentById);

// Create / Update / Delete restricted to super_admin & admin
router.post('/',    authenticateToken, authorizeRoles('super_admin', 'admin'), studentController.createStudent);
router.put('/:id',  authenticateToken, authorizeRoles('super_admin', 'admin'), studentController.updateStudent);
router.delete('/:id', authenticateToken, authorizeRoles('super_admin', 'admin'), studentController.deleteStudent);

module.exports = router;
