/**
 * Service Stripe Simulé
 * Permet de simuler les appels à Stripe sans clé API
 */

class StripeService {
    constructor() {
        console.log("💳 Service Stripe Simulé Initialisé");
    }

    /**
     * Simule la création d'une PaymentIntent
     * @param {number} amount - Montant en centimes (ex: 2000 pour 20.00$)
     * @param {string} currency - Devise (ex: 'usd', 'eur')
     * @param {object} metadata - Métadonnées additionnelles
     */
    async createPaymentIntent(amount, currency = 'usd', metadata = {}) {
        // Simulation d'un délai réseau
        await new Promise(resolve => setTimeout(resolve, 500));

        const id = `pi_${Math.random().toString(36).substr(2, 24)}`;
        const client_secret = `${id}_secret_${Math.random().toString(36).substr(2, 20)}`;

        return {
            id: id,
            object: 'payment_intent',
            amount: amount,
            amount_capturable: 0,
            amount_details: { tip: {} },
            amount_received: 0,
            currency: currency,
            status: 'requires_payment_method',
            client_secret: client_secret,
            created: Math.floor(Date.now() / 1000),
            currency: currency,
            metadata: metadata,
            livemode: false,
            payment_method_options: {
                card: {
                    request_three_d_secure: 'automatic'
                }
            },
            payment_method_types: ['card']
        };
    }

    /**
     * Simule la confirmation (non utilisé directement par le client mobile, mais utile pour tests backend)
     */
    async confirmPayment(intentId) {
        await new Promise(resolve => setTimeout(resolve, 500));
        return {
            id: intentId,
            object: 'payment_intent',
            status: 'succeeded'
        };
    }

    /**
     * Helper pour générer un événement webhook simulé
     */
    generateWebhookEvent(type, data) {
        return {
            id: `evt_${Math.random().toString(36).substr(2, 24)}`,
            object: 'event',
            api_version: '2022-11-15',
            created: Math.floor(Date.now() / 1000),
            type: type,
            data: {
                object: data
            },
            livemode: false,
            pending_webhooks: 1,
            request: {
                id: `req_${Math.random().toString(36).substr(2, 14)}`,
                idempotency_key: null
            }
        };
    }
}

module.exports = new StripeService();
