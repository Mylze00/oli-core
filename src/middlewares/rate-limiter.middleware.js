/**
 * Rate Limiters — Protection contre le brute-force et le flood
 *
 * Appliqués sur :
 *  - /auth/send-otp    → 5 tentatives / 15 min / IP
 *  - /auth/verify-otp  → 10 tentatives / 15 min / IP
 *  - /api/wallet/deposit + /withdraw → 10 opérations / 15 min / user
 */
const rateLimit = require('express-rate-limit');

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

module.exports = {
    otpSendLimiter,
    otpVerifyLimiter,
    walletOperationLimiter,
};
