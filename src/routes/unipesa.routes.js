/**
 * Unipesa Routes â€” Mobile Money Integration (AgrÃ©gateur C2B/B2C)
 *
 * PrÃ©fixe de montage : /api/unipesa  (dÃ©fini dans server.js)
 *
 * âš ï¸  CES ROUTES SONT RÃ‰SERVÃ‰ES AU FLUX INTERNE UNIPESA.
 *     Le flux principal Mobile Money passe par /api/wallet (wallet.routes.js).
 *
 * Endpoints disponibles :
 *   POST /api/unipesa/deposit          â†’ Initier une recharge C2B (alias direct Unipesa)
 *   GET  /api/unipesa/status/:orderId  â†’ Statut d'une opÃ©ration (polling alternatif)
 *   POST /api/unipesa/webhook          â†’ OBSOLÃˆTE (410 Gone) â€” utiliser /webhooks/unipesa/deposit
 *
 * ðŸ“Œ  ROUTES WALLET SUPPRIMÃ‰ES (anti-duplication) :
 *     /api/unipesa/wallet/balance  â†’ maintenant sur /api/wallet/balance
 *     /api/unipesa/wallet/history  â†’ maintenant sur /api/wallet/transactions
 */

const express         = require('express');
const router          = express.Router();
const unipesa         = require('../services/unipesa.service');
const walletRepo      = require('../repositories/wallet.repository');
const { authenticateToken } = require('../middlewares/auth.middleware');

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// POST /api/unipesa/deposit
//
// Initie une recharge Mobile Money â†’ Wallet OLI (C2B).
// Endpoint alternatif Ã  POST /api/wallet/deposit â€” mÃªme flux interne.
//
// Body : { phone: string, amountFC: number }
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.post('/deposit', authenticateToken, async (req, res) => {
    try {
        const { phone, amountFC } = req.body;
        const userId = req.user.id;

        // â”€â”€ Validations â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (!phone) {
            return res.status(400).json({
                success: false,
                error: 'NumÃ©ro de tÃ©lÃ©phone Mobile Money requis',
            });
        }

        if (!amountFC || isNaN(amountFC) || parseFloat(amountFC) <= 0) {
            return res.status(400).json({
                success: false,
                error: 'Montant invalide. Entrez un montant positif en FC.',
            });
        }

        const amount = parseFloat(amountFC);

        if (amount < 500) {
            return res.status(400).json({
                success: false,
                error: 'Montant minimum de recharge : 500 FC',
            });
        }

        if (amount > 10_000_000) {
            return res.status(400).json({
                success: false,
                error: 'Montant maximum de recharge : 10 000 000 FC',
            });
        }

        // â”€â”€ Initier le paiement Unipesa (C2B) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        // Appel direct au service â€” mÃªme rÃ©sultat que via wallet.routes /deposit
        const result = await unipesa.initiateDeposit(userId, phone, amount);

        console.log(`ðŸ“² [Unipesa] DÃ©pÃ´t initiÃ©: user #${userId} â€” ${amount} FC via ${phone}`);

        return res.status(200).json({
            success:         true,
            message:         'Paiement initiÃ©. Validez sur votre tÃ©lÃ©phone.',
            oliOrderId:      result.oliOrderId,
            status:          'pending',
            // â”€â”€ DÃ©tail des frais â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            amountFC:        result.amountFC,         // Montant brut (FC)
            aggregatorFeeFC: result.aggregatorFeeFC,  // 3% frais Unipesa (FC)
            oliFeeFC:        result.oliFeeFC,          // 3% commission OLI (FC)
            totalFeeFC:      result.totalFeeFC,        // 6% total (FC)
            netAmountFC:     result.netAmountFC,       // Montant crÃ©ditÃ© wallet (FC)
            // â”€â”€ Infos Mobile Money â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            provider:        result.provider,          // Vodacom | Airtel | Orange | Africell
            phone:           result.phone,
        });

    } catch (err) {
        console.error('âŒ POST /api/unipesa/deposit:', err.message);
        return res.status(500).json({
            success: false,
            error: err.message || "Impossible d'initier le paiement",
        });
    }
});

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/unipesa/status/:orderId
//
// Polling de statut â€” alternatif Ã  GET /api/wallet/status/:orderId
// AppelÃ© par Flutter toutes les ~5 secondes.
//
// Statuts retournÃ©s : pending | success | failed | timeout
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ─────────────────────────────────────────────────────────────────────────────
// POST /api/unipesa/withdraw
//
// Initiation d'un retrait (B2C) via Unipesa.
// ─────────────────────────────────────────────────────────────────────────────
router.post('/withdraw', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const { amountFC, phone } = req.body;

        const parsedAmount = parseFloat(amountFC);
        if (!parsedAmount || isNaN(parsedAmount) || parsedAmount < 500) {
            return res.status(400).json({ error: "Montant minimum : 500 FC" });
        }
        if (!phone) {
            return res.status(400).json({ error: "Numéro de téléphone requis" });
        }

        // Appel au service Unipesa B2C
        const result = await unipesa.initiateWithdrawal(userId, phone, parsedAmount);

        return res.status(200).json({
            success: true,
            oliOrderId: result.oliOrderId,
            amountFC: result.amountFC,
            message: "Retrait initié, en attente de validation",
        });

    } catch (err) {
        console.error('❌ POST /api/unipesa/withdraw:', err.message);
        return res.status(500).json({
            success: false,
            error: err.message || "Impossible d'initier le retrait",
        });
    }
});

