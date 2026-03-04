/**
 * Tests d'authentification - Protection des routes
 * Ne nécessite PAS de base de données
 * Vérifie que le middleware auth bloque correctement les accès non autorisés
 */
const request = require('supertest');

describe('🔐 Auth - Protection des routes', () => {

    let app;

    beforeAll(() => {
        require('dotenv').config();
        app = require('../src/server');
    });

    // --- GET /auth/me (protégé par requireAuth) ---
    describe('GET /auth/me - Middleware requireAuth', () => {

        test('devrait retourner 401 sans token', async () => {
            const res = await request(app).get('/auth/me');
            expect(res.statusCode).toBe(401);
        });

        test('devrait retourner 401/403 avec un faux token', async () => {
            const res = await request(app)
                .get('/auth/me')
                .set('Authorization', 'Bearer fake_token_12345');
            expect([401, 403]).toContain(res.statusCode);
        });
    });

    // --- Vérification en masse : toutes les routes protégées ---
    describe('Routes protégées - Rejet sans token', () => {

        const protectedRoutes = [
            { method: 'get', path: '/orders' },
            { method: 'get', path: '/wallet/balance' },
            { method: 'get', path: '/wallet/transactions' },
            { method: 'post', path: '/wallet/deposit' },
            { method: 'post', path: '/wallet/withdraw' },
            { method: 'get', path: '/delivery/available' },
            { method: 'get', path: '/notifications' },
            { method: 'get', path: '/chat/conversations' },
            { method: 'post', path: '/orders' },
            { method: 'patch', path: '/orders/1/cancel' },
        ];

        protectedRoutes.forEach(({ method, path }) => {
            test(`${method.toUpperCase()} ${path} → 401 sans token`, async () => {
                const res = await request(app)[method](path);
                expect(res.statusCode).toBe(401);
            });
        });
    });

    // --- Vérification avec token invalide ---
    describe('Routes protégées - Rejet avec faux token', () => {

        const routes = [
            { method: 'get', path: '/orders' },
            { method: 'get', path: '/wallet/balance' },
            { method: 'get', path: '/delivery/available' },
        ];

        routes.forEach(({ method, path }) => {
            test(`${method.toUpperCase()} ${path} → 401/403 avec faux token`, async () => {
                const res = await request(app)[method](path)
                    .set('Authorization', 'Bearer invalid_jwt_token');
                expect([401, 403]).toContain(res.statusCode);
            });
        });
    });
});
