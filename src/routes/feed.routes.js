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
router.get('/:id/comments', feedController.getComments);

// Ajouter un commentaire à une publication
router.post('/:id/comments', requireAuth, feedController.addComment);

module.exports = router;
