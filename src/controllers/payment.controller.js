/**
 * Contrôleur de Paiement (Simulé)
 */
const walletService = require('../services/wallet.service');
const orderService = require('../services/order.service');
const stripeService = require('../services/stripe.service');

/**
 * Créer une intention de paiement
 * POST /api/payment/create-payment-intent
 */
exports.createPaymentIntent = async (req, res) => {
    try {
        const { amount, currency, metadata } = req.body;

        if (!amount || amount <= 0) {
            return res.status(400).json({
                error: {
                    message: "Le montant est requis et doit être positif.",
                    type: "invalid_request_error"
                }
            });
        }

        const paymentIntent = await stripeService.createPaymentIntent(amount, currency || 'usd', metadata);

        res.json(paymentIntent);

    } catch (error) {
        console.error("Erreur createPaymentIntent:", error);
        res.status(500).json({
            error: {
                message: "Erreur lors de la création du paiement.",
                type: "api_error"
            }
        });
    }
};

/**
 * Webhook Stripe (Simulé)
 * POST /api/payment/webhook
 */
exports.handleWebhook = async (req, res) => {
    // Dans une vraie implémentation, on vérifie la signature ici
    const event = req.body;

    console.log(`🔔 Webhook reçu: ${event.type}`);

    // Simulation de traitement
    switch (event.type) {
        case 'payment_intent.succeeded':
            const paymentIntent = event.data.object;
            console.log(`💰 Paiement réussi pour ${paymentIntent.amount} ${paymentIntent.currency}`);

            // Récupérer l'ID de la commande depuis les métadonnées
            const orderId = paymentIntent.metadata ? paymentIntent.metadata.orderId : null;

            if (orderId) {
                console.log(`📦 Mise à jour de la commande #${orderId} -> PAID`);
                try {
                    // Utiliser le service de commande pour valider le paiement
                    await orderService.simulatePayment(orderId, 'stripe');
                    console.log(`✅ Commande #${orderId} mise à jour avec succès`);
                } catch (err) {
                    console.error(`❌ Erreur mise à jour commande #${orderId}:`, err.message);
                }
            } else {
                console.warn("⚠️ Pas d'orderId dans les métadonnées du paiement");
            }
            break;
        case 'payment_intent.payment_failed':
            console.log('❌ Paiement échoué');
            break;
        default:
        // console.log(`Unhandled event type ${event.type}`);
    }

    res.json({ received: true });
};
