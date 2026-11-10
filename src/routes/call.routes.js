const express = require('express');
const router = express.Router();
const callController = require('../controllers/call.controller');

router.get('/history', callController.getCallHistory);
router.get('/peer/:userId', callController.getCallPeer);
router.post('/:callerId/decline', callController.declineCall);

module.exports = router;
