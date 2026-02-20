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
 * Body (multipart): video, product_id, title, description
 */
router.post('/', requireAuth, genericUpload.single('video'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'Aucune vidéo fournie' });
        }

        const videoUrl = req.file.path || req.file.url || req.file.secure_url || req.file.location;
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
        console.error('❌ Erreur upload vidéo:', err.message);
        res.status(500).json({ error: 'Erreur lors de l\'upload' });
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
        console.error('❌ Erreur like vidéo:', err.message);
        res.status(500).json({ error: 'Erreur' });
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
