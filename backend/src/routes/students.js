const express = require('express');
const router  = express.Router();
const studentController = require('../controllers/studentController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

// All routes require authentication
router.get('/',    authenticateToken, studentController.getAllStudents);
router.get('/:id', authenticateToken, studentController.getStudentById);

// Create / Update / Delete restricted to super_admin & admin
router.post('/',    authenticateToken, authorizeRoles('admin'), studentController.createStudent);
router.post('/bulk-enroll', authenticateToken, authorizeRoles('admin'), studentController.bulkEnrollStudents);
router.put('/bulk-graduate', authenticateToken, authorizeRoles('admin'), studentController.bulkGraduate);
router.put('/:id',  authenticateToken, authorizeRoles('admin'), studentController.updateStudent);
router.delete('/:id', authenticateToken, authorizeRoles('admin'), studentController.deleteStudent);

module.exports = router;
