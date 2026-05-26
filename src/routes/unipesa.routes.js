/**
 * Unipesa Routes — Mobile Money Integration
 *
 * POST /api/unipesa/deposit          → Initier une recharge Mobile Money
 * GET  /api/unipesa/status/:orderId  → Statut d'une recharge (polling Flutter)
 * POST /api/unipesa/webhook          → Callback Unipesa (confirmation de paiement)
 * GET  /api/wallet/balance           → Solde du wallet de l'utilisateur
 * GET  /api/wallet/history           → Historique des transactions
 */

const express         = require('express');
const router          = express.Router();
const unipesa         = require('../services/unipesa.service');
const walletRepo      = require('../repositories/wallet.repository');
const { authenticateToken } = require('../middlewares/auth.middleware');

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/unipesa/deposit
// Initie une recharge Mobile Money → Wallet OLI
// Appelé par l'application Flutter quand l'utilisateur clique sur "Recharger"
// ─────────────────────────────────────────────────────────────────────────────
router.post('/deposit', authenticateToken, async (req, res) => {
    try {
        const { phone, amountFC } = req.body;
        const userId = req.user.id;

        // ── Validations ──────────────────────────────────────────────────────
        if (!phone) {
            return res.status(400).json({
                success: false,
                error: 'Numéro de téléphone Mobile Money requis',
            });
        }

        if (!amountFC || isNaN(amountFC) || parseFloat(amountFC) <= 0) {
            return res.status(400).json({
                success: false,
                error: 'Montant invalide. Entrez un montant positif en FC.',
            });
        }

        const amount = parseFloat(amountFC);

        // Montant minimum de recharge : 500 FC
        if (amount < 500) {
            return res.status(400).json({
                success: false,
                error: 'Montant minimum de recharge : 500 FC',
            });
        }

        // Montant maximum : 10 000 000 FC (sécurité)
        if (amount > 10_000_000) {
            return res.status(400).json({
                success: false,
                error: 'Montant maximum de recharge : 10 000 000 FC',
            });
        }

        // ── Initier le paiement Unipesa ──────────────────────────────────────
        const result = await unipesa.initiateDeposit(userId, phone, amount);

        console.log(`📲 Dépôt initié: user #${userId} — ${amount} FC via ${phone}`);

        return res.status(200).json({
            success:         true,
            message:         'Paiement initié. Validez sur votre téléphone.',
            oliOrderId:      result.oliOrderId,
            status:          'pending',
            // ── Détail des frais (affiché à l'utilisateur dans l'app) ──
            amountFC:        result.amountFC,        // Montant brut envoyé depuis Mobile Money
            aggregatorFeeFC: result.aggregatorFeeFC, // 3% frais Unipesa
            oliFeeFC:        result.oliFeeFC,         // 3% commission OLI
            totalFeeFC:      result.totalFeeFC,       // 6% total
            netAmountFC:     result.netAmountFC,      // Montant crédité sur votre wallet OLI
            // ── Infos Mobile Money ──
            provider:        result.provider,
            phone:           result.phone,
        });

    } catch (err) {
        console.error('❌ POST /unipesa/deposit:', err.message);
        return res.status(500).json({
            success: false,
            error: err.message || 'Impossible d\'initier le paiement',
        });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/unipesa/status/:orderId
// Polling de statut — appelé par Flutter toutes les 5 secondes
// ─────────────────────────────────────────────────────────────────────────────
router.get('/status/:orderId', authenticateToken, async (req, res) => {
    try {
        const { orderId } = req.params;
        const userId      = req.user.id;

        // Vérifier que l'opération appartient bien à cet utilisateur
        const { rows } = await require('../config/db').query(
            'SELECT user_id FROM unipesa_operations WHERE oli_order_id = $1',
            [orderId]
        );

        if (!rows.length || parseInt(rows[0].user_id) !== parseInt(userId)) {
            return res.status(404).json({ success: false, error: 'Opération introuvable' });
        }

        const result = await unipesa.checkOperationStatus(orderId);

        // Si succès, retourner le nouveau solde
        let wallet = null;
        if (result.status === 'success') {
            wallet = await walletRepo.getWallet(userId);
        }

        return res.json({
            success:   true,
            orderId,
            status:    result.status,    // pending | success | failed | timeout
            amountFC:  result.amountFC,
            provider:  result.provider,
            wallet,                      // nouveau solde si succès
        });

    } catch (err) {
        console.error('❌ GET /unipesa/status:', err.message);
        return res.status(500).json({ success: false, error: err.message });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/unipesa/webhook
// Endpoint PUBLIC appelé par les serveurs Unipesa pour confirmer un paiement.
// ⚠️  PAS de middleware d'authentification utilisateur ici.
// ⚠️  La sécurité repose sur la vérification de signature HMAC-SHA512.
// ─────────────────────────────────────────────────────────────────────────────
router.post('/webhook', async (req, res) => {
    try {
        const body = req.body;
        console.log('📩 Webhook Unipesa reçu:', JSON.stringify(body));

        // ── Vérifier la signature HMAC ───────────────────────────────────────
        const isValid = unipesa.verifyWebhookSignature(body);
        if (!isValid) {
            console.warn('🚨 Webhook Unipesa rejeté: signature invalide');
            return res.status(401).json({ success: false, error: 'Signature invalide' });
        }

        // ── Traiter le webhook ────────────────────────────────────────────────
        const result = await unipesa.processWebhook(body);

        // Répondre rapidement à Unipesa (ils attendent une réponse rapide)
        return res.status(200).json({ success: true, ...result });

    } catch (err) {
        console.error('❌ POST /unipesa/webhook:', err.message);
        // On retourne quand même 200 pour éviter les re-tentatives en boucle
        return res.status(200).json({ success: false, error: err.message });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/wallet/balance
// Retourne le solde et les infos du wallet de l'utilisateur connecté
// ─────────────────────────────────────────────────────────────────────────────
router.get('/wallet/balance', authenticateToken, async (req, res) => {
    try {
        const wallet = await walletRepo.getWallet(req.user.id);
        return res.json({
            success:   true,
            balance:   wallet.balance,
            currency:  wallet.currency,
            is_frozen: wallet.is_frozen,
            updated_at: wallet.updated_at,
        });
    } catch (err) {
        console.error('❌ GET /wallet/balance:', err.message);
        return res.status(500).json({ success: false, error: err.message });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/wallet/history?limit=20&offset=0
// Historique des transactions du wallet
// ─────────────────────────────────────────────────────────────────────────────
router.get('/wallet/history', authenticateToken, async (req, res) => {
    try {
        const limit  = Math.min(parseInt(req.query.limit)  || 20, 100);
        const offset = Math.max(parseInt(req.query.offset) || 0,  0);

        const history = await walletRepo.getHistory(req.user.id, limit, offset);

        return res.json({
            success: true,
            history,
            count:   history.length,
            limit,
            offset,
        });
    } catch (err) {
        console.error('❌ GET /wallet/history:', err.message);
        return res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;
