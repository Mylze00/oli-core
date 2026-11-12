const express = require('express');
const router = express.Router();
const feedController = require('../controllers/feed.controller');
const { requireAuth, optionalAuth } = require('../middlewares/auth.middleware');
const { genericUpload } = require('../config/upload');

// Note: Certaines routes comme getFeed peuvent être optionnellement sans auth si on veut un fil public,
// mais pour interagir (liker, commenter), l'authentification est requise.

// Récupérer le fil d'actualité (avec pagination)
router.get('/', optionalAuth, feedController.getFeed);

// Créer une publication
router.post('/', requireAuth, genericUpload.single('media'), feedController.createPost);

// Liker / Unliker une publication
router.post('/:id/like', requireAuth, feedController.toggleLike);

// Récupérer les commentaires d'une publication (pas besoin d'auth)
router.get('/:id/comments', optionalAuth, feedController.getComments);
// J'aime sur une réponse
router.post('/comments/:commentId/like', requireAuth, feedController.toggleCommentLike);

// Page « Post » et actions façon X
router.get('/:id', optionalAuth, feedController.getPost);
router.post('/:id/view', optionalAuth, feedController.recordView);
router.post('/:id/repost', requireAuth, feedController.toggleRepost);
router.post('/:id/bookmark', requireAuth, feedController.toggleBookmark);
router.post('/:id/hide', requireAuth, feedController.hidePost);
router.post('/:id/report', requireAuth, feedController.reportPost);
router.get('/:id/interactions', requireAuth, feedController.getInteractions);
router.delete('/:id', requireAuth, feedController.deletePost);

// Ajouter un commentaire à une publication
router.post('/:id/comments', requireAuth, genericUpload.single('media'), feedController.addComment);

module.exports = router;
