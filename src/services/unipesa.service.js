const axios = require('axios');
const crypto = require('crypto');
const config = require('../config/unipesa.config');

/**
 * Service Unipesa
 * Gère les paiements Mobile Money & Carte via la passerelle Unipesa pour la RDC.
 *
 * --- Architecture ---
 * C2B (Client → OLI Wallet)  : deposit via payment_c2b
 * B2C (OLI Wallet → Client)  : withdrawal via payment_b2c
 *
 * --- Authentification ---
 * Toutes les requêtes sont signées avec HMAC-SHA512 à partir de la clé secrète
 * (pas de OAuth). La signature est calculée sur tous les paramètres dans l'ordre.
 */
class UnipesaService {

    /**
     * Calcule la signature HMAC-SHA512 de la requête.
     * Conformément à la documentation Unipesa.
     */
    _calculateSignature(data) {
        let stringForSignature = '';
        for (const [key, value] of Object.entries(data)) {
            if (key !== 'signature' && value !== undefined && value !== null) {
                // Support des objets imbriqués (récursion de niveau 1)
                if (typeof value === 'object') {
                    for (const [subKey, subVal] of Object.entries(value)) {
                        stringForSignature += `${key}.${subKey}${subVal}`;
                    }
                } else {
                    stringForSignature += `${key}${value}`;
                }
            }
        }
        return crypto.createHmac('sha512', config.SECRET_KEY)
                     .update(stringForSignature)
                     .digest('hex')
                     .toLowerCase();
    }

    /**
     * Résout le provider_id Unipesa à partir du nom de l'opérateur OLI.
     */
    _resolveProviderId(provider) {
        const map = {
            'vodacom':  config.PROVIDERS.VODACOM,
            'mpesa':    config.PROVIDERS.VODACOM,
            'orange':   config.PROVIDERS.ORANGE,
            'orangemoney': config.PROVIDERS.ORANGE,
            'airtel':   config.PROVIDERS.AIRTEL,
            'africell': config.PROVIDERS.AFRICELL,
            'equity':   config.PROVIDERS.EQUITY,
            'ecobank':  config.PROVIDERS.ECOBANK,
            'visa':     config.PROVIDERS.VISA,
            'card':     config.PROVIDERS.EQUITY, // par défaut: Equity pour les cartes
        };
        if (!provider) return config.PROVIDERS.ORANGE;
        return map[provider.toLowerCase()] ?? config.PROVIDERS.SIMULATOR;
    }

    // ─────────────────────────────────────────────────────────────
    // 1. Dépôt — Client vers OLI Wallet (C2B)
    // ─────────────────────────────────────────────────────────────

