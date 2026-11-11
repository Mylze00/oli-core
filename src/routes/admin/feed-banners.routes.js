/**
 * Routes admin des bannières du fil d'accueil (/admin/feed-banners).
 * Protégées par requireAuth + requireAdmin (appliqués dans admin.routes.js).
 *
 * Une bannière est :
 *  - une image avec un lien facultatif, ou
 *  - une vidéo courte, compressée par Cloudinary (720 px max, qualité « eco »,
 *    H.264, sans son) pour rester légère et être gardée en cache dans l'app.
 */
const express = require('express');
const cloudinary = require('cloudinary').v2;
const router = express.Router();
const repo = require('../../repositories/feedBanner.repository');
const { genericUpload, isCloudStorage } = require('../../config/upload');

// Compression appliquée à la diffusion des vidéos (lecture muette en boucle dans le fil).
const VIDEO_TRANSFORM = 'q_auto:eco,w_720,c_limit,vc_h264,ac_none';
// Vignette : première image de la vidéo.
const POSTER_TRANSFORM = 'so_0,w_720,c_limit,q_auto';

/** Insère une transformation Cloudinary après /upload/ et change l'extension. */
function cloudinaryVariant(url, transform, extension) {
    const marker = '/upload/';
    const i = url.indexOf(marker);
    if (i === -1) return url;
    const before = url.slice(0, i + marker.length);
    const after = url.slice(i + marker.length).replace(/\.[a-z0-9]+$/i, `.${extension}`);
    return `${before}${transform}/${after}`;
}

const VALID_TYPES = ['image', 'video'];

/**
 * POST /admin/feed-banners/upload  (champ multipart « file »)
 * Renvoie { media_type, media_url, poster_url }.
 */
router.post('/upload', genericUpload.single('file'), async (req, res) => {
    try {
        if (!req.file) return res.status(400).json({ error: 'Aucun fichier fourni' });

        const isVideo = req.file.mimetype.startsWith('video/');
        if (!isVideo && !req.file.mimetype.startsWith('image/')) {
            return res.status(400).json({ error: 'Seules les images et les vidéos sont acceptées' });
        }

        let url = req.file.path;
        if (!url.startsWith('http')) {
            // Stockage local (développement) : pas de compression possible.
            url = `${req.protocol}://${req.get('host')}/${url.replace(/\\/g, '/')}`;
            return res.json({ media_type: isVideo ? 'video' : 'image', media_url: url, poster_url: null });
        }

        if (!isVideo) {
            return res.json({ media_type: 'image', media_url: url, poster_url: null });
        }

        // Lance la compression tout de suite chez Cloudinary (en arrière-plan) pour que
        // le premier utilisateur n'attende pas la génération de la version légère.
        if (isCloudStorage && req.file.filename) {
            cloudinary.uploader.explicit(req.file.filename, {
                type: 'upload',
                resource_type: 'video',
                eager: [{ raw_transformation: VIDEO_TRANSFORM, format: 'mp4' }],
                eager_async: true,
            }).catch(err => console.warn('⚠️ Compression vidéo différée:', err.message));
        }

        res.json({
            media_type: 'video',
            media_url: cloudinaryVariant(url, VIDEO_TRANSFORM, 'mp4'),
            poster_url: cloudinaryVariant(url, POSTER_TRANSFORM, 'jpg'),
        });
    } catch (err) {
        console.error('Erreur upload bannière:', err);
        res.status(500).json({ error: 'Erreur upload' });
    }
});

/** GET /admin/feed-banners — toutes les bannières. */
router.get('/', async (req, res) => {
    try {
        res.json(await repo.findAllAdmin());
    } catch (err) {
        console.error('Erreur GET /admin/feed-banners:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/** POST /admin/feed-banners — créer une bannière. */
router.post('/', async (req, res) => {
    try {
        const { media_type = 'image', media_url, poster_url, link_url, title, is_active } = req.body;
        if (!media_url) return res.status(400).json({ error: 'Média requis' });
        if (!VALID_TYPES.includes(media_type)) return res.status(400).json({ error: 'Type invalide' });

        const banner = await repo.create({ media_type, media_url, poster_url, link_url, title, is_active });
        res.status(201).json(banner);
    } catch (err) {
        console.error('Erreur POST /admin/feed-banners:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/** PATCH /admin/feed-banners/reorder — body { orders: [{ id, order }] }. */
router.patch('/reorder', async (req, res) => {
    try {
        const { orders } = req.body;
        if (!Array.isArray(orders)) return res.status(400).json({ error: 'orders doit être une liste' });
        await repo.updateOrder(orders);
        res.json({ message: 'Ordre mis à jour' });
    } catch (err) {
        console.error('Erreur PATCH /admin/feed-banners/reorder:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/** PUT /admin/feed-banners/:id — modifier une bannière. */
router.put('/:id', async (req, res) => {
    try {
        const { media_type, media_url, poster_url, link_url, title, is_active } = req.body;
        if (media_type !== undefined && !VALID_TYPES.includes(media_type)) {
            return res.status(400).json({ error: 'Type invalide' });
        }
        const banner = await repo.update(req.params.id, { media_type, media_url, poster_url, link_url, title, is_active });
        if (!banner) return res.status(404).json({ error: 'Bannière introuvable' });
        res.json(banner);
    } catch (err) {
        console.error('Erreur PUT /admin/feed-banners/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/** PATCH /admin/feed-banners/:id/status — body { is_active }. */
router.patch('/:id/status', async (req, res) => {
    try {
        const banner = await repo.setActive(req.params.id, !!req.body.is_active);
        if (!banner) return res.status(404).json({ error: 'Bannière introuvable' });
        res.json(banner);
    } catch (err) {
        console.error('Erreur PATCH /admin/feed-banners/:id/status:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/** DELETE /admin/feed-banners/:id */
router.delete('/:id', async (req, res) => {
    try {
        const deleted = await repo.delete(req.params.id);
        if (!deleted) return res.status(404).json({ error: 'Bannière introuvable' });
        res.json({ message: 'Bannière supprimée' });
    } catch (err) {
        console.error('Erreur DELETE /admin/feed-banners/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
