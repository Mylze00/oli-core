/**
 * Routes Video Sales — Live Shopping MVP
 * Upload, feed, likes, vues
 */
const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middlewares/auth.middleware');
const videoService = require('../services/video-sales.service');
const { genericUpload } = require('../config/upload');

// ─── Auto-migration au démarrage ──────
videoService.ensureTables();

// Les identifiants de vidéo sont des entiers : on refuse le reste avant d'interroger la base
router.param('id', (req, res, next, id) => {
    if (!/^\d+$/.test(id)) {
        return res.status(400).json({ error: 'Identifiant de vidéo invalide' });
    }
    next();
});

/**
 * GET /api/videos
 * Feed paginé de vidéos
 * Query: ?page=1&limit=10
 */
router.get('/', requireAuth, async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = Math.min(parseInt(req.query.limit) || 10, 20);
        const videos = await videoService.getFeed(page, limit, req.user.id);
        res.json({ success: true, videos, page, limit });
    } catch (err) {
        console.error('❌ Erreur feed vidéos:', err.message);
        res.status(500).json({ error: 'Erreur lors du chargement du feed' });
    }
});

/**
 * GET /api/videos/stickers
 * Galerie de stickers des commentaires
 */
router.get('/stickers', requireAuth, async (req, res) => {
    try {
        res.json({ success: true, stickers: await videoService.getStickers() });
    } catch (err) {
        console.error('❌ Erreur stickers:', err.message);
        res.status(500).json({ error: 'Erreur lors du chargement des stickers' });
    }
});

/**
 * POST /api/videos/upload-ticket
 * Autorise l'envoi direct d'une vidéo ou d'un son vers Cloudinary
 * Body: { kind: 'video' | 'audio' }
 */
router.post('/upload-ticket', requireAuth, async (req, res) => {
    try {
        res.json({ success: true, ...await videoService.createUploadTicket(req.user.id, req.body?.kind) });
    } catch (err) {
        if (err.message === 'LIMIT_REACHED') {
            return res.status(403).json({
                error: 'Limite atteinte',
                message: 'Vous avez atteint la limite de 3 vidéos par mois. Obtenez la certification pour un accès illimité.'
            });
        }
        if (err.message === 'INVALID_KIND') {
            return res.status(400).json({ error: 'Type de fichier invalide' });
        }
        if (err.message === 'UPLOAD_UNAVAILABLE') {
            return res.status(503).json({ error: 'Envoi indisponible', message: "L'envoi de vidéos est momentanément indisponible." });
        }
        console.error('❌ Erreur autorisation envoi:', err.message);
        res.status(500).json({ error: "Erreur lors de la préparation de l'envoi" });
    }
});

/**
 * GET /api/videos/creators/:userId
 * Score, statistiques et vidéos d'un créateur
 */
router.get('/creators/:userId', requireAuth, async (req, res) => {
    try {
        if (!/^\d+$/.test(req.params.userId)) {
            return res.status(400).json({ error: 'Identifiant invalide' });
        }
        res.json({ success: true, ...await videoService.getCreatorProfile(req.params.userId, req.user.id) });
    } catch (err) {
        if (err.message === 'NOT_FOUND') {
            return res.status(404).json({ error: 'Créateur introuvable' });
        }
        console.error('❌ Erreur profil créateur:', err.message);
        res.status(500).json({ error: 'Erreur lors du chargement du profil' });
    }
});

/**
 * GET /api/videos/my
 * Mes vidéos
 */
router.get('/my', requireAuth, async (req, res) => {
    try {
        const videos = await videoService.getUserVideos(req.user.id);
        res.json({ success: true, videos });
    } catch (err) {
        console.error('❌ Erreur mes vidéos:', err.message);
        res.status(500).json({ error: 'Erreur lors du chargement' });
    }
});

/**
 * POST /api/videos
 * Upload d'une vidéo de vente
 * Body (multipart): video, audio (optionnel), duration_seconds, product_id, title, description
 */