    /**
     * Initie une demande de paiement Mobile Money du client vers le Wallet OLI.
     * @param {Object} data
     * data.amount        — montant en USD (ex: "10.00")
     * data.currency      — devise ("USD" | "CDF")
     * data.phoneNumber   — numéro international du client (ex: "243xxxxxxxxx")
     * data.provider      — nom de l'opérateur (ex: "orange", "vodacom", "airtel"...)
     * data.reference     — ID de la transaction OLI (ex: "DEP_1_1678...")
     * data.callbackUrl   — URL de callback
     */
    async depositC2B(data) {

        // ══════════════════════════════════════════════
        // MODE SIMULATEUR (si pas de clés configurées)
        // ══════════════════════════════════════════════
        if (!config.IS_CONFIGURED) {
            console.warn(`⚠️ [SIMULATION UNIPESA] C2B initié pour ${data.amount} ${data.currency}`);

            setTimeout(async () => {
                try {
                    console.log(`⏱️ [SIMULATION UNIPESA] Auto-webhook C2B pour ${data.reference}`);
                    await axios.post(`http://127.0.0.1:${process.env.PORT || 3000}/webhooks/unipesa/deposit`, {
                        merchant_id:    config.MERCHANT_ID || 'SIMULATOR',
                        operation_type: 17,
                        customer_id:    data.phoneNumber,
                        amount:         data.amount,
                        currency:       data.currency || 'USD',
                        order_id:       data.reference,
                        status:         2, // 2 = SUCCESS
                        provider_id:    this._resolveProviderId(data.provider),
                        result:         { code: 0, message: 'OK' },
                        transaction_id: `SIM_TXN_${Date.now()}`,
                        signature:      'SIMULATED'
                    });
                } catch (e) {
                    console.error('❌ Echec Simulation Webhook C2B:', e.message);
                }
            }, 3000);

            return {
                success: true,
                status: 'pending',
                transaction_id: `SIM_C2B_${Date.now()}`,
                message: '[Mode Test] Demande initiée. Le portefeuille sera crédité dans ~3s.'
            };
        }
        // ══════════════════════════════════════════════

        try {
            const providerId = this._resolveProviderId(data.provider);
            const payload = {
                merchant_id:  config.MERCHANT_ID,
                customer_id:  data.phoneNumber,
                order_id:     data.reference,
                amount:       parseFloat(data.amount).toFixed(2),
                currency:     data.currency || 'USD',
                country:      'CD',
                callback_url: data.callbackUrl || `${process.env.APP_URL}/webhooks/unipesa/deposit`,
                provider_id:  providerId,
            };
            payload.signature = this._calculateSignature(payload);

            const response = await axios.post(
                `${config.API_URL}/${config.PUBLIC_ID}/payment_c2b`,
                payload,
                { headers: { 'Content-Type': 'application/json' } }
            );

            return {
                success: true,
                status: 'pending',
                transaction_id: response.data.transaction_id || data.reference,
                unipesa_order_id: response.data.order_id,
                message: 'Demande de dépôt (C2B) initiée. En attente de confirmation PIN Mobile Money.'
            };

        } catch (error) {
            console.error('Erreur Unipesa (depositC2B):', error.response?.data || error.message);
            return {
                success: false,
                status: 'failed',
                message: error.response?.data?.result?.message || error.message || 'Échec du dépôt.'
            };
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 2. Retrait — OLI Wallet vers Mobile Money Client (B2C)
    // ─────────────────────────────────────────────────────────────

    /**
     * Initie un paiement depuis le Wallet OLI vers le Mobile Money du client.
     * @param {Object} data
     * data.amount        — montant en USD
     * data.currency      — devise ("USD" | "CDF")
     * data.phoneNumber   — numéro international du client
     * data.provider      — nom de l'opérateur Mobile Money
     * data.reference     — ID de la transaction OLI
     * data.callbackUrl   — URL de callback
     */
    async withdrawB2C(data) {

        // ══════════════════════════════════════════════
        // MODE SIMULATEUR
        // ══════════════════════════════════════════════
        if (!config.IS_CONFIGURED) {
            console.warn(`⚠️ [SIMULATION UNIPESA] B2C initié pour ${data.amount} ${data.currency}`);

            setTimeout(async () => {
                try {
                    console.log(`⏱️ [SIMULATION UNIPESA] Auto-webhook B2C pour ${data.reference}`);
                    await axios.post(`http://127.0.0.1:${process.env.PORT || 3000}/webhooks/unipesa/withdrawal`, {
                        merchant_id:    config.MERCHANT_ID || 'SIMULATOR',
                        operation_type: 16,
                        customer_id:    data.phoneNumber,
                        amount:         data.amount,
                        currency:       data.currency || 'USD',
                        order_id:       data.reference,
                        status:         2, // 2 = SUCCESS
                        provider_id:    this._resolveProviderId(data.provider),
                        result:         { code: 0, message: 'OK' },
                        transaction_id: `SIM_TXN_${Date.now()}`,
                        signature:      'SIMULATED'
                    });
                } catch (e) {
                    console.error('❌ Echec Simulation Webhook B2C:', e.message);
                }
            }, 3000);

            return {
                success: true,
                status: 'pending',
                transaction_id: `SIM_B2C_${Date.now()}`,
                message: '[Mode Test] Retrait demandé. Le client recevra les fonds dans ~3s.'
            };
        }
        // ══════════════════════════════════════════════

        try {
            const providerId = this._resolveProviderId(data.provider);
            const payload = {
                merchant_id:  config.MERCHANT_ID,
                customer_id:  data.phoneNumber,
                order_id:     data.reference,
                amount:       parseFloat(data.amount).toFixed(2),
                currency:     data.currency || 'USD',
                country:      'CD',
                callback_url: data.callbackUrl || `${process.env.APP_URL}/webhooks/unipesa/withdrawal`,
                provider_id:  providerId,
            };
            payload.signature = this._calculateSignature(payload);

            const response = await axios.post(
                `${config.API_URL}/${config.PUBLIC_ID}/payment_b2c`,
                payload,
                { headers: { 'Content-Type': 'application/json' } }
            );

            return {
                success: true,
                status: 'pending',
                transaction_id: response.data.transaction_id || data.reference,
                message: 'Décaissement (B2C) envoyé. Le client recevra les fonds bientôt.'
            };

        } catch (error) {
            console.error('Erreur Unipesa (withdrawB2C):', error.response?.data || error.message);
            return {
                success: false,
                status: 'failed',
                message: error.response?.data?.result?.message || error.message || 'Échec du retrait.'
            };
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 3. Vérification de signature des Webhooks entrants
    // ─────────────────────────────────────────────────────────────

    /**
     * Vérifie l'authenticité d'un callback entrant d'Unipesa.
     * @param {Object} payload — Le corps brut du webhook (JSON parsé)
     * @returns {boolean}
     */
    verifyWebhookSignature(payload) {
        // En mode simulateur, on autorise tout
        if (!config.IS_CONFIGURED || !payload.signature || payload.signature === 'SIMULATED') {
            return true;
        }
        try {
            const receivedSignature = payload.signature;
            const dataToSign = { ...payload };
            delete dataToSign.signature;
            const computed = this._calculateSignature(dataToSign);
            return computed === receivedSignature.toLowerCase();
        } catch (e) {
            console.error('Erreur vérification signature Unipesa:', e.message);
            return false;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 4. Consultation de statut d'une transaction
    // ─────────────────────────────────────────────────────────────
    async getTransactionStatus(orderId) {
        if (!config.IS_CONFIGURED) return { status: 2, result: { code: 0, message: 'SIMULATED OK' } };
        
        try {
            const payload = {
                merchant_id: config.MERCHANT_ID,
                order_id:    orderId,
            };
            payload.signature = this._calculateSignature(payload);
            const response = await axios.post(
                `${config.API_URL}/${config.PUBLIC_ID}/status`,
                payload,
                { headers: { 'Content-Type': 'application/json' } }
            );
            return response.data;
        } catch (error) {
            console.error('Erreur Unipesa (getStatus):', error.response?.data || error.message);
            throw error;
        }
    }
}

module.exports = new UnipesaService();
