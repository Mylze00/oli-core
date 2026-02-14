/**
 * Stripe Webhook Stub
 * POST /api/payment/webhook
 * 
 * Placeholder for future Stripe webhook integration.
 * In production, this should:
 * 1. Verify the Stripe signature (stripe.webhooks.constructEvent)
 * 2. Handle 'payment_intent.succeeded' events
 * 3. Call orderService.simulatePayment() or equivalent to confirm the order
 * 
 * @see https://stripe.com/docs/webhooks
 */
const express = require('express');
const router = express.Router();

router.post('/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
    try {
        // TODO: Verify Stripe signature
        // const sig = req.headers['stripe-signature'];
        // const event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);

        const event = req.body;
        console.log(`📩 Stripe webhook received: ${event?.type || 'unknown'}`);

        // TODO: Handle specific events
        // switch (event.type) {
        //     case 'payment_intent.succeeded':
        //         const orderId = event.data.object.metadata?.order_id;
        //         if (orderId) {
        //             const orderService = require('../services/order.service');
        //             await orderService.simulatePayment(parseInt(orderId), 'card');
        //         }
        //         break;
        //     case 'payment_intent.payment_failed':
        //         console.log('❌ Payment failed:', event.data.object.id);
        //         break;
        // }

        res.json({ received: true });
    } catch (err) {
        console.error('⚠️ Webhook error:', err.message);
        res.status(400).json({ error: `Webhook Error: ${err.message}` });
    }
});

module.exports = router;
