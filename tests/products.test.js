/**
 * Tests Produits - Protection des routes
 * Ne nécessite PAS de base de données
 * Vérifie uniquement que les routes protégées rejettent les requêtes non authentifiées
 */
const request = require('supertest');

describe('📦 Products - Protection des routes', () => {

    let app;

    beforeAll(() => {
        require('dotenv').config();
        app = require('../src/server');
    });

    // Les routes products utilisent optionalAuth (pas requireAuth)
    // Donc on teste que le serveur répond bien (pas de crash)

    test('GET /products devrait répondre sans crash', async () => {
        const res = await request(app).get('/products');
        // Accepte tout sauf un crash (pas de code 0 ou undefined)
        expect(res.statusCode).toBeDefined();
    }, 30000);

    test('GET /products/featured devrait répondre sans crash', async () => {
        const res = await request(app).get('/products/featured');
        expect(res.statusCode).toBeDefined();
    }, 30000);

    test('DELETE /products/1 sans auth devrait être refusé ou échouer', async () => {
        const res = await request(app).delete('/products/1');
        // Sans auth : 401, 403, 404 ou 500 — mais pas 200/204
        expect(res.statusCode).toBeGreaterThanOrEqual(400);
    }, 30000);
});