router.get('/status/:orderId', authenticateToken, async (req, res) => {
    try {
        const { orderId } = req.params;
        const userId      = req.user.id;

        // VÃ©rifier que l'opÃ©ration appartient Ã  cet utilisateur
        const { rows } = await require('../config/db').query(
            'SELECT user_id, status FROM unipesa_operations WHERE oli_order_id = $1',
            [orderId]
        );

        if (!rows.length || parseInt(rows[0].user_id) !== parseInt(userId)) {
            return res.status(404).json({
                success: false,
                error:   'OpÃ©ration introuvable ou non autorisÃ©e',
            });
        }

        const result = await unipesa.checkOperationStatus(orderId);

        // Si succÃ¨s â†’ retourner le nouveau solde
        let wallet = null;
        if (result.status === 'success') {
            const w = await walletRepo.getWallet(userId);
            wallet = {
                balanceFC:  parseFloat(w.balance),
                currency:   w.currency || 'FC',
                is_frozen:  w.is_frozen,
                updated_at: w.updated_at,
            };
        }

        return res.json({
            success:  true,
            orderId,
            status:   result.status,    // pending | success | failed | timeout
            amountFC: result.amountFC,
            provider: result.provider,
            wallet,
        });

    } catch (err) {
        console.error('âŒ GET /api/unipesa/status:', err.message);
        return res.status(500).json({ success: false, error: err.message });
    }
});

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// POST /api/unipesa/webhook  â€” OBSOLÃˆTE (410 Gone)
//
// âš ï¸  CET ENDPOINT EST DÃ‰SACTIVÃ‰ â€” risque de double crÃ©dit wallet.
//
//     L'endpoint officiel Unipesa est : POST /webhooks/unipesa/deposit
//     (gÃ©rÃ© dans webhook.routes.js â†’ unipesa.controller.handleDeposit)
//
//     Configurez votre dashboard Unipesa sur :
//         https://votre-domaine.com/webhooks/unipesa/deposit
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.post('/webhook', (req, res) => {
    console.warn('âš ï¸ Webhook reÃ§u sur /api/unipesa/webhook â€” ENDPOINT OBSOLÃˆTE (410 Gone).');
    console.warn('   â†’ Configurez Unipesa sur : POST /webhooks/unipesa/deposit');
    return res.status(410).json({
        success:          false,
        error:            'Endpoint obsolÃ¨te (410 Gone)',
        message:          'Ce webhook a Ã©tÃ© dÃ©placÃ©. Configurez Unipesa sur : POST /webhooks/unipesa/deposit',
        official_webhook: '/webhooks/unipesa/deposit',
    });
});

module.exports = router;

