const express = require('express');
const router = express.Router();
const multer = require('multer');
const settingsController = require('../controllers/settingsController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

const issueAttachmentUpload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 10 * 1024 * 1024, // 10 MB per attachment
        files: 5,
    },
});

router.get('/', authenticateToken, authorizeRoles('admin'), settingsController.getSettings);
router.put('/', authenticateToken, authorizeRoles('admin'), settingsController.updateSettings);
router.post(
    '/report-issue',
    authenticateToken,
    issueAttachmentUpload.array('attachments', 5),
    settingsController.reportIssue
);

module.exports = router;
