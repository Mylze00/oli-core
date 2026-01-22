const express = require('express');
const router = express.Router();
const adRepo = require('../../repositories/ad.repository');

/**
 * GET /admin/ads
 * Liste toutes les pubs (admin)
 */
router.get('/', async (req, res) => {
    try {
        const ads = await adRepo.findAllAdmin();
        res.json(ads);
    } catch (err) {
        console.error('Erreur GET /admin/ads:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /admin/ads
 * Créer une nouvelle pub
 */
router.post('/', async (req, res) => {
    try {
        const { image_url, title, link_url } = req.body;
        if (!image_url) return res.status(400).json({ error: 'Image requise' });

        const newAd = await adRepo.create({ image_url, title, link_url });
        res.status(201).json(newAd);
    } catch (err) {
        console.error('Erreur POST /admin/ads:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * DELETE /admin/ads/:id
 * Supprimer une pub
 */
router.delete('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const deleted = await adRepo.delete(id);
        if (!deleted) return res.status(404).json({ error: 'Pub introuvable' });
        res.json({ message: 'Pub supprimée' });
    } catch (err) {
        console.error('Erreur DELETE /admin/ads/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/ads/:id/status
 * Activer/Désactiver une pub
 */
router.patch('/:id/status', async (req, res) => {
    try {
        const { id } = req.params;
        const { is_active } = req.body;
        const updated = await adRepo.toggleActive(id, is_active);
        res.json(updated);
    } catch (err) {
        console.error('Erreur PATCH /admin/ads/:id/status:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
