const express = require('express');
const router = express.Router();
const authMiddleware = require('../middlewares/auth');
const callController = require('../controllers/call.controller');

router.get('/history', authMiddleware, callController.getCallHistory);

module.exports = router;
