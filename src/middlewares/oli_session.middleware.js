/**
 * OLI Session Middleware
 *
 * Ce middleware intercepte chaque requête authentifiée et :
 *  1. Enregistre/met à jour la session dans user_sessions_ext
 *  2. Incrémente le compteur d'actions (financières ou non)
 *  3. Détecte les comportements suspects (multi-device, IP changeante, burst)
 *  4. Notifie la Banque OLI de tout événement critique
 */

const oliBank = require('../services/oli_bank.service');
const crypto  = require('crypto');

// Routes considérées comme "financières"
const FINANCIAL_ROUTES = [
    '/wallet/deposit', '/wallet/withdraw', '/wallet/transfer',
    '/wallet/deposit-card', '/bank/', '/orders',
    '/payment', '/checkout',
];

// Routes à ignorer (pas de tracking)
const SKIP_ROUTES = [
    '/health', '/favicon', '/static', '/__',
];

/**
 * Génère un token de session stable à partir du JWT d'entrée.
 * On ne stocke jamais le JWT en clair — seulement son hash SHA-256.
 */
function _hashToken(token) {
    return crypto.createHash('sha256').update(token || '').digest('hex').slice(0, 64);
}

/**
 * Extrait les infos de device depuis les headers.
 */
function _extractDeviceInfo(req) {
    const ua = req.headers['user-agent'] || '';
    const deviceType = /android/i.test(ua) ? 'android'
        : /iphone|ipad/i.test(ua) ? 'ios'
        : /flutter/i.test(ua) ? 'flutter'
        : 'web';

    return {
        deviceType,
        deviceModel: req.headers['x-device-model'] || null,
        platform:    req.headers['x-platform'] || deviceType,
        appVersion:  req.headers['x-app-version'] || null,
        deviceId:    req.headers['x-device-id'] || null,
    };
}

/**
 * Détermine si la route courante est financière.
 */
function _isFinancialRoute(path) {
    return FINANCIAL_ROUTES.some(route => path.includes(route));
}

/**
 * Middleware principal OLI Session.
 */
async function oliSessionMiddleware(req, res, next) {
    try {
        // Ignorer certaines routes
        const path = req.path || '';
        if (SKIP_ROUTES.some(s => path.startsWith(s))) {
            return next();
        }

        // Ne tracker que si l'utilisateur est authentifié
        if (!req.user?.id) return next();

        const userId = req.user.id;
        const rawToken = req.headers.authorization?.replace('Bearer ', '') || '';
        const sessionToken = _hashToken(rawToken || `${userId}-${Date.now()}`);

        const deviceInfo = _extractDeviceInfo(req);
        const ipAddress  = req.ip || req.connection?.remoteAddress || null;
        const isFinancial = _isFinancialRoute(path);

        // Tracker la session de manière non-bloquante
        setImmediate(async () => {
            try {
                await oliBank.trackSession(userId, {
                    sessionToken,
                    ipAddress,
                    ...deviceInfo,
                });

                if (isFinancial) {
                    await oliBank.incrementSessionAction(sessionToken, true);
                } else {
                    await oliBank.incrementSessionAction(sessionToken, false);
                }
            } catch (e) {
                // Le tracking ne doit jamais bloquer la requête principale
                console.warn('⚠️ OLI Session tracking failed (non-blocking):', e.message);
            }
        });

        // Attacher les infos de session à la requête
        req.oliSession = { sessionToken, isFinancial, deviceInfo };

        next();
    } catch (err) {
        // Non-fatal — toujours laisser passer la requête
        console.warn('⚠️ OLI Session Middleware error:', err.message);
        next();
    }
}

module.exports = oliSessionMiddleware;
