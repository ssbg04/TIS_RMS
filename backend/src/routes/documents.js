const express = require('express');
const router = express.Router();
const documentController = require('../controllers/documentController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

router.get('/', authenticateToken, documentController.getAllDocuments);
router.get('/requirements', authenticateToken, documentController.getRequirements);

// Print Queue routes — must be BEFORE /:id routes to avoid conflict
router.get('/print-queue', authenticateToken, documentController.getPrintQueue);
router.post('/print-queue', authenticateToken, documentController.addToPrintQueue);
router.delete('/print-queue/clear', authenticateToken, documentController.clearPrintQueue);
router.delete('/print-queue/:queueId', authenticateToken, documentController.removeFromPrintQueue);

router.post('/upload', authenticateToken, documentController.uploadMiddleware, documentController.uploadDocument);
router.get('/student/:studentId', authenticateToken, documentController.getDocumentsByStudent);
router.patch('/:id/status', authenticateToken, authorizeRoles('super_admin', 'admin'), documentController.updateStatus);
router.delete('/:id', authenticateToken, authorizeRoles('super_admin', 'admin'), documentController.deleteDocument);

module.exports = router;
