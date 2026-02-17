/**
 * Routes Candidature Livreur
 * Permet à tout utilisateur authentifié de postuler pour devenir livreur
 */
const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { requireAuth } = require('../middlewares/auth.middleware');

// ─── Auto-migration : créer la table si elle n'existe pas ──────

(async () => {
    try {
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
        console.log('✅ Table deliverer_applications prête');
    } catch (err) {
        console.error('❌ Erreur migration deliverer_applications:', err.message);
    }
})();

/**
 * POST /delivery/apply
 * Soumettre une candidature pour devenir livreur
 * Body: { pledge_amount, motivation? }
 */
router.post('/', requireAuth, async (req, res) => {
    const userId = req.user.id;
    const { pledge_amount, motivation } = req.body;

    if (!pledge_amount || parseFloat(pledge_amount) <= 0) {
        return res.status(400).json({ error: "Le montant de gage doit être supérieur à 0" });
    }

    try {
        // Vérifier si déjà livreur
        const userCheck = await pool.query('SELECT is_deliverer FROM users WHERE id = $1', [userId]);
        if (userCheck.rows[0]?.is_deliverer) {
            return res.status(400).json({ error: "Vous êtes déjà un livreur enregistré" });
        }

        // Vérifier s'il y a déjà une candidature
        const existing = await pool.query(
            'SELECT id, status FROM deliverer_applications WHERE user_id = $1',
            [userId]
        );

        if (existing.rows.length > 0) {
            const app = existing.rows[0];
            if (app.status === 'pending') {
                return res.status(400).json({ error: "Vous avez déjà une candidature en attente" });
            }
            if (app.status === 'approved') {
                return res.status(400).json({ error: "Votre candidature a déjà été approuvée" });
            }
            // Si rejetée, permettre de re-postuler
            await pool.query(
                `UPDATE deliverer_applications 
                 SET pledge_amount = $1, motivation = $2, status = 'pending', 
                     admin_note = NULL, reviewed_at = NULL, created_at = NOW()
                 WHERE user_id = $3`,
                [parseFloat(pledge_amount), motivation || '', userId]
            );

            return res.json({
                success: true,
                message: "Nouvelle candidature soumise avec succès"
            });
        }

        // Créer la candidature
        const phone = req.user.phone || '';
        await pool.query(
            `INSERT INTO deliverer_applications (user_id, pledge_amount, phone, motivation, status)
             VALUES ($1, $2, $3, $4, 'pending')`,
            [userId, parseFloat(pledge_amount), phone, motivation || '']
        );

        res.status(201).json({
            success: true,
            message: "Candidature soumise avec succès. Vous serez notifié une fois approuvé."
        });

    } catch (err) {
        console.error('❌ Erreur candidature livreur:', err.message);
        res.status(500).json({ error: "Erreur lors de la soumission" });
    }
});

/**
 * GET /delivery/apply/status
 * Vérifier le statut de sa candidature
 */
router.get('/status', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT id, pledge_amount, status, admin_note, created_at, reviewed_at 
             FROM deliverer_applications WHERE user_id = $1`,
            [req.user.id]
        );

        if (result.rows.length === 0) {
            return res.json({ status: 'none', message: "Aucune candidature trouvée" });
        }

        res.json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
