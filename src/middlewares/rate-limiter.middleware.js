/**
 * Rate Limiters — Protection contre le brute-force et le flood
 *
 * Appliqués sur :
 *  - /auth/send-otp    → 5 tentatives / 15 min / IP
 *  - /auth/verify-otp  → 10 tentatives / 15 min / IP
 *  - /api/wallet/deposit + /withdraw → 10 opérations / 15 min / user
 *  - /api/wallet/transfer            → 20 transferts / 15 min / utilisateur
 *  - /api/wallet/resolve-recipient   → 40 recherches / 15 min / utilisateur
 */
const rateLimit = require('express-rate-limit');
const { ipKeyGenerator } = require('express-rate-limit');

/**
 * Limiter strict pour l'envoi d'OTP.
 * Protège contre le flood SMS et le brute-force de numéros.
 */
const otpSendLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5,                    // 5 envois max par fenêtre par IP
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        error: 'Trop de tentatives. Veuillez patienter 15 minutes avant de réessayer.',
        code: 'RATE_LIMIT_OTP_SEND'
    },
    skip: (req) => process.env.NODE_ENV === 'test', // Ne pas limiter en test
});

/**
 * Limiter pour la vérification OTP.
 * Protège contre le brute-force des codes à 6 chiffres (10^6 combos).
 */
const otpVerifyLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 10,                   // 10 tentatives max par fenêtre par IP
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        error: 'Trop de tentatives de connexion. Compte temporairement bloqué (15 min).',
        code: 'RATE_LIMIT_OTP_VERIFY'
    },
    skip: (req) => process.env.NODE_ENV === 'test',
});

/**
 * Limiter pour les opérations financières (dépôt / retrait).
 * Protège contre le spam de transactions.
 */
const walletOperationLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 10,                   // 10 opérations max par fenêtre par IP
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        error: 'Trop d\'opérations en peu de temps. Veuillez patienter 15 minutes.',
        code: 'RATE_LIMIT_WALLET'
    },
    skip: (req) => process.env.NODE_ENV === 'test',
});

// Clé par utilisateur connecté : plusieurs abonnés d'un même opérateur
// partagent souvent la même adresse IP en RDC.
const perUserKey = (req) =>
    (req.user && req.user.id ? `user:${req.user.id}` : ipKeyGenerator(req.ip));

/**
 * Transferts P2P (portefeuille et billets dans la messagerie).
 */
const walletTransferLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 20,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: perUserKey,
    message: {
        error: 'Trop de transferts en peu de temps. Réessayez dans quelques minutes.',
        code: 'RATE_LIMIT_TRANSFER'
    },
    skip: () => process.env.NODE_ENV === 'test',
});

/**
 * Recherche d'un destinataire : chaque essai révèle si un compte existe,
 * le nombre de recherches est donc limité par utilisateur.
 */
const recipientLookupLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 40,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: perUserKey,
    message: {
        success: false,
        error: 'Trop de recherches de destinataire. Réessayez dans quelques minutes.',
        code: 'RATE_LIMIT_LOOKUP'
    },
    skip: () => process.env.NODE_ENV === 'test',
});

module.exports = {
    walletTransferLimiter,
    recipientLookupLimiter,
    otpSendLimiter,
    otpVerifyLimiter,
    walletOperationLimiter,
};
