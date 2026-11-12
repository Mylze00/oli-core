/**
 * Routes Admin - Gestion Livreurs
 * GET /admin/delivery/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');
const { BASE_URL } = require('../../config');
const walletRepository = require('../../repositories/wallet.repository');
const notificationService = require('../../services/notification.service');

/** Le candidat est prévenu de la décision (base, temps réel et push vers l'app Oli). */
function notifyCandidate(req, userId, title, body) {
    notificationService.send(userId, 'system', title, body, { kind: 'deliverer_application' }, req.app.get('io'))
        .catch((e) => console.warn(`⚠️ Candidat #${userId} non prévenu:`, e.message));
}

// ─── Auto-migration au démarrage ──────────────────────────────────
(async () => {
    try {
        await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS is_deliverer BOOLEAN DEFAULT FALSE`);
        await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE`);
        await pool.query(`
            CREATE TABLE IF NOT EXISTS deliverer_applications (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES users(id) UNIQUE,
                pledge_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
                phone VARCHAR(20),
                motivation TEXT,
                status VARCHAR(20) DEFAULT 'pending',
                admin_note TEXT,
                created_at TIMESTAMP DEFAULT NOW(),
                reviewed_at TIMESTAMP
            )
        `);
        console.log('✅ [admin/delivery] Tables livreurs prêtes');
    } catch (err) {
        console.error('❌ [admin/delivery] Migration:', err.message);
    }
})();

/**
 * GET /admin/delivery/drivers
 * Liste tous les livreurs (users avec is_deliverer = true)
 */
