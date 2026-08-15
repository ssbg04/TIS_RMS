const express = require('express');
const router = express.Router();
const documentController = require('../controllers/documentController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

router.get('/', authenticateToken, documentController.getAllDocuments);
router.get('/requirements', authenticateToken, documentController.getRequirements);
router.get('/statuses', authenticateToken, documentController.getStatuses);

// Print Queue routes — must be BEFORE /:id routes to avoid conflict
router.get('/print-queue', authenticateToken, authorizeRoles('admin'), documentController.getPrintQueue);
router.get('/print-history', authenticateToken, authorizeRoles('admin'), documentController.getPrintHistory);
router.delete('/print-history/clear', authenticateToken, authorizeRoles('admin'), documentController.clearPrintHistory);
router.post('/print-queue', authenticateToken, authorizeRoles('admin'), documentController.addToPrintQueue);
router.post('/print-queue/print', authenticateToken, authorizeRoles('admin'), documentController.executePrintQueue);
router.delete('/print-queue/clear', authenticateToken, authorizeRoles('admin'), documentController.clearPrintQueue);
router.delete('/print-queue/:queueId', authenticateToken, authorizeRoles('admin'), documentController.removeFromPrintQueue);

router.post('/upload', authenticateToken, authorizeRoles('admin'), documentController.uploadMiddleware, documentController.uploadDocument);
router.get('/student/:studentId', authenticateToken, documentController.getDocumentsByStudent);

// Recycle Bin / Trash routes — must be BEFORE /:id routes
router.get('/trash', authenticateToken, documentController.getTrashDocuments);
router.post('/bulk-restore', authenticateToken, authorizeRoles('admin'), documentController.bulkRestore);
router.post('/bulk-permanent-delete', authenticateToken, authorizeRoles('admin'), documentController.bulkPermanentDelete);

// Bulk routes — must be BEFORE /:id routes to avoid conflict
router.post('/bulk-delete', authenticateToken, authorizeRoles('admin'), documentController.bulkDelete);
router.post('/bulk-status', authenticateToken, authorizeRoles('admin'), documentController.bulkStatus);
router.post('/bulk-print', authenticateToken, authorizeRoles('admin'), documentController.bulkAddToPrintQueue);
router.post('/bulk-copy', authenticateToken, authorizeRoles('admin'), documentController.bulkCopy);

router.get('/:id/view', authenticateToken, documentController.viewDocument);
router.post('/:id/copy', authenticateToken, authorizeRoles('admin'), documentController.copyDocument);
router.patch('/:id/status', authenticateToken, authorizeRoles('admin'), documentController.updateStatus);
router.post('/:id/restore', authenticateToken, authorizeRoles('admin'), documentController.restoreDocument);
router.delete('/:id/permanent', authenticateToken, authorizeRoles('admin'), documentController.permanentDeleteDocument);
router.delete('/:id', authenticateToken, authorizeRoles('admin'), documentController.deleteDocument);

module.exports = router;
