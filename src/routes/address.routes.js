const express = require('express');
const router = express.Router();
const addressService = require('../services/address.service');
const { requireAuth } = require('../middlewares/auth.middleware'); // Correction import si besoin

// Toutes les routes nécessitent une authentification
// Si requireAuth n'est pas dispo directement, adapter selon structure existante (ex: vérifier server.js)
// Pour l'instant on suppose qu'il est passé ou injecté dans server.js. 
// Mais ici on définit juste le router. 

// GET /addresses - Récupérer les adresses
router.get('/', async (req, res) => {
    try {
        const addresses = await addressService.getUserAddresses(req.user.id);
        res.json(addresses);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// POST /addresses - Ajouter une adresse
router.post('/', async (req, res) => {
    try {
        const address = await addressService.addAddress(req.user.id, req.body);
        res.status(201).json(address);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// PUT /addresses/:id - Modifier une adresse
router.put('/:id', async (req, res) => {
    try {
        const address = await addressService.updateAddress(req.user.id, req.params.id, req.body);
        res.json(address);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// DELETE /addresses/:id - Supprimer
router.delete('/:id', async (req, res) => {
    try {
        await addressService.deleteAddress(req.user.id, req.params.id);
        res.json({ message: 'Adresse supprimée' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// POST /addresses/:id/set-default
router.post('/:id/set-default', async (req, res) => {
    try {
        const address = await addressService.setDefaultAddress(req.user.id, req.params.id);
        res.json(address);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
