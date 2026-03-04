/**
 * Configuration globale des tests
 * Charge l'environnement et exporte les utilitaires partagés
 */
require('dotenv').config();
const pool = require('../src/config/db');

// Fermer la connexion DB après tous les tests
afterAll(async () => {
    await pool.end();
});

module.exports = { pool };
