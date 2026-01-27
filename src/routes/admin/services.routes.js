/**
 * Routes Admin - Gestion Services Dynamiques
 * GET /admin/services/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');
const { genericUpload } = require('../../config/upload'); // Import genericUpload

/**
 * POST /admin/services/upload
 * Uploader un logo de service
 */
router.post('/upload', genericUpload.single('image'), (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'Aucun fichier fourni' });
        }

        let imageUrl = req.file.path;

        // Si stockage local (pas Cloudinary), construire l'URL complète
        if (!imageUrl.startsWith('http')) {
            const baseUrl = `${req.protocol}://${req.get('host')}`;
            const cleanPath = req.file.path.replace(/\\/g, '/');
            imageUrl = `${baseUrl}/${cleanPath}`;
        }

        res.json({ url: imageUrl });
    } catch (err) {
        console.error('Erreur Upload Logo Service:', err);
        res.status(500).json({ error: 'Erreur upload' });
    }
});

/**
 * GET /admin/services
 * Liste tous les services (admin view - inclut status cachés)
 */
router.get('/', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT * FROM services 
            ORDER BY display_order ASC, created_at DESC
        `);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur GET /admin/services:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /admin/services
 * Créer un nouveau service
 */
router.post('/', async (req, res) => {
    try {
        const { name, logo_url, color_hex, status = 'coming_soon', display_order = 0 } = req.body;

        if (!name || !logo_url) {
            return res.status(400).json({ error: "Nom et Logo requis" });
        }

        const result = await pool.query(`
            INSERT INTO services (name, logo_url, color_hex, status, display_order)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING *
        `, [name, logo_url, color_hex, status, display_order]);

        res.status(201).json(result.rows[0]);
    } catch (err) {
        console.error('Erreur POST /admin/services:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PUT /admin/services/:id
 * Mettre à jour un service
 */
router.put('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { name, logo_url, color_hex, status, display_order, is_visible } = req.body;

        // On construit la requête dynamiquement ou on update tout (simple ici)
        const result = await pool.query(`
            UPDATE services 
            SET name = COALESCE($1, name),
                logo_url = COALESCE($2, logo_url),
                color_hex = COALESCE($3, color_hex),
                status = COALESCE($4, status),
                display_order = COALESCE($5, display_order),
                is_visible = COALESCE($6, is_visible),
                updated_at = NOW()
            WHERE id = $7
            RETURNING *
        `, [name, logo_url, color_hex, status, display_order, is_visible, id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: "Service introuvable" });
        }

        res.json(result.rows[0]);
    } catch (err) {
        console.error('Erreur PUT /admin/services/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * DELETE /admin/services/:id
 * Supprimer un service
 */
router.delete('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await pool.query('DELETE FROM services WHERE id = $1', [id]);
        res.json({ message: "Service supprimé" });
    } catch (err) {
        console.error('Erreur DELETE /admin/services/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/services/reorder
 * Réordonner les services (batch update)
 * Body: { orders: [{ id: 1, order: 0 }, { id: 2, order: 1 }] }
 */
router.patch('/reorder', async (req, res) => {
    try {
        const { orders } = req.body; // Array of { id, order }

        if (!Array.isArray(orders)) {
            return res.status(400).json({ error: "Format invalide" });
        }

        // Transaction pour l'atomicité
        const client = await pool.connect();
        try {
            await client.query('BEGIN');
            for (const item of orders) {
                await client.query('UPDATE services SET display_order = $1 WHERE id = $2', [item.order, item.id]);
            }
            await client.query('COMMIT');
            res.json({ message: "Ordre mis à jour" });
        } catch (e) {
            await client.query('ROLLBACK');
            throw e;
        } finally {
            client.release();
        }
    } catch (err) {
        console.error('Erreur PATCH /admin/services/reorder:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
