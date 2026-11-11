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
    const declared = String(req.headers['x-platform'] || '').toLowerCase().slice(0, 16);
    // L'application déclare sa plateforme : son agent « Dart/… » ne la donne pas
    const deviceType = ['android', 'ios', 'web', 'windows', 'macos', 'linux'].includes(declared) ? declared
        : /android/i.test(ua) ? 'android'
        : /iphone|ipad/i.test(ua) ? 'ios'
        : /flutter/i.test(ua) ? 'flutter'
        : 'web';

    return {
        deviceType,
        deviceModel: req.headers['x-device-model'] || null,
        platform:    deviceType,
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

// La session n'est réécrite qu'une fois par minute ; le compteur d'actions, lui, suit chaque requête
const SESSION_REFRESH_MS = 60 * 1000;
const _lastTrackedAt = new Map();

function _shouldRefreshSession(sessionToken) {
    const now = Date.now();
    if (now - (_lastTrackedAt.get(sessionToken) || 0) < SESSION_REFRESH_MS) return false;
    _lastTrackedAt.set(sessionToken, now);
    // Mémoire bornée : les sessions inactives sont oubliées
    if (_lastTrackedAt.size > 5000) {
        for (const [token, at] of _lastTrackedAt) {
            if (now - at > SESSION_REFRESH_MS) _lastTrackedAt.delete(token);
        }
    }
    return true;
}

/**
 * Middleware principal OLI Session.
 *
 * Ce middleware est monté avant les routes, alors que req.user n'est rempli que par
 * l'authentification de chaque route : le suivi attend donc la fin de la réponse.
 */
function oliSessionMiddleware(req, res, next) {
    const path = (req.originalUrl || req.url || '').split('?')[0];
    if (SKIP_ROUTES.some(s => path.startsWith(s))) return next();

    res.on('finish', () => {
        const userId = req.user?.id;
        if (!userId) return;

        const rawToken = req.headers.authorization?.replace('Bearer ', '') || '';
        if (!rawToken) return;
        const sessionToken = _hashToken(rawToken);
        const isFinancial = _isFinancialRoute(path);
        const refresh = _shouldRefreshSession(sessionToken);

        setImmediate(async () => {
            try {
                if (refresh) {
                    await oliBank.trackSession(userId, {
                        sessionToken,
                        ipAddress: req.ip || req.socket?.remoteAddress || null,
                        ..._extractDeviceInfo(req),
                    });
                }
                await oliBank.incrementSessionAction(sessionToken, isFinancial);
            } catch (e) {
                // Le suivi ne doit jamais gêner l'application
                console.warn('⚠️ OLI Session tracking failed (non-blocking):', e.message);
            }
        });
    });

    next();
}

module.exports = oliSessionMiddleware;
