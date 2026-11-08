const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const { requireAuth } = require('../middlewares/auth.middleware');
const { requireAdmin } = require('../middlewares/admin.middleware');

// Configuration Cloudinary
const storage = new CloudinaryStorage({
    cloudinary: cloudinary,
    params: {
        folder: 'product-requests',
        allowed_formats: ['jpg', 'png', 'jpeg', 'webp'],
    },
});

const upload = multer({ storage, limits: { fileSize: 8 * 1024 * 1024 } });

const receiveImage = (req, res, next) => {
    upload.single('image')(req, res, (err) => {
        if (err) {
            return res.status(400).json({ success: false, error: "Image refusée : format non pris en charge ou fichier trop lourd (8 Mo max)" });
        }
        next();
    });
};

// Créer une demande de produit
router.post('/', receiveImage, async (req, res) => {
    try {
        const { description, user_id, user_name, user_phone } = req.body;
        const imageUrl = req.file?.path || null;
        const source = req.body.source === 'b2b' ? 'b2b' : null;

        if (!description?.trim() && !imageUrl) {
            return res.status(400).json({ success: false, error: 'Décrivez votre besoin ou joignez une image' });
        }

        // Insérer la demande dans la base de données
        const result = await pool.query(
            `INSERT INTO product_requests (user_id, user_name, user_phone, description, image_url, source, status, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, 'pending', NOW())
       RETURNING *`,
            [user_id || null, user_name || 'Anonyme', user_phone || null, description || '', imageUrl, source]
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

// Consultation et gestion : réservées aux administrateurs
router.use(requireAuth, requireAdmin);

// Récupérer toutes les demandes avec les coordonnées du client (admin).
// Si le formulaire n'a pas transmis le nom ou le numéro, ceux du compte sont utilisés.
router.get('/', async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT pr.*,
                    COALESCE(NULLIF(pr.user_phone, ''), u.phone) AS contact_phone,
                    COALESCE(NULLIF(NULLIF(pr.user_name, ''), 'Anonyme'), u.name, pr.user_name) AS contact_name
             FROM product_requests pr
             LEFT JOIN users u ON u.id = pr.user_id
             ORDER BY pr.created_at DESC`
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
