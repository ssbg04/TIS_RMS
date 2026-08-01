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
router.post('/bulk-ocr-import', authenticateToken, authorizeRoles('admin'), studentController.bulkCreateStudents);
router.put('/bulk-graduate', authenticateToken, authorizeRoles('admin'), studentController.bulkGraduate);
router.post('/bulk-status', authenticateToken, authorizeRoles('admin'), studentController.bulkStatusStudents);
router.put('/:id',  authenticateToken, authorizeRoles('admin'), studentController.updateStudent);
router.delete('/:id', authenticateToken, authorizeRoles('admin'), studentController.deleteStudent);

router.post('/:id/enrollments', authenticateToken, authorizeRoles('admin'), studentController.addEnrollment);
router.post('/:id/ocr-enrollment', authenticateToken, authorizeRoles('admin'), studentController.scanEnrollmentFromSF);
router.put('/enrollments/:enrollmentId', authenticateToken, authorizeRoles('admin'), studentController.updateEnrollment);
router.delete('/enrollments/:enrollmentId', authenticateToken, authorizeRoles('admin'), studentController.deleteEnrollment);

module.exports = router;
