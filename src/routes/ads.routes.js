const express = require('express');
const router = express.Router();
const adRepo = require('../repositories/ad.repository');

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

module.exports = router;