router.get('/drivers', async (req, res) => {
    try {
        const { search, limit = 100, offset = 0 } = req.query;

        let query = `
            SELECT 
                u.id, u.name, u.phone, NULL::text AS email, u.avatar_url,
                u.is_deliverer, u.is_verified, u.is_suspended,
                u.created_at,
                -- users n'a pas de colonne last_active : la dernière activité vient des sessions suivies
                (SELECT MAX(s.last_seen_at) FROM user_sessions_ext s WHERE s.user_id = u.id) AS last_active,
                COUNT(DISTINCT d.id) FILTER (WHERE d.status = 'delivered') as completed_deliveries,
                COUNT(DISTINCT d.id) FILTER (WHERE d.status IN ('assigned', 'picked_up', 'in_transit')) as active_deliveries,
                COUNT(DISTINCT d.id) as total_deliveries
            FROM users u
            -- Le livreur d'une commande est dans delivery_orders (orders n'a pas de deliverer_id).
            -- Comparaison en texte : le type de deliverer_id diffère selon les migrations.
            LEFT JOIN delivery_orders d ON d.deliverer_id::text = u.id::text
            WHERE u.is_deliverer = TRUE
        `;
        const params = [];
        let paramIndex = 1;

        if (search) {
            query += ` AND (u.name ILIKE $${paramIndex} OR u.phone ILIKE $${paramIndex})`;
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
        res.status(500).json({ error: 'Erreur serveur', detail: err.message });
    }
});

/**
 * POST /admin/delivery/drivers
 * Promouvoir manuellement un utilisateur en livreur (par phone ou user_id)
 */
router.post('/drivers', async (req, res) => {
    try {
        const { phone, user_id } = req.body;
        if (!phone && !user_id) {
            return res.status(400).json({ error: 'phone ou user_id requis' });
        }

        let userQuery;
        if (user_id) {
            userQuery = await pool.query('SELECT id, name, phone, is_deliverer FROM users WHERE id = $1', [user_id]);
        } else {
            userQuery = await pool.query('SELECT id, name, phone, is_deliverer FROM users WHERE phone = $1', [phone]);
        }

        if (userQuery.rows.length === 0) {
            return res.status(404).json({ error: 'Utilisateur introuvable' });
        }

        const user = userQuery.rows[0];
        if (user.is_deliverer) {
            return res.status(400).json({ error: 'Cet utilisateur est déjà livreur' });
        }

        await pool.query('UPDATE users SET is_deliverer = TRUE, updated_at = NOW() WHERE id = $1', [user.id]);

        res.json({
            success: true,
            message: `${user.name || user.phone} est maintenant livreur`,
            user_id: user.id
        });
    } catch (err) {
        console.error('Erreur POST /admin/delivery/drivers:', err);
        res.status(500).json({ error: 'Erreur serveur', detail: err.message });
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
        res.status(500).json({ error: 'Erreur serveur', detail: err.message });
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
        res.status(500).json({ error: 'Erreur serveur', detail: err.message });
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
                da.full_name, da.id_document_url, da.vehicle_type, da.vehicle_plate, da.zone,
                da.pledge_fc, da.pledge_status,
                u.name, u.phone, NULL::text AS email, u.avatar_url
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
            conditions.push(`(u.name ILIKE $${paramIndex} OR da.full_name ILIKE $${paramIndex} OR u.phone ILIKE $${paramIndex})`);
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
            pledge_fc: parseFloat(a.pledge_fc) || 0,
            avatar_url: a.avatar_url
                ? (a.avatar_url.startsWith('http') ? a.avatar_url : `${BASE_URL}/uploads/${a.avatar_url}`)
                : null
        }));

        // Stats des candidatures
        let appStats = { total: 0, pending: 0, approved: 0, rejected: 0, pledges_held_count: 0, pledges_held_fc: 0 };
        try {
            const statsResult = await pool.query(`
                SELECT 
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE status = 'pending') as pending,
                    COUNT(*) FILTER (WHERE status = 'approved') as approved,
                    COUNT(*) FILTER (WHERE status = 'rejected') as rejected,
                    COUNT(*) FILTER (WHERE pledge_status = 'held') as pledges_held_count,
                    COALESCE(SUM(pledge_fc) FILTER (WHERE pledge_status = 'held'), 0) as pledges_held_fc
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
                pledges_held_count: parseInt(appStats.pledges_held_count),
                pledges_held_fc: parseFloat(appStats.pledges_held_fc),
            }
        });
    } catch (err) {
        console.error('Erreur GET /admin/delivery/applications:', err);
        res.status(500).json({ error: 'Erreur serveur', detail: err.message });
    }
});

/**
 * PATCH /admin/delivery/applications/:id/approve
 * Approuver une candidature → active is_deliverer sur l'utilisateur
 */
router.patch('/applications/:id/approve', async (req, res) => {
    try {
        const { id } = req.params;

        // Seule une candidature en attente peut être approuvée (une refusée a déjà rendu son gage)
        const updated = await pool.query(
            `UPDATE deliverer_applications
             SET status = 'approved', admin_note = $1, reviewed_at = NOW()
             WHERE id = $2 AND status = 'pending'
             RETURNING user_id, pledge_fc, pledge_status`,
            [req.body.admin_note || 'Approuvé par admin', id]
        );
        if (updated.rows.length === 0) {
            const exists = await pool.query('SELECT status FROM deliverer_applications WHERE id = $1', [id]);
            return exists.rows.length === 0
                ? res.status(404).json({ error: 'Candidature introuvable' })
                : res.status(400).json({ error: `Candidature déjà traitée (${exists.rows[0].status})` });
        }

        const { user_id: userId } = updated.rows[0];

        // Activer le rôle livreur sur l'utilisateur
        await pool.query(
            'UPDATE users SET is_deliverer = TRUE, updated_at = NOW() WHERE id = $1',
            [userId]
        );

        notifyCandidate(req, userId, '🎉 Candidature livreur acceptée',
            'Bienvenue dans l\'équipe ! Ouvrez l\'app Oli Delivery pour commencer vos livraisons. Votre gage reste bloqué comme garantie.');

        res.json({
            success: true,
            message: 'Candidature approuvée — livreur activé',
            user_id: userId
        });
    } catch (err) {
        console.error('Erreur approve application:', err);
        res.status(500).json({ error: 'Erreur serveur', detail: err.message });
    }
});

/**
 * PATCH /admin/delivery/applications/:id/reject
 * Rejeter une candidature
 */
router.patch('/applications/:id/reject', async (req, res) => {
    try {
        const { id } = req.params;
        const note = (req.body.admin_note || '').trim() || 'Rejeté par admin';

        // Le passage à « refusée » et la libération du gage se font en une seule écriture :
        // deux clics simultanés ne peuvent pas rembourser deux fois
        const updated = await pool.query(`
            WITH current AS (
                SELECT id, pledge_status AS was FROM deliverer_applications WHERE id = $1 FOR UPDATE
            )
            UPDATE deliverer_applications da
            SET status = 'rejected', admin_note = $2, reviewed_at = NOW(),
                pledge_status = CASE WHEN current.was = 'held' THEN 'refunded' ELSE da.pledge_status END
            FROM current
            WHERE da.id = current.id AND da.status = 'pending'
            RETURNING da.user_id, da.pledge_fc, da.pledge_reference, current.was AS previous_pledge_status
        `, [id, note]);

        if (updated.rows.length === 0) {
            const exists = await pool.query('SELECT status FROM deliverer_applications WHERE id = $1', [id]);
            return exists.rows.length === 0
                ? res.status(404).json({ error: 'Candidature introuvable' })
                : res.status(400).json({ error: `Candidature déjà traitée (${exists.rows[0].status})` });
        }

        const app = updated.rows[0];
        const pledgeFc = parseFloat(app.pledge_fc) || 0;
        let refunded = false;

        if (app.previous_pledge_status === 'held' && pledgeFc > 0) {
            try {
                await walletRepository.performDeposit(app.user_id, pledgeFc, {
                    type: 'escrow_refund',
                    provider: 'OLI_DELIVERY',
                    reference: `${app.pledge_reference || `DELIVERER_PLEDGE_APP_${id}`}_REFUND`,
                    description: 'Gage livreur rendu (candidature refusée)',
                });
                refunded = true;
            } catch (e) {
                // Retour à l'état d'avant : l'admin peut refuser à nouveau, ce qui retentera le remboursement
                await pool.query(
                    "UPDATE deliverer_applications SET status = 'pending', pledge_status = 'held', admin_note = NULL, reviewed_at = NULL WHERE id = $1",
                    [id]
                );
                console.error(`❌ Gage de la candidature #${id} non rendu:`, e.message);
                return res.status(500).json({ error: 'Le gage n\'a pas pu être rendu : la candidature reste en attente. Réessayez.' });
            }
        }

        notifyCandidate(req, app.user_id, 'Candidature livreur refusée',
            refunded
                ? `Motif : ${note}. Votre gage de ${Math.round(pledgeFc).toLocaleString('fr-FR')} FC a été rendu sur votre wallet Oli.`
                : `Motif : ${note}.`);

        res.json({
            success: true,
            message: refunded ? 'Candidature rejetée — gage rendu au candidat' : 'Candidature rejetée',
            refunded,
        });
    } catch (err) {
        console.error('Erreur reject application:', err);
        res.status(500).json({ error: 'Erreur serveur', detail: err.message });
    }
});

module.exports = router;
