/**
 * Configuration Unipesa
 * Passerelle de paiement pour la RDC (Vodacom, OrangeMoney, Airtel, Africell, Equity)
 *
 * Variables d'environnement requises dans .env :
 *   UNIPESA_API_URL     — URL de base de l'API (ex: https://api.unipesa.tech)
 *   UNIPESA_PUBLIC_ID   — ID public du commerçant (format: f54ec96649be...)
 *   UNIPESA_MERCHANT_ID — ID unique du commerçant (format: e0fecd91fcb2...)
 *   UNIPESA_SECRET_KEY  — Clé secrète pour la signature HMAC-SHA512
 */

module.exports = {
    API_URL:     process.env.UNIPESA_API_URL     || 'https://api.unipesa.tech',
    PUBLIC_ID:   process.env.UNIPESA_PUBLIC_ID   || null,
    MERCHANT_ID: process.env.UNIPESA_MERCHANT_ID || null,
    SECRET_KEY:  process.env.UNIPESA_SECRET_KEY  || null,

    // ID des fournisseurs de paiement disponibles pour la RDC
    PROVIDERS: {
        VODACOM:   9,
        ORANGE:    10,
        AIRTEL:    17,
        AFRICELL:  19,
        EQUITY:    20,   // carte bancaire
        ECOBANK:   23,   // carte bancaire
        VISA:      5002, // VISA DRC
        SIMULATOR: 14,   // Simulateur Unipesa (tests uniquement)
    },

    // Indicateur de mode test
    IS_CONFIGURED: !!(process.env.UNIPESA_MERCHANT_ID && process.env.UNIPESA_SECRET_KEY),
};
