/**
 * Unipesa Service
 *
 * Encapsule tous les appels vers l'API Unipesa (agrégateur Mobile Money).
 *
 * Opérations supportées :
 *   - C2B (Customer to Business) : Recharge Mobile Money → Wallet OLI
 *   - Vérification de statut     : Interroger le statut d'une opération
 *   - Vérification de signature  : Valider qu'un webhook vient bien d'Unipesa
 *
 * Documentation Unipesa : https://api.unipesa.tech
 */

const axios   = require('axios');
const crypto  = require('crypto');
const pool    = require('../config/db');

// ─────────────────────────────────────────────────────────────────────────────
// CONFIGURATION
// ─────────────────────────────────────────────────────────────────────────────

const UNIPESA_API_URL   = process.env.UNIPESA_API_URL   || 'https://api.unipesa.tech';
const UNIPESA_PUBLIC_ID = process.env.UNIPESA_PUBLIC_ID || '';
const UNIPESA_SECRET    = process.env.UNIPESA_SECRET_KEY || '';
const UNIPESA_MERCHANT  = process.env.UNIPESA_MERCHANT_ID || '';

// ─────────────────────────────────────────────────────────────────────────────
// STRUCTURE DE FRAIS (configurable via .env)
// ─────────────────────────────────────────────────────────────────────────────
// OLI prélève 3% de commission sur chaque recharge Mobile Money.
// Unipesa (l'agrégateur) prélève 3% de frais de traitement.
// Total : 6% déduit du montant brut envoyé par l'utilisateur.
//
// Exemple : l'utilisateur envoie 10 000 FC
//   → Frais Unipesa : 300 FC (3%)
//   → Commission OLI : 300 FC (3%)
//   → Montant crédité sur le wallet : 9 400 FC
// ─────────────────────────────────────────────────────────────────────────────
const OLI_FEE_RATE      = parseFloat(process.env.OLI_DEPOSIT_FEE_RATE      || '0.03'); // 3% OLI
const AGGREGATOR_FEE_RATE = parseFloat(process.env.UNIPESA_FEE_RATE         || '0.03'); // 3% Unipesa
const TOTAL_FEE_RATE    = OLI_FEE_RATE + AGGREGATOR_FEE_RATE;                          // 6% total

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS CRYPTO
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Calcule la signature HMAC-SHA512 d'un payload Unipesa.
 * La signature est calculée sur la concaténation triée des clés=valeurs.
 */
function _buildSignature(payload) {
    // Trier les clés, exclure 'signature' si présent
    const sortedKeys = Object.keys(payload)
        .filter(k => k !== 'signature')
        .sort();

    let str = '';
    for (const key of sortedKeys) {
        str += `${key}${payload[key]}`;
    }

    return crypto
        .createHmac('sha512', UNIPESA_SECRET)
        .update(str)
        .digest('hex')
        .toLowerCase();
}

/**
 * Génère un ID d'ordre unique pour OLI.
 * Format : DEP-{userId}-{timestamp}
 */
