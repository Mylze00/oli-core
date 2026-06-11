const express = require('express');
const router = express.Router();
const callController = require('../controllers/call.controller');

router.get('/history', callController.getCallHistory);

module.exports = router;
