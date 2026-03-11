const axios = require('axios');
const crypto = require('crypto');
const onafriqConfig = require('../config/onafriq.config');

class OnafriqService {
    constructor() {
        this.apiUrl = onafriqConfig.ONAFRIQ_API_URL;
        this.clientId = onafriqConfig.ONAFRIQ_CLIENT_ID;
        this.clientSecret = onafriqConfig.ONAFRIQ_CLIENT_SECRET;
        
        // Cache pour le token OAuth d'Onafriq (pour éviter de recommencer à chaque requête)
        this.accessToken = null;
        this.tokenExpiry = null;
    }

    /**
     * Obtenir le token d'authentification OAuth (Bearer)
     */
    async _getAccessToken() {
        // Retourne le token s'il est encore valide (avec marge de 5 min)
        if (this.accessToken && this.tokenExpiry && Date.now() < (this.tokenExpiry - 300000)) {
            return this.accessToken;
        }

        try {
            const response = await axios.post(`${this.apiUrl}/o/token/`, new URLSearchParams({
                grant_type: 'client_credentials',
                client_id: this.clientId,
                client_secret: this.clientSecret
            }), {
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded'
                }
            });

            this.accessToken = response.data.access_token;
            // expires_in est en secondes
            this.tokenExpiry = Date.now() + (response.data.expires_in * 1000); 

            return this.accessToken;

        } catch (error) {
            console.error('Erreur API Onafriq (_getAccessToken):', error.response?.data || error.message);
            throw new Error('Impossible d\'authentifier le service Onafriq');
        }
    }

    /**
     * Header builder pour Axios
     */
    async _getHeaders() {
        const token = await this._getAccessToken();
        return {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        };
    }

    /**
     * 1. Collections - Mobile Money & Card
     * @param {Object} data - Détails du dépôt (Recharge de portefeuille OLI)
     */
    async collectPayment(data) {
        
        // ==========================================================
        // SIMULATION MODE (Si pas de clés API Onafriq configurées)
        // ==========================================================
        if (!this.clientId || !this.clientSecret) {
            console.warn(`⚠️ [SIMULATION ONAFRIQ] CollectPayment initié pour ${data.amount} ${data.currency}`);
            
            // Simule l'appel asynchrone du Webhook dans 3 secondes
            setTimeout(async () => {
                try {
                    console.log(`⏱️ [SIMULATION ONAFRIQ] Envoi du webhook (Succès) pour ${data.reference}...`);
                    await axios.post(`http://127.0.0.1:${process.env.PORT || 3000}/webhooks/onafriq/collections`, {
                        status: 'SUCCESS',
                        amount: data.amount,
                        currency: data.currency,
                        reference: data.reference,
                        metadata: { oliTransactionId: data.reference }
                    });
                } catch (e) {
                    console.error("❌ Echec Simulation Webhook Collection:", e.message);
                }
            }, 3000);

            return {
                success: true,
                status: 'pending',
                transaction_id: `SIM_COLL_${Date.now()}`,
                message: "[Mode Test] Demande initiée. Le portefeuille sera crédité dans quelques secondes."
            };
        }
        // ==========================================================

        /*
        data = {
           amount: Number,
           currency: 'USD' | 'CDF',
           paymentType: 'MOBILE_MONEY' | 'CARD',
           phoneNumber: String (ex: '+243999999999'),
           reference: String, // ex: `DEP_${userId}_${Date.now()}`
           callbackUrl: String
        }
        */
        try {
            const headers = await this._getHeaders();

            // Structure du payload de demande de Collection
            // Référez-vous à la documentation exacte d'Onafriq pour les champs requis précis
            const payload = {
                amount: data.amount,
                currency: data.currency,
                request_currency: data.currency,
                phonenumber: data.phoneNumber,
                reference: data.reference,
                metadata: {
                    oliTransactionId: data.reference,
                    paymentType: data.paymentType
                },
                // callback_url n'est pas toujours dans le payload de requete
                // il peut être configuré globalement sur le portail Onafriq
                // Mais s'il est supporté dynamiquement :
                // callback_url: data.callbackUrl 
            };

            const response = await axios.post(`${this.apiUrl}/collections/`, payload, { headers });

            // La transaction est initiée (en attente du PIN ou 3D-Secure côté client)
            return {
                success: true,
                status: 'pending', // par défaut pendante jusqu'au webhook
                transaction_id: response.data.id || response.data.remote_transaction_id,
                message: "Demande de paiement (Collection) initiée. En attente de validation utilisateur.",
                rawAuthData: response.data // (peut contenir des infos de redirection pour la carte)
            };

        } catch (error) {
            console.error('Erreur API Onafriq (collectPayment):', error.response?.data || error.message);
            return {
                success: false,
                status: 'failed',
                message: error.response?.data?.message || error.message || "Échec de l'initiation de la Collection."
            };
        }
    }

    /**
     * 2. Décaissements - Retraits (Disbursements)
     * @param {Object} data - Détails du retrait (Depuis portefeuille OLI vers MM/Banque)
     */
    async disburse(data) {
        
        // ==========================================================
        // SIMULATION MODE (Si pas de clés API Onafriq configurées)
        // ==========================================================
        if (!this.clientId || !this.clientSecret) {
            console.warn(`⚠️ [SIMULATION ONAFRIQ] Disbursement (Retrait) initié pour ${data.amount} ${data.currency}`);
            
            // Simule l'appel asynchrone du Webhook dans 3 secondes
            setTimeout(async () => {
                try {
                    console.log(`⏱️ [SIMULATION ONAFRIQ] Envoi du webhook (Succès) pour ${data.reference}...`);
                    await axios.post(`http://127.0.0.1:${process.env.PORT || 3000}/webhooks/onafriq/disbursements`, {
                        status: 'SUCCESS',
                        amount: data.amount,
                        currency: data.currency,
                        reference: data.reference,
                        metadata: { oliTransactionId: data.reference }
                    });
                } catch (e) {
                    console.error("❌ Echec Simulation Webhook Disbursement:", e.message);
                }
            }, 3000);

            return {
                success: true,
                status: 'pending',
                transaction_id: `SIM_DISB_${Date.now()}`,
                message: "[Mode Test] Retrait demandé. Le statut sera mis à jour dans quelques secondes."
            };
        }
        // ==========================================================

        /*
         data = {
            amount: Number,
            currency: 'USD' | 'CDF',
            phoneNumber: String,
            reference: String, // ex: `WD_${userId}_${Date.now()}`
         }
        */
        try {
             const headers = await this._getHeaders();

             // Payload selon l'API Transfert de fonds en masse (Bulk / Single Disbursement)
             const payload = {
                amount: data.amount,
                currency: data.currency,
                phonenumber: data.phoneNumber,
                reference: data.reference,
                metadata: {
                    oliTransactionId: data.reference
                }
             };

             const response = await axios.post(`${this.apiUrl}/disbursements/`, payload, { headers });
             
             return {
                 success: true,
                 status: 'pending', // L'envoi prend généralement quelques secondes à minutes
                 transaction_id: response.data.id || response.data.remote_transaction_id,
                 message: "Demande de décaissement envoyée. En cours de traitement."
             };

        } catch (error) {
            console.error('Erreur API Onafriq (disburse):', error.response?.data || error.message);
            return {
                success: false,
                status: 'failed',
                message: error.response?.data?.message || "Échec du décaissement."
            };
        }
    }

    /**
     * Vérificateur de signature Webhook (Sécurité)
     * @param {String} signatureHeader
     * @param {Object|String} rawBody
     */
    verifyWebhookSignature(signatureHeader, payload) {
        // En mode Sandbox où vous n'avez pas encore les détails de la signature: retournez True
        if (onafriqConfig.IS_SANDBOX && !signatureHeader) return true;
        
        // Implémentation typique HMAC SHA256 (à ajuster selon la doc exacte Onfriq)
        try {
            const hmac = crypto.createHmac('sha256', this.clientSecret);
            const bodyString = typeof payload === 'string' ? payload : JSON.stringify(payload);
            const computedSignature = hmac.update(bodyString).digest('hex'); // ou base64 selon Onafriq
            
            return computedSignature === signatureHeader;
        } catch(e) {
            console.error("Erreur de vérification signature", e);
            return false;
        }
    }
}

module.exports = new OnafriqService();
