/**
 * Tests Wallet
 * Vérifie que les endpoints financiers sont bien protégés
 */
const request = require('supertest');

describe('💰 Wallet - Endpoints', () => {

    let app;

    beforeAll(() => {
        require('dotenv').config();
        app = require('../src/server');
    });

    // --- GET /wallet/balance (protégé) ---
    describe('GET /wallet/balance', () => {

        test('devrait refuser sans authentification', async () => {
            const res = await request(app)
                .get('/wallet/balance');

            expect(res.statusCode).toBe(401);
        });
    });

    // --- GET /wallet/transactions (protégé) ---
    describe('GET /wallet/transactions', () => {

        test('devrait refuser sans authentification', async () => {
            const res = await request(app)
                .get('/wallet/transactions');

            expect(res.statusCode).toBe(401);
        });
    });

    // --- POST /wallet/deposit (protégé) ---
    describe('POST /wallet/deposit', () => {

        test('devrait refuser sans authentification', async () => {
            const res = await request(app)
                .post('/wallet/deposit')
                .send({ amount: 100 });

            expect(res.statusCode).toBe(401);
        });
    });

    // --- POST /wallet/withdraw (protégé) ---
    describe('POST /wallet/withdraw', () => {

        test('devrait refuser sans authentification', async () => {
            const res = await request(app)
                .post('/wallet/withdraw')
                .send({ amount: 50 });

            expect(res.statusCode).toBe(401);
        });
    });

    // --- POST /wallet/transfer (protégé) ---
    describe('POST /wallet/transfer', () => {

        test('devrait refuser sans authentification', async () => {
            const res = await request(app)
                .post('/wallet/transfer')
                .send({ to: 'user_123', amount: 25 });

            expect(res.statusCode).toBe(401);
        });
    });
});
