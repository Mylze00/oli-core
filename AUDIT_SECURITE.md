# Rapport Analyse Consolidee - oli-core

## ALERTES CRITIQUES IMMEDIATES

### ALERTE A - /api/debug expose le schema DB sans auth
Fichier: src/routes/debug.routes.js + src/server.js ligne 333
GET /api/debug/db-schema : expose toutes les tables, colonnes users, hote DB sans authentification.
GET /api/debug/order-status/:id : expose les 10 dernieres commandes en clair.
Action immediate : couper cette route en production.

### ALERTE B - price-worker sans authentification
Fichier: src/server.js lignes 278-286
N'importe qui peut POST /api/price-worker/run et recalculer les prix de tous les produits.

### ALERTE C - CORS accepte tous les *.vercel.app
Fichier: src/server.js lignes 222-225
if (origin.endsWith('.vercel.app')) return callback(null, true);
Un attaquant sur evil-app.vercel.app peut faire des requetes credentialed vers votre API.

## TOP 10 AMELIORATIONS PARETO

### 1 - SECU CRITIQUE - OTP en clair dans la reponse API
Fichier: src/controllers/auth.controller.js ligne 32
otp: otpCode est retourne dans la reponse JSON publique.
Impact: Compromission totale de l'auth. 2 requetes HTTP pour hijacker n'importe quel compte.
Effort: Faible (supprimer 1 ligne). Risque: Nul.

### 2 - SECU - Routes sensibles sans authentification
Fichier: src/server.js lignes 278-286, 306-309, 333
/api/price-worker, /api/debug, /api/identity, /api/verification sans requireAuth.
Impact: Reconnaissance infrastructure, manipulation prix, exposition donnees personnelles.
Effort: Faible. Risque: Faible.

### 3 - SECU - Rate limiting absent sur auth et wallet
Aucun rate limiter sur /auth/send-otp, /auth/verify-otp, /api/wallet/deposit, /api/wallet/withdraw.
OTP_MAX_ATTEMPTS existe dans config mais marque [Phase 2] non implemente.
Impact: Brute-force OTP (10^6 combos), couts SMS, DDoS financier.
Effort: Faible (express-rate-limit). Risque: Faible.

### 4 - SECU - CORS *.vercel.app contourne la whitelist
Toute app Vercel gratuite peut faire des requetes avec credentials vers votre API.
Impact: CSRF, vol de sessions, bypass CORS.
Effort: Faible. Risque: Faible.

### 5 - SECU/FINANCE - Webhook Unipesa bypass HMAC
Fichier: src/services/unipesa.service.js lignes 316-322
Le polling appelle processWebhook() directement sans verification de signature.
Impact: Credit de wallet sans paiement reel (fraude financiere).
Effort: Moyen. Risque: Moyen.

### 6 - PERF - ORDER BY RANDOM() sur 4 requetes page accueil
Fichier: src/repositories/product.repository.js lignes 48, 72, 104, 123
Full-scan PostgreSQL a chaque chargement du fil. Sur 10k produits: 200ms par requete.
Effort: Moyen. Risque: Faible.

### 7 - BUG - _insertTx calcule balance_before incorrectement
Fichier: src/repositories/wallet.repository.js ligne 292
balanceAfter - txData.amount est faux pour les debits (amount negatif).
Corruption silencieuse de l'historique des transactions P2P.
Effort: Faible. Risque: Faible.

### 8 - ARCHI - Auto-migration SQL a chaque demarrage serveur
Fichier: src/server.js lignes 386-427
CREATE TABLE, ALTER TABLE, et execution de 039_oli_bank_crypto.sql a chaque restart.
Impact: +200-500ms demarrage, risk de lock tables en prod.
Effort: Moyen. Risque: Moyen.

### 9 - PERF - Pagination manquante sur endpoints critiques
order.repository.js getOrdersByUser() : aucun LIMIT
product.repository.js findBySeller() : aucun LIMIT
Impact: Fetch complet pour vendeurs avec 500+ produits.
Effort: Faible. Risque: Faible.

### 10 - QUALITE - console.log avec donnees personnelles en prod (200+ occurrences)
Numeros de telephone, montants, sessions Socket logges en clair.
Impact: RGPD, couts logging, performances I/O.
Effort: Faible (pino logger). Risque: Nul.

## TABLEAU DE SYNTHESE

| # | Titre | Impact | Effort | Risque |
|---|-------|--------|--------|--------|
| A | /api/debug public | Critique | Faible | Nul |
| B | price-worker sans auth | Eleve | Faible | Nul |
| C | CORS *.vercel.app | Eleve | Faible | Faible |
| 1 | OTP expose en reponse | Critique | Faible | Nul |
| 2 | Routes sensibles publiques | Eleve | Faible | Faible |
| 3 | Rate limiting absent | Eleve | Faible | Faible |
| 5 | Webhook HMAC bypass | Critique | Moyen | Moyen |
| 6 | ORDER BY RANDOM() x4 | Eleve | Moyen | Faible |
| 7 | Bug _insertTx | Eleve | Faible | Faible |
| 8 | Auto-migration au boot | Moyen | Moyen | Moyen |
| 9 | Pagination manquante | Moyen | Faible | Faible |
| 10 | console.log en prod | Faible | Faible | Nul |

## PHASE 3 - SELECTION

Quelles optimisations souhaitez-vous appliquer ?
Indiquez les numeros (A, B, C, 1, 2, 3... ou 'tout')
Recommandation: A, B, C, 1, 3, 7 (effort faible, impact critique/eleve, risque nul/faible)
