/**
 * Routes Chat Oli
 * Messagerie temps réel - Conversations, Messages, Médias
 */
const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chat.controller');
const chatUploadController = require('../controllers/chat-upload.controller');

// --- Routes ---

const { chatUpload } = require('../config/upload'); // Centralized upload config

// Médias (Via Cloudinary/Local)
router.post('/upload', chatUpload.single('chat_file'), chatUploadController.uploadFile);

// Conversations & Messages
router.post('/send', chatController.sendInitialMessage);
router.post('/messages', chatController.sendMessage);
router.get('/conversations', chatController.getConversations);
router.patch('/conversations/:id/state', chatController.updateConversationState);
router.post('/conversations/:id/read', chatController.markConversationRead);
router.put('/conversations/:id/mute', chatController.setConversationMute);
router.post('/blocks/:userId', chatController.blockUser);
router.delete('/blocks/:userId', chatController.unblockUser);
router.delete('/conversations/:id', chatController.deleteConversationForMe);
router.get('/presence/:userId', chatController.getPresence);
router.get('/messages/:otherUserId', chatController.getMessages);

// Recherche
router.get('/users', chatController.searchUsers);

// Réactions sur un message
router.put('/messages/:messageId/react', chatController.reactToMessage);

module.exports = router;