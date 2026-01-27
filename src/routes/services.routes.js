/**
 * Routes Public - Services Dynamiques
 * GET /services (Public app access)
 */
const express = require('express');
const router = express.Router();
const pool = require('../config/db');

/**
 * GET /services
 * Liste les services actifs pour l'application mobile
 */
router.get('/', async (req, res) => {
    try {
        // On ne retourne que les services visibles
        const result = await pool.query(`
            SELECT id, name, logo_url, status, color_hex 
            FROM services 
            WHERE is_visible = TRUE 
            ORDER BY display_order ASC, created_at DESC
        `);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur GET /services:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
