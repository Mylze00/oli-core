/**
 * Tests Commandes
 * Vérifie les endpoints protégés des commandes
 */
const request = require('supertest');

describe('🛒 Orders - Endpoints', () => {

    let app;

    beforeAll(() => {
        require('dotenv').config();
        app = require('../src/server');
    });

    // --- GET /orders (protégé) ---
    describe('GET /orders', () => {

        test('devrait refuser sans authentification', async () => {
            const res = await request(app)
                .get('/orders');

            expect(res.statusCode).toBe(401);
        });

        test('devrait refuser avec un token invalide', async () => {
            const res = await request(app)
                .get('/orders')
                .set('Authorization', 'Bearer invalid_token');

            expect([401, 403]).toContain(res.statusCode);
        });
    });

    // --- POST /orders (protégé) ---
    describe('POST /orders', () => {

        test('devrait refuser sans authentification', async () => {
            const res = await request(app)
                .post('/orders')
                .send({ product_id: 1, quantity: 1 });

            expect(res.statusCode).toBe(401);
        });
    });

    // --- PATCH /orders/:id/cancel (protégé) ---
    describe('PATCH /orders/:id/cancel', () => {

        test('devrait refuser sans authentification', async () => {
            const res = await request(app)
                .patch('/orders/1/cancel');

            expect(res.statusCode).toBe(401);
        });
    });

    // --- Delivery endpoints (protégé) ---
    describe('GET /delivery/available', () => {

        test('devrait refuser sans authentification', async () => {
            const res = await request(app)
                .get('/delivery/available');

            expect(res.statusCode).toBe(401);
        });
    });
});
