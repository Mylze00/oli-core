const express = require('express');
const router = express.Router();
const pool = require('../../config/db');

/**
 * GET /admin/disputes
 * Liste tous les litiges
 */
router.get('/', async (req, res) => {
    try {
        const { status, limit = 50, offset = 0 } = req.query;

        let query = `
            SELECT d.*,
                   o.id as order_ref,
                   r.name as reporter_name,
                   r.phone as reporter_phone,
                   t.name as target_name
            FROM disputes d
            JOIN orders o ON d.order_id = o.id
            LEFT JOIN users r ON d.reporter_id = r.id
            LEFT JOIN users t ON d.target_id = t.id
            WHERE 1=1
        `;
        const params = [];
        let paramIndex = 1;

        if (status) {
            query += ` AND d.status = $${paramIndex++}`;
            params.push(status);
        }

        query += ` ORDER BY d.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur GET /admin/disputes:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/disputes/:id/resolve
 * Résoudre un litige (Remboursement ou Clôture)
 */
router.patch('/:id/resolve', async (req, res) => {
    try {
        const { id } = req.params;
        const { status, resolution_notes } = req.body; // status: 'resolved' | 'rejected'

        if (!['resolved', 'rejected'].includes(status)) {
            return res.status(400).json({ error: 'Statut invalide' });
        }

        await pool.query(`
            UPDATE disputes 
            SET status = $1, resolution_notes = $2, updated_at = NOW() 
            WHERE id = $3
        `, [status, resolution_notes, id]);

        res.json({ message: 'Litige mis à jour' });
    } catch (err) {
        console.error('Erreur PATCH /admin/disputes/:id/resolve:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
