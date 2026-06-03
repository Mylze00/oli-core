/**
 * OLI Bank Routes — Portail Cryptographique
 *
 * GET  /bank/portal              → Vue 360° de l'utilisateur
 * GET  /bank/ledger              → Grand Livre personnel
 * GET  /bank/verify/:txHash      → Vérifier l'intégrité d'une TX
 * GET  /bank/escrow              → Mes escrows actifs
 * POST /bank/escrow/:orderId/release → (admin/système) Libérer un escrow
 * POST /bank/escrow/:orderId/refund  → (admin/système) Rembourser un escrow
 * POST /bank/init                → (interne) Initialiser le portail d'un user
 * GET  /bank/address             → Récupérer son adresse OLI publique
 */

const express   = require('express');
const router    = express.Router();
const oliBank   = require('../services/oli_bank.service');
const pool      = require('../config/db');

// Middleware auth (à importer depuis votre middleware existant)
const { authenticateToken } = require('../middlewares/auth.middleware');
const { isAdmin }           = require('../middlewares/admin.middleware');

// ─────────────────────────────────────────────────────────────────────────────
// Portail & Identité
// ─────────────────────────────────────────────────────────────────────────────

/**
 * GET /bank/portal
 * Vue 360° de l'utilisateur : solde, ledger, escrows, sessions, score.
 */
router.get('/portal', authenticateToken, async (req, res) => {
    try {
        const portal = await oliBank.getUserPortal(req.user.id);
        res.json({ success: true, portal });
    } catch (err) {
        console.error('Erreur GET /bank/portal:', err.message);
        res.status(500).json({ error: 'Impossible de charger le portail' });
    }
});

/**
 * GET /bank/address
 * Retourne l'adresse OLI publique de l'utilisateur.
 */
