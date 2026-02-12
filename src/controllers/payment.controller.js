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
    const event = req.body;

    console.log(`🔔 Webhook reçu: ${event.type}`);

    switch (event.type) {
        case 'payment_intent.succeeded':
            const paymentIntent = event.data.object;
            console.log(`💰 Paiement réussi pour ${paymentIntent.amount} ${paymentIntent.currency}`);

            const orderId = paymentIntent.metadata ? paymentIntent.metadata.orderId : null;

            if (orderId) {
                console.log(`📦 Mise à jour de la commande #${orderId} -> PAID`);
                try {
                    const io = req.app ? req.app.get('io') : null;
                    const result = await orderService.simulatePayment(orderId, 'stripe', io);
                    console.log(`✅ Commande #${orderId} mise à jour avec succès`);
                    return res.json({ received: true, success: true, orderId, result });
                } catch (err) {
                    console.error(`❌ Erreur mise à jour commande #${orderId}:`, err.message, err.stack);
                    return res.json({ received: true, success: false, orderId, error: err.message, stack: err.stack });
                }
            } else {
                console.warn("⚠️ Pas d'orderId dans les métadonnées du paiement");
                return res.json({ received: true, warning: 'No orderId in metadata', metadata: paymentIntent.metadata });
            }
        case 'payment_intent.payment_failed':
            console.log('❌ Paiement échoué');
            break;
        default:
            break;
    }

    res.json({ received: true });
};
