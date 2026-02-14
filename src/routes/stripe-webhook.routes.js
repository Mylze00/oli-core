/**
 * Stripe Webhook
 * POST /api/payment/webhook
 * 
 * Handles payment confirmation events.
 * Currently in simulation mode: called directly by StripePaymentPage
 * after a successful test card payment.
 * 
 * In production, this should verify the Stripe signature
 * using stripe.webhooks.constructEvent().
 * 
 * @see https://stripe.com/docs/webhooks
 */
const express = require('express');
const router = express.Router();

router.post('/webhook', express.json(), async (req, res) => {
    try {
        // TODO (Production): Verify Stripe signature
        // const sig = req.headers['stripe-signature'];
        // const event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);

        const event = req.body;
        console.log(`📩 Stripe webhook received: ${event?.type || 'unknown'}`);

        switch (event.type) {
            case 'payment_intent.succeeded': {
                // Extract orderId from metadata (sent by StripePaymentPage)
                const paymentIntent = event.data?.object;
                const orderId = paymentIntent?.metadata?.orderId
                    || paymentIntent?.metadata?.order_id;

                if (orderId) {
                    const orderService = require('../services/order.service');
                    const io = req.app.get('io');

                    await orderService.simulatePayment(parseInt(orderId), 'card', io);
                    console.log(`✅ Commande #${orderId}: paiement carte confirmé (pending → paid)`);
                } else {
                    console.warn('⚠️ payment_intent.succeeded reçu sans orderId dans metadata');
                }
                break;
            }
            case 'payment_intent.payment_failed': {
                const failedIntent = event.data?.object;
                const failedOrderId = failedIntent?.metadata?.orderId
                    || failedIntent?.metadata?.order_id;
                console.log(`❌ Payment failed for order #${failedOrderId || 'unknown'}:`, failedIntent?.id);
                break;
            }
            default:
                console.log(`ℹ️ Unhandled webhook event type: ${event.type}`);
        }

        res.json({ received: true });
    } catch (err) {
        console.error('⚠️ Webhook error:', err.message);
        res.status(400).json({ error: `Webhook Error: ${err.message}` });
    }
});

module.exports = router;
