const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');

// Configuration Cloudinary
const storage = new CloudinaryStorage({
    cloudinary: cloudinary,
    params: {
        folder: 'product-requests',
        allowed_formats: ['jpg', 'png', 'jpeg', 'webp'],
    },
});

const upload = multer({ storage });

// Créer une demande de produit
router.post('/', upload.single('image'), async (req, res) => {
    try {
        const { description, user_id, user_name, user_phone } = req.body;
        const imageUrl = req.file?.path || null;

        // Insérer la demande dans la base de données
        const result = await pool.query(
            `INSERT INTO product_requests (user_id, user_name, user_phone, description, image_url, status, created_at)
       VALUES ($1, $2, $3, $4, $5, 'pending', NOW())
       RETURNING *`,
            [user_id || null, user_name || 'Anonyme', user_phone || null, description, imageUrl]
        );

        // Créer une notification pour l'admin
        await pool.query(
            `INSERT INTO admin_notifications (type, title, message, data, is_read, created_at)
       VALUES ('product_request', 'Nouvelle demande de produit', $1, $2, false, NOW())`,
            [
                `${user_name || 'Un utilisateur'} a soumis une demande de produit`,
                JSON.stringify({ request_id: result.rows[0].id, user_name, description: description?.substring(0, 100) })
            ]
        );

        res.status(201).json({
            success: true,
            message: 'Demande envoyée avec succès',
            request: result.rows[0]
        });
    } catch (error) {
        console.error('Error creating product request:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// Récupérer toutes les demandes (admin)
router.get('/', async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT * FROM product_requests ORDER BY created_at DESC`
        );
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching product requests:', error);
        res.status(500).json({ error: error.message });
    }
});

// Mettre à jour le statut d'une demande (admin)
router.patch('/:id/status', async (req, res) => {
    try {
        const { id } = req.params;
        const { status, admin_response } = req.body;

        const result = await pool.query(
            `UPDATE product_requests 
       SET status = $1, admin_response = $2, updated_at = NOW()
       WHERE id = $3
       RETURNING *`,
            [status, admin_response, id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Demande non trouvée' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating product request:', error);
        res.status(500).json({ error: error.message });
    }
});

// Supprimer une demande (admin)
router.delete('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await pool.query('DELETE FROM product_requests WHERE id = $1', [id]);
        res.json({ success: true, message: 'Demande supprimée' });
    } catch (error) {
        console.error('Error deleting product request:', error);
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
