/**
 * Routes Admin - Gestion Livreurs
 * GET /admin/delivery/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');
const { BASE_URL } = require('../../config');

/**
 * GET /admin/delivery/drivers
 * Liste tous les livreurs (users avec is_deliverer = true)
 */
router.get('/drivers', async (req, res) => {
    try {
        const { search, limit = 100, offset = 0 } = req.query;

        let query = `
            SELECT 
                u.id, u.name, u.phone, u.email, u.avatar_url,
                u.is_deliverer, u.is_verified, u.is_suspended,
                u.created_at, u.last_active,
                COUNT(DISTINCT o.id) FILTER (WHERE o.delivery_status = 'delivered') as completed_deliveries,
                COUNT(DISTINCT o.id) FILTER (WHERE o.delivery_status IN ('assigned', 'in_transit')) as active_deliveries,
                COUNT(DISTINCT o.id) as total_deliveries
            FROM users u
            LEFT JOIN orders o ON o.deliverer_id = u.id
            WHERE u.is_deliverer = TRUE
        `;
        const params = [];
        let paramIndex = 1;

        if (search) {
            query += ` AND (u.name ILIKE $${paramIndex} OR u.phone ILIKE $${paramIndex} OR u.email ILIKE $${paramIndex})`;
            params.push(`%${search}%`);
            paramIndex++;
        }

        query += ` GROUP BY u.id ORDER BY u.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, params);

        // Format avatar URLs
        const drivers = result.rows.map(d => ({
            ...d,
            avatar_url: d.avatar_url
                ? (d.avatar_url.startsWith('http') ? d.avatar_url : `${BASE_URL}/uploads/${d.avatar_url}`)
                : null
        }));

        // Stats
        let stats = { total: 0, active: 0, verified: 0, suspended: 0 };
        try {
            const statsResult = await pool.query(`
                SELECT 
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE is_suspended = FALSE) as active,
                    COUNT(*) FILTER (WHERE is_verified = TRUE) as verified,
                    COUNT(*) FILTER (WHERE is_suspended = TRUE) as suspended
                FROM users WHERE is_deliverer = TRUE
            `);
            stats = statsResult.rows[0];
        } catch (e) { console.warn('delivery stats error:', e.message); }

        res.json({
            drivers,
            stats: {
                total: parseInt(stats.total),
                active: parseInt(stats.active),
                verified: parseInt(stats.verified),
                suspended: parseInt(stats.suspended),
            }
        });
    } catch (err) {
        console.error('Erreur GET /admin/delivery/drivers:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/delivery/drivers/:id/toggle
 * Activer/Désactiver un livreur
 */
router.patch('/drivers/:id/toggle', async (req, res) => {
    try {
        const { id } = req.params;
        const current = await pool.query('SELECT is_suspended FROM users WHERE id = $1 AND is_deliverer = TRUE', [id]);
        if (current.rows.length === 0) return res.status(404).json({ error: 'Livreur introuvable' });

        const newStatus = !current.rows[0].is_suspended;
        await pool.query('UPDATE users SET is_suspended = $1, updated_at = NOW() WHERE id = $2', [newStatus, id]);
        res.json({ message: newStatus ? 'Livreur suspendu' : 'Livreur réactivé', is_suspended: newStatus });
    } catch (err) {
        console.error('Erreur toggle driver:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/delivery/drivers/:id/verify
 * Vérifier un livreur
 */
router.patch('/drivers/:id/verify', async (req, res) => {
    try {
        const { id } = req.params;
        const current = await pool.query('SELECT is_verified FROM users WHERE id = $1 AND is_deliverer = TRUE', [id]);
        if (current.rows.length === 0) return res.status(404).json({ error: 'Livreur introuvable' });

        const newVal = !current.rows[0].is_verified;
        await pool.query('UPDATE users SET is_verified = $1, updated_at = NOW() WHERE id = $2', [newVal, id]);
        res.json({ message: newVal ? 'Livreur vérifié' : 'Vérification retirée', is_verified: newVal });
    } catch (err) {
        console.error('Erreur verify driver:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/delivery/applications
 * Liste toutes les candidatures de livreurs
 */
router.get('/applications', async (req, res) => {
    try {
        const { status, search, limit = 100, offset = 0 } = req.query;

        let query = `
            SELECT 
                da.id, da.user_id, da.pledge_amount, da.phone as app_phone,
                da.motivation, da.status, da.admin_note,
                da.created_at, da.reviewed_at,
                u.name, u.phone, u.email, u.avatar_url
            FROM deliverer_applications da
            JOIN users u ON u.id = da.user_id
        `;
        const params = [];
        let paramIndex = 1;
        const conditions = [];

        if (status && status !== 'all') {
            conditions.push(`da.status = $${paramIndex++}`);
            params.push(status);
        }

        if (search) {
            conditions.push(`(u.name ILIKE $${paramIndex} OR u.phone ILIKE $${paramIndex} OR u.email ILIKE $${paramIndex})`);
            params.push(`%${search}%`);
            paramIndex++;
        }

        if (conditions.length > 0) {
            query += ` WHERE ${conditions.join(' AND ')}`;
        }

        query += ` ORDER BY da.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, params);

        // Format avatars
        const applications = result.rows.map(a => ({
            ...a,
            avatar_url: a.avatar_url
                ? (a.avatar_url.startsWith('http') ? a.avatar_url : `${BASE_URL}/uploads/${a.avatar_url}`)
                : null
        }));

        // Stats des candidatures
        let appStats = { total: 0, pending: 0, approved: 0, rejected: 0 };
        try {
            const statsResult = await pool.query(`
                SELECT 
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE status = 'pending') as pending,
                    COUNT(*) FILTER (WHERE status = 'approved') as approved,
                    COUNT(*) FILTER (WHERE status = 'rejected') as rejected
                FROM deliverer_applications
            `);
            appStats = statsResult.rows[0];
        } catch (e) { console.warn('app stats error:', e.message); }

        res.json({
            applications,
            stats: {
                total: parseInt(appStats.total),
                pending: parseInt(appStats.pending),
                approved: parseInt(appStats.approved),
                rejected: parseInt(appStats.rejected),
            }
        });
    } catch (err) {
        console.error('Erreur GET /admin/delivery/applications:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/delivery/applications/:id/approve
 * Approuver une candidature → active is_deliverer sur l'utilisateur
 */
router.patch('/applications/:id/approve', async (req, res) => {
    try {
        const { id } = req.params;

        // Récupérer la candidature
        const app = await pool.query(
            'SELECT user_id, status FROM deliverer_applications WHERE id = $1',
            [id]
        );
        if (app.rows.length === 0) {
            return res.status(404).json({ error: 'Candidature introuvable' });
        }
        if (app.rows[0].status === 'approved') {
            return res.status(400).json({ error: 'Candidature déjà approuvée' });
        }

        const userId = app.rows[0].user_id;

        // Mettre à jour la candidature
        await pool.query(
            `UPDATE deliverer_applications 
             SET status = 'approved', admin_note = $1, reviewed_at = NOW() 
             WHERE id = $2`,
            [req.body.admin_note || 'Approuvé par admin', id]
        );

        // Activer le rôle livreur sur l'utilisateur
        await pool.query(
            'UPDATE users SET is_deliverer = TRUE, updated_at = NOW() WHERE id = $1',
            [userId]
        );

        res.json({
            success: true,
            message: 'Candidature approuvée — livreur activé',
            user_id: userId
        });
    } catch (err) {
        console.error('Erreur approve application:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/delivery/applications/:id/reject
 * Rejeter une candidature
 */
router.patch('/applications/:id/reject', async (req, res) => {
    try {
        const { id } = req.params;
        const { admin_note } = req.body;

        const app = await pool.query(
            'SELECT user_id, status FROM deliverer_applications WHERE id = $1',
            [id]
        );
        if (app.rows.length === 0) {
            return res.status(404).json({ error: 'Candidature introuvable' });
        }

        await pool.query(
            `UPDATE deliverer_applications 
             SET status = 'rejected', admin_note = $1, reviewed_at = NOW() 
             WHERE id = $2`,
            [admin_note || 'Rejeté par admin', id]
        );

        res.json({
            success: true,
            message: 'Candidature rejetée'
        });
    } catch (err) {
        console.error('Erreur reject application:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