router.get('/address', authenticateToken, async (req, res) => {
    try {
        const res2 = await pool.query(
            'SELECT oli_address, public_key, created_at, last_used_at FROM oli_bank_keypairs WHERE user_id = $1',
            [req.user.id]
        );
        if (!res2.rows.length) {
            // Initialiser si inexistant
            const init = await oliBank.initializeUserPortal(req.user.id);
            return res.json({ success: true, ...init, isNew: true });
        }
        const kp = res2.rows[0];
        res.json({
            success: true,
            oliAddress:  kp.oli_address,
            publicKey:   kp.public_key,
            createdAt:   kp.created_at,
            lastUsedAt:  kp.last_used_at,
        });
    } catch (err) {
        console.error('Erreur GET /bank/address:', err.message);
        res.status(500).json({ error: 'Impossible de récupérer l\'adresse OLI' });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
// Grand Livre
// ─────────────────────────────────────────────────────────────────────────────

/**
 * GET /bank/ledger?limit=50&offset=0
 * Historique du Grand Livre personnel, paginé.
 */
router.get('/ledger', authenticateToken, async (req, res) => {
    try {
        const limit  = Math.min(parseInt(req.query.limit)  || 50, 200);
        const offset = Math.max(parseInt(req.query.offset) || 0, 0);
        const ledger = await oliBank.getLedger(req.user.id, limit, offset);
        res.json({ success: true, ledger, count: ledger.length, limit, offset });
    } catch (err) {
        console.error('Erreur GET /bank/ledger:', err.message);
        res.status(500).json({ error: 'Impossible de charger le ledger' });
    }
});

/**
 * GET /bank/verify/:txHash
 * Vérifie l'intégrité cryptographique d'une transaction.
 * Accessible publiquement (pour audit externe).
 */
router.get('/verify/:txHash', async (req, res) => {
    try {
        const result = await oliBank.verifyTransaction(req.params.txHash);
        res.json({ success: true, ...result });
    } catch (err) {
        console.error('Erreur GET /bank/verify:', err.message);
        res.status(500).json({ error: 'Impossible de vérifier la transaction' });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
// Escrow
// ─────────────────────────────────────────────────────────────────────────────

/**
 * GET /bank/escrow
 * Retourne les escrows actifs de l'utilisateur (acheteur ou vendeur).
 */
router.get('/escrow', authenticateToken, async (req, res) => {
    try {
        const uid = req.user.id;
        const result = await pool.query(`
            SELECT e.*, 
                   u_buyer.name AS buyer_name,
                   u_seller.name AS seller_name,
                   u_deliverer.name AS deliverer_name,
                   o.status AS order_status
            FROM   oli_bank_escrow e
            JOIN   users u_buyer    ON u_buyer.id    = e.buyer_id
            JOIN   users u_seller   ON u_seller.id   = e.seller_id
            LEFT JOIN users u_deliverer ON u_deliverer.id = e.deliverer_id
            LEFT JOIN orders o ON o.id = e.order_id
            WHERE  (e.buyer_id = $1 OR e.seller_id = $1 OR e.deliverer_id = $1)
            ORDER BY e.locked_at DESC
            LIMIT 50
        `, [uid]);

        res.json({
            success: true,
            escrows: result.rows.map(e => ({
                ...e,
                amount_locked: parseFloat(e.amount_locked),
                seller_amount: parseFloat(e.seller_amount),
                deliverer_amount: parseFloat(e.deliverer_amount),
                oli_fee: parseFloat(e.oli_fee),
            })),
        });
    } catch (err) {
        console.error('Erreur GET /bank/escrow:', err.message);
        res.status(500).json({ error: 'Impossible de charger les escrows' });
    }
});

/**
 * POST /bank/escrow/:orderId/release
 * Libère l'escrow (vendeur reçoit son paiement).
 *
 * [P1.3] Règles de sécurité :
 *   - L'acheteur peut confirmer la réception → trigger: 'delivery_confirmed'
 *   - Un admin peut forcer la libération   → trigger: 'admin_override'
 *   - Le vendeur ne peut PAS libérer son propre escrow (conflit d'intérêt)
 *   - Un tiers n'a aucun droit sur cet escrow
 */
router.post('/escrow/:orderId/release', authenticateToken, async (req, res) => {
    try {
        const orderId = parseInt(req.params.orderId);
        const callerId = req.user.id;
        const isAdmin  = req.user.is_admin === true;

        // Récupérer l'escrow pour vérifier la propriété
        const { rows } = await pool.query(
            'SELECT buyer_id, seller_id, status FROM oli_bank_escrow WHERE order_id = $1',
            [orderId]
        );

        if (!rows.length) {
            return res.status(404).json({ error: `Aucun escrow trouvé pour la commande #${orderId}` });
        }

        const escrow = rows[0];

        // Vérifier que l'escrow est bien en statut 'locked'
        if (escrow.status !== 'locked') {
            return res.status(409).json({
                error: `Impossible de libérer : escrow en statut '${escrow.status}'`,
            });
        }

        // [SÉCURITÉ] Seul l'acheteur ou un admin peut libérer
        const isBuyer = parseInt(escrow.buyer_id) === parseInt(callerId);
        if (!isBuyer && !isAdmin) {
            console.warn(`🚨 Tentative non autorisée: user #${callerId} → release escrow order #${orderId} (buyer: #${escrow.buyer_id})`);
            return res.status(403).json({
                error: 'Seul l\'acheteur ou un administrateur peut confirmer la réception et libérer le paiement.',
            });
        }

        const trigger = isAdmin ? (req.body.trigger || 'admin_override') : 'delivery_confirmed';
        const result  = await oliBank.releaseEscrow(orderId, trigger);

        console.log(`✅ Escrow libéré: commande #${orderId} par user #${callerId} (${isAdmin ? 'admin' : 'acheteur'})`);
        res.json({ success: true, ...result });

    } catch (err) {
        console.error('Erreur POST /bank/escrow/release:', err.message);
        res.status(400).json({ error: err.message });
    }
});

/**
 * POST /bank/escrow/:orderId/refund
 * Rembourse l'acheteur depuis l'escrow (annulation ou litige).
 *
 * [P1.3] Règles de sécurité :
 *   - L'acheteur peut demander un remboursement (annulation)
 *   - Le vendeur peut initier un remboursement (si commande annulée de son côté)
 *   - Un admin peut forcer un remboursement
 *   - Un tiers n'a aucun accès
 */
router.post('/escrow/:orderId/refund', authenticateToken, async (req, res) => {
    try {
        const orderId  = parseInt(req.params.orderId);
        const callerId = req.user.id;
        const isAdmin  = req.user.is_admin === true;

        // Récupérer l'escrow pour vérifier la propriété
        const { rows } = await pool.query(
            'SELECT buyer_id, seller_id, status FROM oli_bank_escrow WHERE order_id = $1',
            [orderId]
        );

        if (!rows.length) {
            return res.status(404).json({ error: `Aucun escrow trouvé pour la commande #${orderId}` });
        }

        const escrow = rows[0];

        // Vérifier que l'escrow est remboursable (locked ou disputed)
        if (!['locked', 'disputed'].includes(escrow.status)) {
            return res.status(409).json({
                error: `Impossible de rembourser : escrow en statut '${escrow.status}'`,
            });
        }

        // [SÉCURITÉ] Seuls l'acheteur, le vendeur ou un admin peuvent rembourser
        const isBuyer  = parseInt(escrow.buyer_id)  === parseInt(callerId);
        const isSeller = parseInt(escrow.seller_id) === parseInt(callerId);
        if (!isBuyer && !isSeller && !isAdmin) {
            console.warn(`🚨 Tentative non autorisée: user #${callerId} → refund escrow order #${orderId}`);
            return res.status(403).json({
                error: 'Accès refusé. Seuls l\'acheteur, le vendeur ou un administrateur peuvent demander un remboursement.',
            });
        }

        const reason = req.body.reason || (isAdmin ? 'admin_decision' : 'order_cancelled');
        const result = await oliBank.refundEscrow(orderId, reason);

        console.log(`💸 Escrow remboursé: commande #${orderId} par user #${callerId} (${isAdmin ? 'admin' : isBuyer ? 'acheteur' : 'vendeur'})`);
        res.json({ success: true, ...result });

    } catch (err) {
        console.error('Erreur POST /bank/escrow/refund:', err.message);
        res.status(400).json({ error: err.message });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
// Administration
// ─────────────────────────────────────────────────────────────────────────────

/**
 * POST /bank/init
 * Initialise le portail OLI Bank d'un utilisateur.
 * Appelé automatiquement lors de l'inscription.
 */
router.post('/init', authenticateToken, async (req, res) => {
    try {
        const result = await oliBank.initializeUserPortal(req.user.id);
        res.json({ success: true, ...result });
    } catch (err) {
        console.error('Erreur POST /bank/init:', err.message);
        res.status(500).json({ error: 'Impossible d\'initialiser le portail' });
    }
});

/**
 * GET /bank/stats (admin)
 * Statistiques globales de la Banque OLI.
 */
router.get('/stats', authenticateToken, isAdmin, async (req, res) => {
    try {
        const stats = await pool.query(`
            SELECT
                (SELECT COUNT(*) FROM oli_bank_keypairs) AS total_users_registered,
                (SELECT COUNT(*) FROM oli_bank_ledger)   AS total_ledger_entries,
                (SELECT COALESCE(SUM(amount_locked),0) FROM oli_bank_escrow WHERE status = 'locked') AS total_escrow_locked,
                (SELECT balance FROM wallets WHERE user_id = 0) AS bank_revenue,
                (SELECT COUNT(*) FROM user_sessions_ext WHERE is_suspicious = TRUE) AS suspicious_sessions,
                (SELECT COUNT(*) FROM oli_bank_events WHERE severity = 'critical' AND processed = FALSE) AS unprocessed_critical_events
        `);
        res.json({ success: true, stats: stats.rows[0] });
    } catch (err) {
        console.error('Erreur GET /bank/stats:', err.message);
        res.status(500).json({ error: 'Impossible de charger les statistiques' });
    }
});

module.exports = router;
