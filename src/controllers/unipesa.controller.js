const walletRepository = require('../repositories/wallet.repository');
const pool = require('../config/db');
const unipesaService = require('../services/unipesa.service');
const { FEES, FC_TO_USD_FALLBACK } = require('../config/index'); // [P1.4]

const FC_TO_USD = FC_TO_USD_FALLBACK; // Depuis config — plus de hardcode
const STATUS    = { SUCCESS: 2, FAILED: 3, PENDING: 1 };

/**
 * Webhook : Confirmation de paiement de COMMANDE (C2B)
 * Le client a validé l'achat d'un produit par Mobile Money.
 */
exports.handleOrderPayment = async (req, res) => {
    try {
        const payload = req.body;
        console.log('📨 Webhook Unipesa C2B (Order Payment) reçu:', JSON.stringify(payload));

        if (!unipesaService.verifyWebhookSignature(payload)) {
            return res.status(403).json({ error: 'Signature invalide' });
        }

        res.status(200).json({ received: true });

        const UNIPESA_CODES = { SUCCESS: 2, FAILED: 3, PENDING: 1 };
        if (parseInt(payload.status) !== UNIPESA_CODES.SUCCESS) {
            return;
        }

        const oliOrderId  = payload.order_id;
        const amount   = parseFloat(payload.amount) || 0;

        if (!oliOrderId || amount <= 0) {
            return;
        }

        const opRes = await pool.query(
            'SELECT * FROM unipesa_operations WHERE oli_order_id = $1 OR unipesa_order_id = $1',
            [oliOrderId]
        );

        if (!opRes.rows.length) {
            return;
        }

        const op = opRes.rows[0];
        if (op.status === 'success') {
            return;
        }

        const userId = op.user_id;
        const targetOrderId = op.target_order_id;

        if (!targetOrderId) {
            console.error('❌ order_payment Webhook : target_order_id manquant');
            return;
        }

        const TOTAL_FEE_RATE = FEES.TOTAL_DEPOSIT_RATE;
        const netAmount = amount / (1 + TOTAL_FEE_RATE);
        const feeAmount = amount - netAmount;

        // 1. Déposer l'argent dans le wallet (pour équilibrer le ledger)
        await walletRepository.performDeposit(userId, netAmount, {
            type:        'deposit',
            provider:    'UNIPESA',
            reference:   oliOrderId + '_DEPOSIT',
            description: `Recharge intermédiaire pour paiement commande #${targetOrderId}`,
        });

        // 2. Prélever immédiatement pour la commande (crée le escrow_lock)
        const walletService = require('../services/wallet.service');
        await walletService.payOrder(userId, netAmount, targetOrderId);

        // 3. Marquer l'opération comme succès
        await pool.query(
            `UPDATE unipesa_operations 
             SET status = 'success', confirmed_at = NOW(), webhook_payload = $1
             WHERE id = $2`,
            [JSON.stringify(payload), op.id]
        );

        // 4. Frais de la Banque OLI
        if (feeAmount > 0) {
            await walletService._creditSystemWallet(
                feeAmount,
                `${oliOrderId}_FEE`,
                `Frais achat direct (User #${userId}) — ${amount} CDF`
            );
        }

        // 5. Mettre à jour la commande OLI
        const orderService = require('../services/order.service');
        const io = req.app ? req.app.get('io') : null;
        await orderService.simulatePayment(targetOrderId, 'mobile_money', io);

        console.log(`✅ Paiement direct commande #${targetOrderId} validé avec succès (user #${userId})`);
    } catch (err) {
        console.error('❌ Erreur traitement webhook handleOrderPayment:', err.message, err.stack);
    }
};

/**
 * Contrôleur Webhooks Unipesa
 *
 * Endpoints attendus :
 *  POST /webhooks/unipesa/deposit    — Confirmation C2B (client → OLI)
 *  POST /webhooks/unipesa/withdrawal — Confirmation B2C (OLI → client)
 */

// Codes de statut Unipesa
const UNIPESA_CODES = {
    INITIATED:   0,
    IN_PROGRESS: 1,
    SUCCESS:     2,
    FAILED:      3,
    CANCELLED:   4,
};

/**
 * Webhook : Confirmation de dépôt (C2B)
 * Le client a validé le paiement Mobile Money → on crédite son Wallet OLI
 */
