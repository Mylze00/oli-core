/**
 * Liens de partage des produits : GET /p/:id
 *
 * Chaque produit a un lien unique, https://oli-core.onrender.com/p/<id>.
 * La page renvoyée porte les balises Open Graph (photo, nom, prix) pour un aperçu
 * enrichi dans WhatsApp, Facebook, Telegram…, puis ouvre le produit dans l'app web.
 */
const express = require('express');
const router = express.Router();
const productRepository = require('../repositories/product.repository');
const productService = require('../services/product.service');
const exchangeRateService = require('../services/exchange-rate.service');

const APP_URL = process.env.WEB_APP_URL || 'https://oli-core.web.app';

/** Échappe un texte pour l'insérer dans du HTML. */
function escapeHtml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

/** Image d'aperçu : 1200 × 630 recadrée par Cloudinary quand c'est possible. */
function previewImage(url) {
    if (!url || !url.includes('res.cloudinary.com') || !url.includes('/upload/')) return url;
    const [before, after] = url.split('/upload/');
    if (/^(c_|w_|f_)/.test(after)) return url;
    return `${before}/upload/c_pad,b_white,w_1200,h_630,q_auto,f_jpg/${after}`;
}

function formatFc(amount) {
    return `${Math.round(amount).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ')} FC`;
}

router.get('/:id', async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const appLink = `${APP_URL}/product/${Number.isFinite(id) ? id : ''}`;
    try {
        if (!Number.isFinite(id)) return res.redirect(302, APP_URL);
        // Lecture directe : l'ouverture d'un lien ne compte pas comme une vue
        const product = await productRepository.findById(id);
        if (!product) return res.redirect(302, APP_URL);

        const images = productService._formatImages(product.images);
        const priceUsd = parseFloat(product.discount_price) > 0
            ? parseFloat(product.discount_price)
            : parseFloat(product.price) || 0;
        let priceLabel = `${priceUsd.toFixed(2)} $`;
        try {
            const rate = await exchangeRateService.getCurrentRate('USD', 'CDF');
            const value = typeof rate === 'object' ? parseFloat(rate.rate) : parseFloat(rate);
            if (value > 0) priceLabel = formatFc(priceUsd * value);
        } catch (_) { /* prix en dollars si le taux est indisponible */ }

        const seller = product.shop_name || product.seller_name || 'Oli';
        const title = escapeHtml(`${product.name} — ${priceLabel}`);
        const description = escapeHtml(
            `Vendu par ${seller} sur Oli. ${String(product.description || '').replace(/\s+/g, ' ').slice(0, 150)}`
        );
        const image = escapeHtml(previewImage(images[0] || ''));
        const link = escapeHtml(appLink);

        res.set('Cache-Control', 'public, max-age=300');
        res.type('html').send(`<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<meta name="description" content="${description}">
<meta property="og:type" content="product">
<meta property="og:site_name" content="Oli">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${description}">
${image ? `<meta property="og:image" content="${image}">\n<meta property="og:image:width" content="1200">\n<meta property="og:image:height" content="630">` : ''}
<meta property="og:url" content="${link}">
<meta name="twitter:card" content="summary_large_image">
<meta http-equiv="refresh" content="0;url=${link}">
<link rel="canonical" href="${link}">
</head>
<body style="font-family:sans-serif;text-align:center;padding:40px">
<p>Ouverture du produit sur Oli…</p>
<p><a href="${link}">Voir le produit</a></p>
<script>window.location.replace(${JSON.stringify(appLink)});</script>
</body>
</html>`);
    } catch (err) {
        console.error('Erreur GET /p/:id:', err.message);
        res.redirect(302, appLink);
    }
});

module.exports = router;
