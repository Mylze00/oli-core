/**
 * Tests Health Check
 * Vérifie que le serveur répond correctement
 */
const request = require('supertest');

describe('❤️ Health Check', () => {

    let app;

    beforeAll(() => {
        require('dotenv').config();
        app = require('../src/server');
    });

    test('GET /health devrait retourner status ok', async () => {
        const res = await request(app)
            .get('/health');

        expect(res.statusCode).toBe(200);
        expect(res.body).toHaveProperty('status', 'ok');
        expect(res.body).toHaveProperty('version');
        expect(res.body).toHaveProperty('environment');
    });
});
