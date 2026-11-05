const unipesaService = require('../services/unipesa.service');
const settlement = require('../services/unipesa-settlement.service');

/**
 * Contrôleur Webhooks Unipesa
 *
 * Endpoints (publics, sécurisés par signature HMAC-SHA512) :
 *  POST /webhooks/unipesa/deposit    — Confirmation C2B (client → OLI)
 *  POST /webhooks/unipesa/withdrawal — Confirmation B2C (OLI → client)
 *
 * Règles :
 *  - Signature vérifiée AVANT toute réponse ou traitement : sans signature valide → 403.
 *  - Montants pris dans unipesa_operations (jamais dans le webhook).
 *  - Règlement une seule fois (settled_at) : un rejeu ne crédite ni ne rembourse à nouveau.
 */

// Codes de statut Unipesa utilisés par le webhook
const UNIPESA_CODES = {
    INITIATED:   0,
    IN_PROGRESS: 1,
    SUCCESS:     2,
    FAILED:      3,
    CANCELLED:   4,
};

/**
 * Webhook : Confirmation de dépôt (C2B)
 */
exports.handleDeposit = async (req, res) => {
    const payload = req.body || {};

    if (!unipesaService.verifyWebhookSignature(payload)) {
        console.warn('🚫 Webhook Unipesa C2B rejeté : signature invalide ou absente.');
        return res.status(403).json({ error: 'Signature invalide' });
    }

    // Réponse immédiate à Unipesa (évite les retries) ; le traitement suit
    res.status(200).json({ received: true });

    try {
        if (parseInt(payload.status) !== UNIPESA_CODES.SUCCESS) {
            console.log(`ℹ️ Unipesa C2B — statut non terminal (${payload.status}), ignoré.`);
            return;
        }

        // Référence attendue : DEP-<userId>-<ts> (ou CARD-<userId>-<ts>)
        const orderId = String(payload.order_id || '');
        const match = orderId.match(/^(DEP|CARD)-(\d+)-\d+$/);
        if (!match) {
            console.error(`❌ Référence Unipesa non reconnue: ${orderId}`);
            return;
        }
        const userId = parseInt(match[2], 10);

        const result = await settlement.settleDeposit(orderId, userId);

        if (result.status !== 'credited') {
            console.warn(`ℹ️ Dépôt ${orderId} non crédité : ${result.status}`);
            return;
        }

        console.log(`✅ Wallet crédité: user #${result.userId} → +${result.netFC.toFixed(2)} FC (frais: ${result.feeFC.toFixed(2)} FC)`);

        // Notifier le client (socket + FCM) pour débloquer l'app
        try {
            const notifService = require('../services/notification.service');
            await notifService.send(
                result.userId,
                'wallet_deposit',
                'Recharge réussie !',
                `Votre dépôt de ${result.grossFC} FC a été confirmé.`,
                { orderId, amount: result.grossFC, netAmount: result.netFC, status: 'success' },
                req.app ? req.app.get('io') : null
            );
        } catch (e) {
            console.error('Erreur notification dépôt:', e.message);
        }
    } catch (err) {
        // La réponse 200 est déjà envoyée : on journalise seulement
        console.error('❌ Erreur traitement webhook handleDeposit:', err.message);
    }
};

/**
 * Webhook : Confirmation ou échec de retrait (B2C)
 */
exports.handleWithdrawal = async (req, res) => {
    const payload = req.body || {};

    if (!unipesaService.verifyWebhookSignature(payload)) {
        console.warn('🚫 Webhook Unipesa B2C rejeté : signature invalide ou absente.');
        return res.status(403).json({ error: 'Signature invalide' });
    }

    res.status(200).json({ received: true });

    try {
        const orderId = String(payload.order_id || '');
        const match = orderId.match(/^WD-(\d+)-\d+$/);
        if (!match) {
            console.error(`❌ Référence de retrait non reconnue: ${orderId}`);
            return;
        }
        const userId = parseInt(match[1], 10);
        const status = parseInt(payload.status, 10);

        if (status === UNIPESA_CODES.FAILED || status === UNIPESA_CODES.CANCELLED) {
            const result = await settlement.settleWithdrawalFailure(orderId, userId);
            console.log(`↩️ Retrait ${orderId} en échec : ${result.status}`);
            return;
        }

        if (status === UNIPESA_CODES.SUCCESS) {
            const result = await settlement.settleWithdrawalSuccess(orderId, userId);
            console.log(`✅ Retrait Unipesa confirmé : ${orderId} (${result.status})`);
        }
    } catch (err) {
        console.error('Erreur handleWithdrawal Unipesa:', err.message);
    }
};
