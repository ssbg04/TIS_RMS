const express = require('express');
const router = express.Router();
const templateController = require('../controllers/templateController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

// ── Read (all authenticated) ──────────────────────────────────────────────────
router.get('/', authenticateToken, templateController.getTemplates);
router.get('/:id', authenticateToken, templateController.getTemplateById);
router.get('/:id/versions', authenticateToken, templateController.getTemplateVersions);
router.get('/:id/download', authenticateToken, templateController.downloadTemplate);

// ── Admin only ────────────────────────────────────────────────────────────────
router.post(
    '/',
    authenticateToken,
    authorizeRoles('admin'),
    templateController.uploadMiddleware,
    templateController.createTemplate
);
router.patch(
    '/:id',
    authenticateToken,
    authorizeRoles('admin'),
    templateController.updateTemplate
);
router.post(
    '/:id/upload-version',
    authenticateToken,
    authorizeRoles('admin'),
    templateController.uploadMiddleware,
    templateController.uploadTemplateVersion
);
router.delete(
    '/:id',
    authenticateToken,
    authorizeRoles('admin'),
    templateController.deleteTemplate
);

module.exports = router;
