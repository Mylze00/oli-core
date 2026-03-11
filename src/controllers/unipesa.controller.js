const walletRepository = require('../repositories/wallet.repository');
const pool = require('../config/db');
const unipesaService = require('../services/unipesa.service');

/**
 * Contrôleur Webhooks Unipesa
 *
 * Endpoints attendus :
 *  POST /webhooks/unipesa/deposit    — Confirmation C2B (client → OLI)
 *  POST /webhooks/unipesa/withdrawal — Confirmation B2C (OLI → client)
 */

// Codes de statut Unipesa
const STATUS = {
    INITIATED:  0,
    IN_PROGRESS: 1,
    SUCCESS:    2,
    FAILED:     3,
    CANCELLED:  4,
};

/**
 * Webhook : Confirmation de dépôt (C2B)
 * Le client a validé le paiement Mobile Money → on crédite son Wallet OLI
 */
exports.handleDeposit = async (req, res) => {
    try {
        const payload = req.body;
        console.log('📨 Webhook Unipesa C2B reçu:', JSON.stringify(payload));

        // 1. Vérification de la signature
        if (!unipesaService.verifyWebhookSignature(payload)) {
            console.warn('⚠️ Signature Unipesa invalide — Webhook rejeté.');
            return res.status(403).json({ error: 'Signature invalide' });
        }

        // 2. On répond immédiatement 200 à Unipesa pour éviter les retries
        res.status(200).json({ received: true });

        // 3. On traite uniquement les statuts SUCCESS (2)
        if (parseInt(payload.status) !== STATUS.SUCCESS) {
            console.log(`ℹ️ Unipesa C2B — Statut non-terminal (${payload.status}), ignoré.`);
            return;
        }

        const orderId    = payload.order_id;
        const amount     = parseFloat(payload.amount) || 0;
        const currency   = payload.currency || 'USD';

        if (!orderId || amount <= 0) {
            console.error('❌ Webhook C2B Unipesa invalide: orderId ou montant manquant');
            return;
        }

        // 4. Retrouver l'utilisateur à partir de la référence (format: DEP_userId_timestamp ou CARD_userId_timestamp)
        const match = orderId.match(/^(DEP|CARD)_(\d+)_\d+/);
        if (!match) {
            console.error(`❌ Format de référence non reconnu: ${orderId}`);
            return;
        }
        const userId = parseInt(match[2]);

        console.log(`💰 Crédit du Wallet OLI : user ${userId} → +${amount} ${currency} (Réf: ${orderId})`);

        // 5. Créditer le Wallet OLI (conversion si nécessaire)
        const amountUSD = currency === 'CDF' ? (amount / 2800) : amount;

        await walletRepository.performDeposit(userId, amountUSD, {
            type:        'deposit',
            provider:    'UNIPESA',
            reference:   orderId,
            description: `Dépôt Mobile Money confirmé par Unipesa (${payload.provider_id || ''})`,
        });

        console.log(`✅ Wallet crédité avec succès : user ${userId} → +${amountUSD} USD`);

    } catch (err) {
        console.error('Erreur handleDeposit Unipesa:', err.message);
    }
};

/**
 * Webhook : Confirmation de retrait (B2C)
 * Unipesa confirme que le client a reçu ses fonds Mobile Money
 */
exports.handleWithdrawal = async (req, res) => {
    try {
        const payload = req.body;
        console.log('📨 Webhook Unipesa B2C reçu:', JSON.stringify(payload));

        // 1. Vérification de la signature
        if (!unipesaService.verifyWebhookSignature(payload)) {
            console.warn('⚠️ Signature Unipesa invalide — Webhook rejeté.');
            return res.status(403).json({ error: 'Signature invalide' });
        }

        // 2. Répondre immédiatement.
        res.status(200).json({ received: true });

        const orderId = payload.order_id;
        const status  = parseInt(payload.status);

        // 3. Si le décaissement a ÉCHOUÉ (status 3), on rembourse le wallet
        if (status === STATUS.FAILED || status === STATUS.CANCELLED) {
            const match = orderId.match(/^WD_(\d+)_\d+/);
            if (match) {
                const userId = parseInt(match[1]);
                const amount = parseFloat(payload.amount) || 0;
                const currency = payload.currency || 'USD';
                const amountUSD = currency === 'CDF' ? (amount / 2800) : amount;

                console.warn(`↩️ Retrait échoué — Remboursement user ${userId} : +${amountUSD} USD`);

                await walletRepository.performDeposit(userId, amountUSD, {
                    type:        'refund',
                    provider:    'UNIPESA',
                    reference:   `${orderId}_REFUND`,
                    description: `Remboursement : échec du retrait Unipesa (statut ${status})`,
                });
            }
            return;
        }

        // 4. Si SUCCÈS, on met juste à jour le statut en base de données (le débit avait déjà été fait)
        if (status === STATUS.SUCCESS) {
            console.log(`✅ Retrait Unipesa confirmé : ${orderId}`);
            await pool.query(
                `UPDATE wallet_transactions 
                 SET status = 'completed', description = description || ' [Confirmé par Unipesa]'
                 WHERE reference = $1`,
                [orderId]
            );
        }

    } catch (err) {
        console.error('Erreur handleWithdrawal Unipesa:', err.message);
    }
};