router.post('/', requireAuth, (req, res, next) => {
    genericUpload.fields([
        { name: 'video', maxCount: 1 },
        { name: 'audio', maxCount: 1 },
    ])(req, res, function (err) {
        if (err) {
            console.error('❌ Multer error in /api/videos:', err);
            return res.status(400).json({ error: "Erreur de fichier", message: err.message });
        }
        next();
    });
}, async (req, res) => {
    try {
        if (req.body?.video_public_id) {
            const media = await videoService.resolveDirectUpload(
                req.user.id, req.body.video_public_id, req.body.audio_public_id
            );
            const video = await videoService.createVideo(
                req.user.id, media.videoUrl, media.thumbnailUrl,
                req.body.product_id, req.body.title, req.body.description, media.durationSeconds
            );
            return res.status(201).json({ success: true, video });
        }

        const videoFile = req.files?.video?.[0];
        const audioFile = req.files?.audio?.[0];
        if (!videoFile) {
            return res.status(400).json({ error: "Erreur d'upload", message: "Aucune vidéo fournie" });
        }

        const videoUrl = videoService.buildPublishedVideoUrl({
            videoUrl: videoFile.path || videoFile.url || videoFile.secure_url || videoFile.location,
            videoBytes: videoFile.size,
            audioPublicId: audioFile?.filename,
            durationSeconds: req.body.duration_seconds,
        });
        const thumbnailUrl = null; // Cloudinary peut générer un thumbnail automatiquement

        const { product_id, title, description } = req.body;

        const video = await videoService.createVideo(
            req.user.id,
            videoUrl,
            thumbnailUrl,
            product_id,
            title,
            description
        );

        res.status(201).json({ success: true, video });
    } catch (err) {
        if (err.message === 'LIMIT_REACHED') {
            return res.status(403).json({
                error: 'Limite atteinte',
                message: 'Vous avez atteint la limite de 3 vidéos par mois. Obtenez la certification pour un accès illimité.'
            });
        }
        if (err.message === 'INVALID_UPLOAD') {
            return res.status(400).json({ error: 'Fichier invalide', message: "La vidéo envoyée est introuvable. Réessayez l'envoi." });
        }
        if (err.message === 'VIDEO_TOO_LARGE') {
            return res.status(400).json({ error: 'Vidéo trop lourde', message: 'La vidéo dépasse 100 Mo.' });
        }
        if (err.message === 'AUDIO_VIDEO_TOO_LARGE') {
            return res.status(400).json({
                error: 'Vidéo trop lourde',
                message: 'Avec un son ajouté, la vidéo doit faire moins de 40 Mo.'
            });
        }
        if (err.message === 'AUDIO_UNAVAILABLE') {
            return res.status(400).json({
                error: 'Son indisponible',
                message: "L'ajout d'un son n'est pas disponible pour le moment."
            });
        }
        if (err.message === 'INVALID_PRODUCT') {
            return res.status(400).json({
                error: 'Produit invalide',
                message: "Ce produit n'existe pas ou n'est plus disponible."
            });
        }
        console.error('❌ Erreur upload vidéo:', err.message);
        console.error('   Stack:', err.stack);
        res.status(500).json({ error: 'Erreur lors de l\'upload', message: err.message });
    }
});

/**
 * POST /api/videos/:id/view
 * Enregistrer une vue (après 3s de lecture)
 */
router.post('/:id/view', requireAuth, async (req, res) => {
    try {
        const result = await videoService.incrementView(req.params.id, req.user.id);
        res.json({ success: true, ...result });
    } catch (err) {
        console.error('❌ Erreur vue vidéo:', err.message);
        res.status(500).json({ error: 'Erreur' });
    }
});

/**
 * POST /api/videos/:id/like
 * Toggle like/unlike
 */
router.post('/:id/like', requireAuth, async (req, res) => {
    try {
        const result = await videoService.toggleLike(req.params.id, req.user.id);
        res.json({ success: true, ...result });
    } catch (err) {
        if (err.message === 'NOT_FOUND') {
            return res.status(404).json({ error: 'Vidéo non disponible' });
        }
        console.error('❌ Erreur like vidéo:', err.message);
        res.status(500).json({ error: 'Erreur' });
    }
});

/**
 * GET /api/videos/:id/comments
 * Commentaires principaux paginés
 * Query: ?page=1&limit=20&sort=recent|top
 */
router.get('/:id/comments', requireAuth, async (req, res) => {
    try {
        const page = Math.max(parseInt(req.query.page) || 1, 1);
        const limit = Math.min(parseInt(req.query.limit) || 20, 50);
        const comments = await videoService.getComments(req.params.id, req.user.id, {
            page,
            limit,
            sort: req.query.sort,
        });
        res.json({ success: true, comments, page, limit });
    } catch (err) {
        console.error('❌ Erreur commentaires vidéo:', err.message);
        res.status(500).json({ error: 'Erreur lors du chargement des commentaires' });
    }
});

/**
 * GET /api/videos/:id/comments/:commentId/replies
 * Réponses à un commentaire
 */
router.get('/:id/comments/:commentId/replies', requireAuth, async (req, res) => {
    try {
        const replies = await videoService.getReplies(req.params.id, req.params.commentId, req.user.id);
        res.json({ success: true, replies });
    } catch (err) {
        console.error('❌ Erreur réponses vidéo:', err.message);
        res.status(500).json({ error: 'Erreur lors du chargement des réponses' });
    }
});

/**
 * POST /api/videos/:id/comments
 * Ajouter un commentaire ou une réponse, avec image facultative
 * Body (JSON ou multipart): content, parent_id, sticker_id, image
 */
