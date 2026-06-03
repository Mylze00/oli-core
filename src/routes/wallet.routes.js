/**
 * Routes Wallet OLI
 *
 * Préfixe de montage : /api/wallet  (défini dans server.js)
 * Auth JWT :  requireAuth appliqué globalement dans server.js (toutes les routes protégées)
 *
 * ┌─────────────────────────────────────────────────────────────────────────────┐
 * │ FLUX COMPLET — Recharge Mobile Money via Unipesa                           │
 * │                                                                             │
 * │ 1. POST /api/wallet/deposit                                                 │
 * │    Body: { amountFC, phone }                                                │
 * │    → Initie le paiement C2B → PUSH USSD sur téléphone                      │
 * │    → Retourne: { oliOrderId, status: "pending", frais... }                 │
 * │                                                                             │
 * │ 2. GET /api/wallet/status/:orderId     ← POLLING Flutter (~5s)             │
 * │    → Vérifie statut local puis API Unipesa                                  │
 * │    → Retourne: { status: pending|success|failed|timeout }                  │
 * │                                                                             │
 * │ 3. POST /webhooks/unipesa/deposit      ← Callback Unipesa (PUBLIC)         │
 * │    → Vérif signature HMAC-SHA512 → crédit wallet → update statut           │
 * │    (Géré dans webhook.routes.js → unipesa.controller.handleDeposit)        │
 * │                                                                             │
 * │ 4. GET /api/wallet/balance                                                  │
 * │    → Affiche le nouveau solde (FC + équivalent USD)                        │
 * └─────────────────────────────────────────────────────────────────────────────┘
 */

const express          = require('express');
const router           = express.Router();
const walletController = require('../controllers/wallet.controller');

// ─── GET /api/wallet/balance ─────────────────────────────────────────────────
// Solde actuel du wallet de l'utilisateur connecté.
// Retourne : { balanceFC, balanceUSD, currency: 'FC', is_frozen, ... }
router.get('/balance', walletController.getBalance);

// ─── GET /api/wallet/summary ─────────────────────────────────────────────────
// Résumé complet du wallet (solde, stats, transactions récentes)
router.get('/summary', walletController.getSummary);

// ─── GET /api/wallet/transactions ────────────────────────────────────────────
// Historique des transactions (query: ?limit=30&offset=0)
router.get('/transactions', walletController.getHistory);

// ─── GET /api/wallet/status/:orderId ─────────────────────────────────────────
// Polling du statut d'une opération Mobile Money initiée.
// Appelé par Flutter toutes les ~5 secondes après POST /deposit ou POST /withdraw.
//
// Params : orderId  — ex: "DEP-42-1717000000000"
// Retour : { status: "pending"|"success"|"failed"|"timeout", wallet? }
router.get('/status/:orderId', walletController.getPaymentStatus);

// ─── POST /api/wallet/deposit ────────────────────────────────────────────────
// Lance une recharge Mobile Money → Wallet OLI via l'agrégateur Unipesa.
//
// Body requis   : { amountFC: number, phone: string }
// Body optionnel: { provider: string }  — détecté automatiquement depuis le numéro
//
// Flux interne  : walletService.deposit() → unipesaService.initiateDeposit()
//                 → POST Unipesa C2B → PUSH USSD téléphone → status "pending"
//
// Le crédit du wallet OLI est effectué APRÈS réception du webhook Unipesa.
router.post('/deposit', walletController.deposit);

// ─── POST /api/wallet/deposit-card ───────────────────────────────────────────
// Recharge via Carte bancaire (Equity/Ecobank — non disponible actuellement)
// Body: { amount, cardNumber, expiryDate, cvv, cardholderName? }
router.post('/deposit-card', walletController.depositCard);

// ─── POST /api/wallet/withdraw ───────────────────────────────────────────────
// Retrait du Wallet OLI vers Mobile Money (B2C Unipesa).
//
// Body requis   : { amountFC: number, phone: string }
// Body optionnel: { provider: string }
//
// Flux interne  : walletService.withdraw() → débit immédiat wallet
//                 → unipesaService.initiateWithdrawal() → B2C Unipesa
//                 → push fonds vers téléphone
router.post('/withdraw', walletController.withdraw);

// ─── POST /api/wallet/transfer ───────────────────────────────────────────────
// Transfert P2P entre utilisateurs OLI (interne — pas de Mobile Money).
// Body: { receiverId: number, amount: number, currency?: 'FC'|'USD' }
router.post('/transfer', walletController.transfer);

module.exports = router;
