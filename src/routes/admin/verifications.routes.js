const express = require('express');
const router = express.Router();
const controller = require('../../controllers/admin/verifications.controller');

router.get('/', controller.getAllVerifications);
router.post('/:userId/revoke', controller.revokeVerification);

module.exports = router;