function _generateOliOrderId(userId, type = 'DEP') {
    return `${type}-${userId}-${Date.now()}`;
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

const unipesaService = {

    /**
     * Initie un paiement C2B (Mobile Money → OLI Wallet).
     * Envoie un push USSD/notification sur le téléphone de l'utilisateur.
     *
     * @param {number} userId         - ID de l'utilisateur OLI
     * @param {string} phone          - Numéro de téléphone Mobile Money (ex: +243XXXXXXXXX)
     * @param {number} amountFC       - Montant en Francs Congolais (FC)
     * @param {number} exchangeRate   - Taux de change FC/USD (requis par Unipesa si en USD)
     * @returns {Promise<{oliOrderId, unipesaOrderId, status, amountFC, feeFC, netAmountFC}>}
     */
    async initiateDeposit(userId, phone, amountFC, exchangeRate = 1) {
        const uid = parseInt(userId);
        const oliOrderId = _generateOliOrderId(uid, 'DEP');

        // ── Calcul des frais ──────────────────────────────────────────────────
        // L'utilisateur saisit le montant BRUT qu'il souhaite envoyer depuis son Mobile Money.
        // Les frais (6%) sont déduits pour obtenir le montant NET crédité sur le wallet OLI.
        const aggregatorFeeFC = Math.round(amountFC * AGGREGATOR_FEE_RATE); // 3% Unipesa
        const oliFeeFC        = Math.round(amountFC * OLI_FEE_RATE);        // 3% OLI
        const totalFeeFC      = aggregatorFeeFC + oliFeeFC;                  // 6% total
        const netFC           = amountFC - totalFeeFC;                       // Montant crédité

        // Enregistrer l'opération en statut "pending" AVANT l'appel API
        // → garantit la traçabilité même si l'API tombe
        await pool.query(`
            INSERT INTO unipesa_operations
                (oli_order_id, user_id, phone, amount_fc, provider, operation_type, status, expires_at)
            VALUES ($1, $2, $3, $4, $5, 'deposit', 'pending', NOW() + INTERVAL '10 minutes')
        `, [oliOrderId, uid, phone, amountFC, _detectProvider(phone)]);

        console.log(`💱 Frais: ${amountFC} FC brut → ${totalFeeFC} FC frais (${aggregatorFeeFC} FC Unipesa + ${oliFeeFC} FC OLI) → ${netFC} FC net`);

        try {
            // Construire le payload Unipesa C2B
            const payload = {
                merchant_id: UNIPESA_MERCHANT,
                order_id:    oliOrderId,
                amount:      amountFC.toString(),
                currency:    'CDF', // Franc Congolais
                phone:       phone.replace(/\D/g, ''), // digits only
                description: `Recharge OLI Wallet — ${amountFC} FC`,
            };
            payload.signature = _buildSignature(payload);

            console.log(`📲 Unipesa C2B initié: ${oliOrderId} — ${amountFC} FC → ${phone}`);

            const response = await axios.post(
                `${UNIPESA_API_URL}/${UNIPESA_PUBLIC_ID}/c2b`,
                payload,
                {
                    headers: { 
                        'Content-Type': 'application/json',
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                    },
                    timeout: 15000,
                }
            );

            // Vérifier les erreurs renvoyées dans le corps JSON (même si HTTP 200)
            if (response.data && response.data.status === 0 && response.data.result && response.data.result.message) {
                throw new Error(`API Error: ${response.data.result.message}`);
            }

            const unipesaOrderId = response.data?.order_id || oliOrderId;

            // Mettre à jour avec l'ID Unipesa
            await pool.query(
                'UPDATE unipesa_operations SET unipesa_order_id = $1 WHERE oli_order_id = $2',
                [unipesaOrderId, oliOrderId]
            );

            return {
                oliOrderId,
                unipesaOrderId,
                status:           'pending',
                amountFC,                           // Montant brut envoyé (FC)
                aggregatorFeeFC,                    // 3% frais Unipesa (FC)
                oliFeeFC,                           // 3% commission OLI (FC)
                totalFeeFC,                         // 6% total frais (FC)
                netAmountFC: netFC,                 // Montant crédité sur le wallet (FC)
                phone,
                provider:         _detectProvider(phone),
            };

        } catch (err) {
            // Marquer l'opération comme échouée
            const errorMsg = err.response?.data
                ? JSON.stringify(err.response.data)
                : err.message;

            await pool.query(
                'UPDATE unipesa_operations SET status = $1, error_message = $2 WHERE oli_order_id = $3',
                ['failed', errorMsg, oliOrderId]
            );

            console.error(`❌ Unipesa C2B échoué: ${oliOrderId}`, errorMsg);
            throw new Error(`Impossible d'initier le paiement Mobile Money: ${errorMsg}`);
        }
    },

    /**
     * Vérifie le statut d'une opération Unipesa.
     * Appelé pour le polling depuis l'application Flutter.
     *
     * @param {string} oliOrderId
     * @returns {Promise<{status, amountFC, confirmedAt, provider}>}
     */
    async checkOperationStatus(oliOrderId) {
        // D'abord vérifier en base (état local mis à jour par le webhook)
        const localRes = await pool.query(
            'SELECT * FROM unipesa_operations WHERE oli_order_id = $1',
            [oliOrderId]
        );

        if (!localRes.rows.length) {
            throw new Error(`Opération introuvable: ${oliOrderId}`);
        }

        const op = localRes.rows[0];

        // Si déjà finalisé localement (webhook reçu), pas besoin d'appeler l'API
        if (['success', 'failed', 'cancelled', 'timeout'].includes(op.status)) {
            return {
                status:      op.status,
                amountFC:    parseFloat(op.amount_fc),
                confirmedAt: op.confirmed_at,
                provider:    op.provider,
            };
        }

        // Si en pending, vérifier si expiré
        if (op.expires_at && new Date(op.expires_at) < new Date()) {
            await pool.query(
                'UPDATE unipesa_operations SET status = $1 WHERE oli_order_id = $2',
                ['timeout', oliOrderId]
            );
            return { status: 'timeout', amountFC: parseFloat(op.amount_fc) };
        }

        // Interroger l'API Unipesa pour avoir le statut en temps réel
        try {
            const payload = {
                merchant_id: UNIPESA_MERCHANT,
                order_id:    oliOrderId,
            };
            payload.signature = _buildSignature(payload);

            const response = await axios.post(
                `${UNIPESA_API_URL}/${UNIPESA_PUBLIC_ID}/status`,
                payload,
                { 
                    headers: { 
                        'Content-Type': 'application/json',
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                    }, 
                    timeout: 8000 
                }
            );

            const apiStatus = response.data?.status;
            // status Unipesa: 1 = succès, 0 = pending, -1 = échoué
            const mappedStatus = apiStatus === 1 ? 'success'
                : apiStatus === -1 ? 'failed'
                : 'pending';

            return {
                status:   mappedStatus,
                amountFC: parseFloat(op.amount_fc),
                provider: op.provider,
                raw:      response.data,
            };

        } catch (err) {
            // En cas d'erreur API, retourner le statut local
            console.warn(`⚠️ Unipesa status check échoué pour ${oliOrderId}:`, err.message);
            return { status: op.status, amountFC: parseFloat(op.amount_fc) };
        }
    },

    /**
     * Traite le webhook de confirmation reçu depuis Unipesa.
     * Appelé uniquement par la route webhook APRÈS vérification de signature.
     *
     * @param {Object} payload  - Corps brut du webhook Unipesa
     * @returns {Promise<{success, userId, amountFC, oliOrderId}>}
     */
    async processWebhook(payload) {
        const { order_id, status, amount } = payload;

        // Récupérer l'opération locale
        const opRes = await pool.query(
            'SELECT * FROM unipesa_operations WHERE oli_order_id = $1 OR unipesa_order_id = $1',
            [order_id]
        );

        if (!opRes.rows.length) {
            console.warn(`⚠️ Webhook Unipesa: opération introuvable pour order_id ${order_id}`);
            return { success: false, reason: 'operation_not_found' };
        }

        const op = opRes.rows[0];

        // Éviter le double traitement (idempotence)
        if (op.status === 'success') {
            console.log(`ℹ️ Webhook déjà traité pour ${op.oli_order_id}`);
            return { success: true, alreadyProcessed: true };
        }

        // status Unipesa : 1 = succès
        if (parseInt(status) !== 1) {
            await pool.query(
                'UPDATE unipesa_operations SET status = $1, webhook_payload = $2 WHERE id = $3',
                ['failed', JSON.stringify(payload), op.id]
            );
            console.log(`❌ Webhook Unipesa: paiement échoué pour ${op.oli_order_id}`);
            return { success: false, reason: 'payment_failed' };
        }

        // ✅ Paiement confirmé — créditer le wallet via OLI Bank
        const oliBank = require('./oli_bank.service');

        try {
            // Calcul du montant net à créditer (montant brut - 6% de frais)
            const grossAmount = parseFloat(op.amount_fc);
            const totalFee    = Math.round(grossAmount * TOTAL_FEE_RATE);
            const netAmount   = grossAmount - totalFee;

            console.log(`💱 Crédit wallet: ${grossAmount} FC brut → ${netAmount} FC net (frais ${totalFee} FC)`);

            await oliBank.processDeposit(op.user_id, netAmount, {
                phone:       op.phone,
                provider:    op.provider,
                orderId:     op.oli_order_id,
                description: `Recharge Mobile Money ${op.provider} — ${grossAmount} FC (frais 6% déduits)`,
                metadata:    { grossAmountFC: grossAmount, totalFeeFC: totalFee, netAmountFC: netAmount },
            });

            // Marquer l'opération comme réussie
            await pool.query(`
                UPDATE unipesa_operations
                SET status = 'success', confirmed_at = NOW(), webhook_payload = $1
                WHERE id = $2
            `, [JSON.stringify(payload), op.id]);

            console.log(`✅ Webhook traité: +${op.amount_fc} FC crédité au user #${op.user_id}`);

            return {
                success:     true,
                userId:      op.user_id,
                amountFC:    parseFloat(op.amount_fc),
                oliOrderId:  op.oli_order_id,
            };

        } catch (err) {
            console.error(`❌ Erreur crédit wallet après webhook ${op.oli_order_id}:`, err.message);
            await pool.query(
                'UPDATE unipesa_operations SET error_message = $1 WHERE id = $2',
                [err.message, op.id]
            );
            throw err;
        }
    },

    /**
     * Vérifie la signature d'un webhook entrant.
     * Rejette tout webhook dont la signature ne correspond pas.
     *
     * @param {Object} body  - Corps brut du webhook
     * @returns {boolean}
     */
    verifyWebhookSignature(body) {
        const receivedSignature = body.signature;
        if (!receivedSignature) return false;

        const expectedSignature = _buildSignature(body);
        return receivedSignature.toLowerCase() === expectedSignature.toLowerCase();
    },
};

/**
 * Détecte l'opérateur Mobile Money à partir du numéro de téléphone.
 * Basé sur les préfixes téléphoniques en RDC.
 */
function _detectProvider(phone) {
    const digits = phone.replace(/\D/g, '');
    const local  = digits.startsWith('243') ? digits.slice(3) : digits;

    if (/^(08[1-4]|08[5-9])/.test(local)) return 'Vodacom';
    if (/^(09[0-7])/.test(local))          return 'Airtel';
    if (/^(09[8-9]|08[0])/.test(local))    return 'Orange';
    if (/^(07[2-7])/.test(local))          return 'Africell';
    return 'Mobile Money';
}

module.exports = unipesaService;
