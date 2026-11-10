/**
 * Routes Admin - Modération des vidéos Live Shopping
 * Le contrôle d'accès administrateur est appliqué par admin.routes.js
 */
const express = require('express');
const router = express.Router();
const videoService = require('../../services/video-sales.service');

const FILTERS = ['pending', 'removed', 'all'];
const ACTIONS = ['remove', 'restore', 'dismiss'];

/**
 * GET /admin/videos?filter=pending|removed|all&limit=50&offset=0
 * Liste les vidéos à modérer avec leurs signalements
 */
router.get('/', async (req, res) => {
    try {
        const filter = FILTERS.includes(req.query.filter) ? req.query.filter : 'pending';
        const limit = Math.min(parseInt(req.query.limit) || 50, 100);
        const offset = Math.max(parseInt(req.query.offset) || 0, 0);
        res.json(await videoService.listForModeration(filter, limit, offset));
    } catch (err) {
        console.error('Erreur GET /admin/videos:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /admin/videos/:id/moderate
 * Body: { action: 'remove' | 'restore' | 'dismiss' }
 */
router.post('/:id/moderate', async (req, res) => {
    try {
        const { action } = req.body || {};
        if (!/^\d+$/.test(req.params.id) || !ACTIONS.includes(action)) {
            return res.status(400).json({ error: 'Requête de modération invalide' });
        }
        res.json(await videoService.moderateVideo(req.params.id, req.user.id, action));
    } catch (err) {
        if (err.message === 'NOT_FOUND') {
            return res.status(404).json({ error: "Vidéo introuvable ou action impossible dans cet état" });
        }
        console.error('Erreur POST /admin/videos/:id/moderate:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
