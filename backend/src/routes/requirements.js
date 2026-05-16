const express = require('express');
const router = express.Router();
const requirementController = require('../controllers/requirementController');
const { authenticateToken, authorizeRoles } = require('../middleware/auth');

// Public routes (all authenticated users)
router.get('/', authenticateToken, requirementController.getRequirements);
router.get('/settings', authenticateToken, requirementController.getRequirementsSettings);
router.get('/missing/:studentId', authenticateToken, requirementController.getMissingRequirements);
router.get('/:id', authenticateToken, requirementController.getRequirementById);

// Super Admin routes only
router.post('/', authenticateToken, authorizeRoles('super_admin'), requirementController.createRequirement);
router.put('/bulk', authenticateToken, authorizeRoles('super_admin'), requirementController.bulkUpdateRequirements);
router.put('/:id', authenticateToken, authorizeRoles('super_admin'), requirementController.updateRequirement);
router.delete('/:id', authenticateToken, authorizeRoles('super_admin'), requirementController.deleteRequirement);

module.exports = router;