exports.handleDeposit = async (req, res) => {
    try {
        const payload = req.body;
        console.log('📨 Webhook Unipesa C2B reçu:', JSON.stringify(payload));

        // 1. Vérification de la signature AVANT tout traitement
        if (!unipesaService.verifyWebhookSignature(payload)) {
            console.warn('⚠️ Signature Unipesa invalide — Webhook rejeté.');
            return res.status(403).json({ error: 'Signature invalide' });
        }

        // 2. [FIX B6] Répondre 200 immédiatement à Unipesa pour éviter les retries.
        //    Le traitement se fait en fire-and-forget SÉCURISÉ ci-dessous.
        res.status(200).json({ received: true });

        // 3. Traiter uniquement les statuts SUCCESS (2)
        if (parseInt(payload.status) !== UNIPESA_CODES.SUCCESS) {
            console.log(`ℹ️ Unipesa C2B — Statut non-terminal (${payload.status}), ignoré.`);
            return;
        }

        const orderId  = payload.order_id;
        const amount   = parseFloat(payload.amount) || 0;
        const currency = payload.currency || 'USD';

        if (!orderId || amount <= 0) {
            console.error('❌ Webhook C2B Unipesa invalide: orderId ou montant manquant');
            return;
        }

        // 4. Retrouver l'utilisateur via la référence
        // FORMAT OFFICIEL : DEP-{userId}-{ts} ou WD-{userId}-{ts} (TIRETS)
        // Le regex accepte les tirets uniquement — format standardisé depuis wallet.service et unipesa.service
        const match = orderId.match(/^(DEP|CARD|WD)-(\d+)-\d+/);
        if (!match) {
            console.error(`❌ Format de référence non reconnu: ${orderId} (attendu: DEP-userId-ts ou WD-userId-ts)`);
            return;
        }
        const userId = parseInt(match[2]);

        // 5. Vérifier l'idempotence — éviter le double crédit
        const existing = await pool.query(
            `SELECT status FROM wallet_transactions WHERE reference = $1 AND type = 'deposit'`,
            [orderId]
        );
        if (existing.rows.length > 0) {
            console.log(`ℹ️ Webhook déjà traité pour ${orderId} — ignoré (idempotence).`);
            return;
        }

        // 6. Créditer le Wallet OLI (le wallet est en FC)
        // [P1.4] Taux de frais depuis config centralisée
        const TOTAL_FEE_RATE = FEES.TOTAL_DEPOSIT_RATE; // 6% (3% OLI + 3% Unipesa)
        // Le webhook reçoit le montant BRUT demandé (ex: 1060 FC)
        // Pour retrouver le net (ex: 1000 FC) : net = brut / (1 + 0.06)
        const netAmount = amount / (1 + TOTAL_FEE_RATE);
        const feeAmount = amount - netAmount;

        console.log(`💰 Crédit Wallet OLI : user ${userId} → +${netAmount.toFixed(2)} FC net (${amount} ${currency} brut, ${(TOTAL_FEE_RATE * 100)}% frais)`);

        // Crédit au client (montant net)
        await walletRepository.performDeposit(userId, netAmount, {
            type:        'deposit',
            provider:    'UNIPESA',
            reference:   orderId,
            description: `Recharge Mobile Money confirmée (${payload.provider_id || currency}) — ${amount} ${currency} brut`,
        });

        // Mettre à jour l'état dans unipesa_operations pour que le polling fonctionne
        await pool.query(
            `UPDATE unipesa_operations 
             SET status = 'success', confirmed_at = NOW(), webhook_payload = $1
             WHERE oli_order_id = $2 OR unipesa_order_id = $2`,
            [JSON.stringify(payload), orderId]
        );

        // Crédit des frais à la Banque OLI (user 0)
        if (feeAmount > 0) {
            const walletService = require('../services/wallet.service');
            await walletService._creditSystemWallet(
                feeAmount,
                `${orderId}_FEE`,
                `Frais 6% recharge C2B (User #${userId}) — ${amount} ${currency}`
            );
        }

        console.log(`✅ Wallet crédité: user #${userId} → +${netAmount.toFixed(2)} FC (frais: ${feeAmount.toFixed(2)} FC → Banque OLI)`);

    } catch (err) {
        // La réponse 200 a déjà été envoyée — on logue seulement l'erreur
        console.error('❌ Erreur traitement webhook handleDeposit:', err.message, err.stack);
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
        if (status === UNIPESA_CODES.FAILED || status === UNIPESA_CODES.CANCELLED) {
            await pool.query(
                `UPDATE unipesa_operations 
                 SET status = 'failed', error_message = $1, webhook_payload = $2
                 WHERE oli_order_id = $3 OR unipesa_order_id = $3`,
                [payload.description || 'Echec retrait', JSON.stringify(payload), orderId]
            );

            // FORMAT OFFICIEL : WD-{userId}-{ts} (tirets) — aligné avec wallet.service et unipesa.service
            const match = orderId.match(/^WD-(\d+)-\d+/);
            if (match) {
                const userId = parseInt(match[1]);
                const amount = parseFloat(payload.amount) || 0;
                const currency = payload.currency || 'USD';
                const amountUSD = currency === 'CDF' ? (amount / FC_TO_USD) : amount;

                // Le montant de payload est le net. On avait débité 105%.
                const refundAmount = amountUSD * 1.05;
                const feeToReverse = amountUSD * 0.05;

                console.warn(`↩️ Retrait échoué — Remboursement user ${userId} : +${refundAmount} USD`);

                // 1. Rembourser le client (105%)
                await walletRepository.performDeposit(userId, refundAmount, {
                    type:        'refund',
                    provider:    'UNIPESA',
                    reference:   `${orderId}_REFUND`,
                    description: `Remboursement : échec du retrait Unipesa (statut ${status})`,
                });

                // 2. Annuler les frais de la Banque OLI (débit silencieux)
                try {
                    await pool.query(`UPDATE wallets SET balance = balance - $1 WHERE user_id = 0`, [feeToReverse]);
                    await pool.query(`UPDATE users SET wallet = wallet - $1 WHERE id = 0`, [feeToReverse]);
                } catch (e) {
                    console.error('Erreur reverse fee System Bank:', e);
                }
            }
            return;
        }

        // 4. Si SUCCÈS, on met juste à jour le statut en base de données (le débit avait déjà été fait)
        if (status === UNIPESA_CODES.SUCCESS) {
            console.log(`✅ Retrait Unipesa confirmé : ${orderId}`);
            await pool.query(
                `UPDATE wallet_transactions 
                 SET status = 'completed', description = description || ' [Confirmé par Unipesa]'
                 WHERE reference = $1`,
                [orderId]
            );
            await pool.query(
                `UPDATE unipesa_operations 
                 SET status = 'success', confirmed_at = NOW(), webhook_payload = $1
                 WHERE oli_order_id = $2 OR unipesa_order_id = $2`,
                [JSON.stringify(payload), orderId]
            );
        }

    } catch (err) {
        console.error('Erreur handleWithdrawal Unipesa:', err.message);
    }
};
