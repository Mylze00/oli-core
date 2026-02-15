const express = require('express');
const router = express.Router();
const controller = require('../../controllers/admin/verifications.controller');

// Certifiés actifs
router.get('/', controller.getAllVerifications);

// Demandes de certification
router.get('/pending', controller.getPendingRequests);
router.get('/all', controller.getAllRequests);

// Actions admin
router.post('/:id/approve', controller.approveRequest);
router.post('/:id/reject', controller.rejectRequest);
router.post('/:userId/revoke', controller.revokeVerification);

module.exports = router;