router.post('/:id/comments', requireAuth, (req, res, next) => {
    genericUpload.single('image')(req, res, function (err) {
        if (err) {
            console.error('❌ Multer error in /api/videos/:id/comments:', err);
            return res.status(400).json({ error: "L'image n'a pas pu être envoyée" });
        }
        next();
    });
}, async (req, res) => {
    try {
        const image = req.file;
        const isImage = image && (image.mimetype?.startsWith('image/') || image.path?.includes('/image/upload/'));
        if (image && !isImage) {
            return res.status(400).json({ error: 'Seules les images sont acceptées' });
        }

        const comment = await videoService.addComment(req.params.id, req.user.id, req.body?.content, {
            parentId: req.body?.parent_id,
            imageUrl: image ? image.path : null,
            stickerId: req.body?.sticker_id,
        });
        res.status(201).json({ success: true, comment });
    } catch (err) {
        if (err.message === 'INVALID_COMMENT') {
            return res.status(400).json({ error: 'Le commentaire doit contenir un texte de 500 caractères maximum ou une image' });
        }
        if (err.message === 'INVALID_STICKER') {
            return res.status(400).json({ error: "Ce sticker n'est plus disponible" });
        }
        if (err.message === 'INVALID_PARENT') {
            return res.status(400).json({ error: "Le commentaire auquel vous répondez n'existe plus" });
        }
        if (err.message === 'NOT_FOUND') {
            return res.status(404).json({ error: 'Vidéo non disponible' });
        }
        console.error('❌ Erreur ajout commentaire:', err.message);
        res.status(500).json({ error: "Erreur lors de l'ajout du commentaire" });
    }
});

/**
 * POST /api/videos/:id/comments/:commentId/react
 * Body: { value: 1 | -1 | 0 }
 */
router.post('/:id/comments/:commentId/react', requireAuth, async (req, res) => {
    try {
        if (!/^\d+$/.test(req.params.commentId)) {
            return res.status(400).json({ error: 'Identifiant de commentaire invalide' });
        }
        const comment = await videoService.reactToComment(
            req.params.id, req.params.commentId, req.user.id, req.body?.value
        );
        res.json({ success: true, comment });
    } catch (err) {
        if (err.message === 'INVALID_REACTION') {
            return res.status(400).json({ error: 'Réaction invalide' });
        }
        if (err.message === 'NOT_FOUND') {
            return res.status(404).json({ error: 'Commentaire non trouvé' });
        }
        console.error('❌ Erreur réaction commentaire:', err.message);
        res.status(500).json({ error: "Erreur lors de l'enregistrement de la réaction" });
    }
});

/**
 * DELETE /api/videos/:id/comments/:commentId
 * Supprimer un commentaire (son auteur ou le propriétaire de la vidéo)
 */
router.delete('/:id/comments/:commentId', requireAuth, async (req, res) => {
    try {
        if (!/^\d+$/.test(req.params.commentId)) {
            return res.status(400).json({ error: 'Identifiant de commentaire invalide' });
        }
        const result = await videoService.deleteComment(req.params.id, req.params.commentId, req.user.id);
        res.json({ success: true, ...result });
    } catch (err) {
        if (err.message === 'NOT_FOUND') {
            return res.status(404).json({ error: 'Commentaire non trouvé ou non autorisé' });
        }
        console.error('❌ Erreur suppression commentaire:', err.message);
        res.status(500).json({ error: 'Erreur lors de la suppression' });
    }
});

/**
 * POST /api/videos/:id/report
 * Signaler une vidéo à la modération
 * Body: { reason, details }
 */
router.post('/:id/report', requireAuth, async (req, res) => {
    try {
        const result = await videoService.reportVideo(
            req.params.id,
            req.user.id,
            req.body?.reason,
            req.body?.details
        );
        res.status(201).json({ success: true, ...result });
    } catch (err) {
        if (err.message === 'INVALID_REASON') {
            return res.status(400).json({ error: 'Motif de signalement invalide' });
        }
        if (err.message === 'OWN_VIDEO') {
            return res.status(400).json({ error: 'Vous ne pouvez pas signaler votre propre vidéo' });
        }
        if (err.message === 'NOT_FOUND') {
            return res.status(404).json({ error: 'Vidéo non disponible' });
        }
        console.error('❌ Erreur signalement vidéo:', err.message);
        res.status(500).json({ error: 'Erreur lors du signalement' });
    }
});

/**
 * DELETE /api/videos/:id
 * Supprimer sa propre vidéo
 */
router.delete('/:id', requireAuth, async (req, res) => {
    try {
        await videoService.deleteVideo(req.params.id, req.user.id);
        res.json({ success: true, message: 'Vidéo supprimée' });
    } catch (err) {
        if (err.message === 'NOT_FOUND') {
            return res.status(404).json({ error: 'Vidéo non trouvée ou non autorisé' });
        }
        console.error('❌ Erreur suppression vidéo:', err.message);
        res.status(500).json({ error: 'Erreur lors de la suppression' });
    }
});

module.exports = router;
