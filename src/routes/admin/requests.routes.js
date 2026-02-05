/**
 * Routes Admin - Gestion des Demandes de Services
 * GET/PATCH /admin/requests/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');

/**
 * GET /admin/requests
 * Liste toutes les demandes avec filtres
 */
router.get('/', async (req, res) => {
    try {
        const { type, status, limit = 50, offset = 0 } = req.query;

        let query = `
            SELECT 
                sr.*,
                u.name as user_name,
                u.phone as user_phone,
                u.avatar_url as user_avatar,
                p.name as product_name,
                p.images as product_images,
                s.name as shop_name,
                docs.documents as user_documents
            FROM service_requests sr
            JOIN users u ON sr.user_id = u.id
            LEFT JOIN products p ON sr.request_type = 'product_sponsorship' AND sr.target_id = p.id
            LEFT JOIN shops s ON sr.request_type = 'shop_certification' AND sr.target_id = s.id
            LEFT JOIN (
                SELECT user_id, JSON_AGG(json_build_object(
                    'type', document_type,
                    'number', document_number,
                    'front', front_image_url,
                    'back', back_image_url,
                    'selfie', selfie_url,
                    'status', verification_status
                )) as documents
                FROM user_identity_documents
                GROUP BY user_id
            ) docs ON sr.user_id = docs.user_id
            WHERE 1=1
        `;
        const params = [];
        let paramIndex = 1;

        // Filtre par type
        if (type) {
            query += ` AND sr.request_type = $${paramIndex++}`;
            params.push(type);
        }

        // Filtre par statut admin
        if (status) {
            query += ` AND sr.admin_status = $${paramIndex++}`;
            params.push(status);
        }

        query += ` ORDER BY sr.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur GET /admin/requests:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/requests/stats
 * Statistiques des demandes
 */
router.get('/stats', async (req, res) => {
    try {
        const stats = await pool.query(`
            SELECT 
                COUNT(*) FILTER (WHERE admin_status = 'pending') as pending_count,
                COUNT(*) FILTER (WHERE admin_status = 'approved') as approved_count,
                COUNT(*) FILTER (WHERE admin_status = 'rejected') as rejected_count,
                COUNT(*) FILTER (WHERE request_type = 'product_sponsorship') as sponsorship_count,
                COUNT(*) FILTER (WHERE request_type = 'user_verification') as verification_count,
                COUNT(*) FILTER (WHERE request_type = 'shop_certification') as certification_count
            FROM service_requests
        `);
        res.json(stats.rows[0]);
    } catch (err) {
        console.error('Erreur GET /admin/requests/stats:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/requests/:id
 * Approuver ou rejeter une demande
 */
router.patch('/:id', async (req, res) => {
    const client = await pool.connect();
    try {
        const { id } = req.params;
        const { action, notes } = req.body; // action: 'approve' ou 'reject'
        const adminId = req.user.id;

        if (!['approve', 'reject'].includes(action)) {
            return res.status(400).json({ error: "Action invalide. Utilisez 'approve' ou 'reject'" });
        }

        await client.query('BEGIN');

        // 1. Récupérer la demande
        const requestResult = await client.query(
            'SELECT * FROM service_requests WHERE id = $1',
            [id]
        );

        if (requestResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Demande non trouvée' });
        }

        const request = requestResult.rows[0];

        // 2. Vérifier que le paiement est effectué (pour approve)
        if (action === 'approve' && request.payment_status !== 'paid') {
            await client.query('ROLLBACK');
            return res.status(400).json({ error: 'Le paiement doit être confirmé avant approbation' });
        }

        // 3. Mettre à jour la demande
        const newStatus = action === 'approve' ? 'approved' : 'rejected';
        await client.query(`
            UPDATE service_requests 
            SET admin_status = $1, admin_id = $2, admin_notes = $3, processed_at = NOW(), updated_at = NOW()
            WHERE id = $4
        `, [newStatus, adminId, notes || null, id]);

        // 4. Si approuvé, appliquer l'effet
        if (action === 'approve') {
            switch (request.request_type) {
                case 'product_sponsorship':
                    await client.query(
                        'UPDATE products SET is_featured = true WHERE id = $1',
                        [request.target_id]
                    );
                    break;
                case 'user_verification':
                    await client.query(
                        'UPDATE users SET is_verified = true WHERE id = $1',
                        [request.user_id]
                    );
                    break;
                case 'shop_certification':
                    await client.query(
                        'UPDATE shops SET is_verified = true WHERE id = $1',
                        [request.target_id]
                    );
                    break;
            }
        }

        await client.query('COMMIT');

        res.json({
            message: action === 'approve' ? 'Demande approuvée' : 'Demande rejetée',
            request_id: id,
            new_status: newStatus
        });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Erreur PATCH /admin/requests/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    } finally {
        client.release();
    }
});

module.exports = router;
