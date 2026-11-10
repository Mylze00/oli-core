/**
 * Routes Admin - Galerie de stickers des commentaires
 * Le contrôle d'accès administrateur est appliqué par admin.routes.js
 */
const express = require('express');
const router = express.Router();
const videoService = require('../../services/video-sales.service');
const { genericUpload } = require('../../config/upload');

/**
 * GET /admin/stickers
 * Tous les stickers, y compris les stickers masqués
 */
router.get('/', async (req, res) => {
    try {
        res.json(await videoService.listStickersForAdmin());
    } catch (err) {
        console.error('Erreur GET /admin/stickers:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /admin/stickers
 * Body (multipart): image, name, pack
 */
router.post('/', (req, res, next) => {
    genericUpload.single('image')(req, res, (err) => {
        if (err) {
            console.error('Erreur envoi sticker:', err);
            return res.status(400).json({ error: "L'image n'a pas pu être envoyée" });
        }
        next();
    });
}, async (req, res) => {
    try {
        const image = req.file;
        const isImage = image && (image.mimetype?.startsWith('image/') || image.path?.includes('/image/upload/'));
        const name = req.body?.name?.trim();
        if (!isImage || !name) {
            return res.status(400).json({ error: 'Une image et un nom sont obligatoires' });
        }
        const sticker = await videoService.createSticker(image.path, name, req.body?.pack, req.user.id);
        res.status(201).json(sticker);
    } catch (err) {
        console.error('Erreur POST /admin/stickers:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/stickers/:id
 * Body: { status: 'active' | 'hidden' }
 */
router.patch('/:id', async (req, res) => {
    try {
        const { status } = req.body || {};
        if (!/^\d+$/.test(req.params.id) || !['active', 'hidden'].includes(status)) {
            return res.status(400).json({ error: 'Requête invalide' });
        }
        res.json(await videoService.setStickerStatus(req.params.id, status));
    } catch (err) {
        if (err.message === 'NOT_FOUND') {
            return res.status(404).json({ error: 'Sticker non trouvé' });
        }
        console.error('Erreur PATCH /admin/stickers/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
