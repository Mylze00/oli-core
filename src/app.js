/**
 * OLI Core — Application Express principale
 *
 * Point d'entrée du backend OLI. Monte tous les middlewares et routes.
 *
 * Architecture des routes :
 *   GET  /health                   → Santé du serveur (monitoring Render)
 *   POST /api/unipesa/deposit      → Recharge Mobile Money
 *   GET  /api/unipesa/status/:id   → Statut d'une recharge (polling)
 *   POST /api/unipesa/webhook      → Callback Unipesa (confirmation)
 *   GET  /api/wallet/balance       → Solde du wallet
 *   GET  /api/wallet/history       → Historique transactions
 *   GET  /api/bank/portal          → Portail OLI Bank complet
 *   GET  /api/bank/ledger          → Grand Livre personnel
 *   GET  /api/bank/verify/:hash    → Vérification intégrité TX
 *   ...
 */

require('dotenv').config();

const express           = require('express');
const cors              = require('cors');
const pool              = require('./config/db');
const oliSessionMW      = require('./middlewares/oli_session.middleware');
const unipesaRoutes     = require('./routes/unipesa.routes');
const oliBankRoutes     = require('./routes/oli_bank.routes');

const app  = express();
const PORT = process.env.PORT || 3000;

// ─────────────────────────────────────────────────────────────────────────────
// MIDDLEWARES GLOBAUX
// ─────────────────────────────────────────────────────────────────────────────

// CORS — autoriser l'application Flutter et le Dashboard
app.use(cors({
    origin: [
        process.env.DASHBOARD_URL     || 'https://oli-admin-smoky.vercel.app',
        process.env.APP_URL           || '*',
        'http://localhost:3001',
        'http://localhost:5173',
    ],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: [
        'Content-Type', 'Authorization',
        'X-Device-Id', 'X-Device-Model', 'X-Platform', 'X-App-Version',
    ],
}));

// Parser JSON (corps des requêtes)
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

// Middleware de logging minimal
app.use((req, _res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    next();
});

// ─────────────────────────────────────────────────────────────────────────────
// ROUTE DE SANTÉ — Render vérifie cette route pour savoir si le serveur vit
// ─────────────────────────────────────────────────────────────────────────────
app.get('/health', async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.json({
            status:    'ok',
            service:   'OLI Core API',
            timestamp: new Date().toISOString(),
            db:        'connected',
        });
    } catch {
        res.status(503).json({ status: 'error', db: 'disconnected' });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
// MIDDLEWARE DE SESSION OLI (tracking) — après auth, avant les routes
// ─────────────────────────────────────────────────────────────────────────────
app.use('/api', oliSessionMW);

// ─────────────────────────────────────────────────────────────────────────────
// ROUTES PRINCIPALES
// ─────────────────────────────────────────────────────────────────────────────

// Intégration Mobile Money (Unipesa) + Wallet
app.use('/api/unipesa', unipesaRoutes);
app.use('/api',         unipesaRoutes); // Expose aussi /api/wallet/...

// OLI Bank (Grand Livre, Escrow, Portail crypto)
app.use('/api/bank',    oliBankRoutes);

// ─────────────────────────────────────────────────────────────────────────────
// GESTION DES ERREURS GLOBALES
// ─────────────────────────────────────────────────────────────────────────────
app.use((err, req, res, _next) => {
    console.error('❌ Erreur non gérée:', err.message);
    res.status(500).json({
        success: false,
        error:   process.env.NODE_ENV === 'production'
            ? 'Une erreur interne est survenue'
            : err.message,
    });
});

// Route 404
app.use((req, res) => {
    res.status(404).json({ success: false, error: `Route ${req.path} introuvable` });
});

// ─────────────────────────────────────────────────────────────────────────────
// DÉMARRAGE
// ─────────────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
    console.log(`\n🚀 OLI Core API démarrée sur le port ${PORT}`);
    console.log(`   Environnement : ${process.env.NODE_ENV || 'development'}`);
    console.log(`   Health check  : http://localhost:${PORT}/health\n`);
});

module.exports = app;
