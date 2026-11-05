/**
 * Vérification de la signature des webhooks Stripe (en-tête Stripe-Signature).
 *
 * Schéma Stripe : signature = HMAC-SHA256(secret, "<t>.<corps brut>") en hexadécimal,
 * transmise dans "t=<timestamp>,v1=<signature>". Le corps DOIT être le corps brut
 * reçu (req.rawBody, capturé par express.json({ verify }) dans server.js).
 *
 * Sans STRIPE_WEBHOOK_SECRET configuré, tous les webhooks sont refusés (fail closed).
 */
const crypto = require('crypto');

const TOLERANCE_SECONDS = 300; // 5 minutes, recommandation Stripe

function verifyStripeWebhook(req, res, next) {
    const secret = process.env.STRIPE_WEBHOOK_SECRET;
    if (!secret) {
        console.error('[STRIPE] STRIPE_WEBHOOK_SECRET absent : webhook refusé.');
        return res.status(503).json({ error: 'Webhook Stripe non configuré' });
    }

    const header = req.headers['stripe-signature'];
    const rawBody = req.rawBody;
    if (!header || !rawBody) {
        console.warn('[STRIPE] Webhook sans signature ou sans corps brut : refusé.');
        return res.status(400).json({ error: 'Signature manquante' });
    }

    let timestamp = null;
    const signatures = [];
    for (const part of String(header).split(',')) {
        const idx = part.indexOf('=');
        if (idx === -1) continue;
        const key = part.slice(0, idx).trim();
        const value = part.slice(idx + 1).trim();
        if (key === 't') timestamp = value;
        else if (key === 'v1') signatures.push(value);
    }
    if (!timestamp || signatures.length === 0) {
        return res.status(400).json({ error: 'Signature mal formée' });
    }

    const age = Math.abs(Math.floor(Date.now() / 1000) - Number(timestamp));
    if (!Number.isFinite(age) || age > TOLERANCE_SECONDS) {
        console.warn('[STRIPE] Webhook hors tolérance temporelle : refusé.');
        return res.status(400).json({ error: 'Timestamp hors tolérance' });
    }

    const expected = crypto
        .createHmac('sha256', secret)
        .update(`${timestamp}.`)
        .update(rawBody)
        .digest('hex');
    const expectedBuf = Buffer.from(expected);

    const valid = signatures.some((sig) => {
        const sigBuf = Buffer.from(sig);
        return sigBuf.length === expectedBuf.length && crypto.timingSafeEqual(sigBuf, expectedBuf);
    });

    if (!valid) {
        console.warn('[STRIPE] Signature de webhook invalide : refusé.');
        return res.status(400).json({ error: 'Signature invalide' });
    }

    next();
}

module.exports = { verifyStripeWebhook };
