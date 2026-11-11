const express = require('express');
const router = express.Router();
const adRepo = require('../repositories/ad.repository');
const feedBannerRepo = require('../repositories/feedBanner.repository');

/**
 * GET /ads
 * Récupère les publicités actives pour l'application mobile
 */
router.get('/', async (req, res) => {
    try {
        const ads = await adRepo.findAllActive();
        res.json(ads);
    } catch (err) {
        console.error('Erreur GET /ads:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /ads/feed-banners
 * Bannières actives du fil d'accueil (image + lien, ou vidéo compressée),
 * insérées entre les blocs du Top Classement.
 */
router.get('/feed-banners', async (req, res) => {
    try {
        const banners = await feedBannerRepo.findAllActive();
        // Liste courte et peu changeante : cache navigateur/proxy de 5 min.
        res.set('Cache-Control', 'public, max-age=300');
        res.json(banners);
    } catch (err) {
        console.error('Erreur GET /ads/feed-banners:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
