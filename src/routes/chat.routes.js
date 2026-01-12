/**
 * Routes Chat Oli
 * Messagerie temps réel - Conversations, Messages, Médias
 */
const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chat.controller');
const { chatUpload } = require('../config/upload');

// --- Routes ---

// Médias
router.post('/upload', chatUpload.single('file'), chatController.uploadFile);

// Conversations & Messages
router.post('/send', chatController.sendInitialMessage);
router.post('/messages', chatController.sendMessage);
router.get('/conversations', chatController.getConversations);
router.get('/messages/:otherUserId', chatController.getMessages);

// Recherche
router.get('/users', chatController.searchUsers);

module.exports = router;