# 🏗️ ARCHITECTURE COMPLÈTE DU PROJET OLI

**Date d'analyse :** 25 Mai 2026  
**Analyse complète :** Code par code, route par route, logique métier complète

---

## 📱 1. DÉTECTION AUTOMATIQUE DES OPÉRATEURS (RDC)

### Préfixes des opérateurs Mobile Money en RDC

```javascript
/**
 * Détection automatique de l'opérateur basée sur le préfixe du numéro
 * Standard RDC (République Démocratique du Congo)
 */

const OPERATOR_PREFIXES = {
    vodacom: ['81', '82', '83', '84'],      // Vodacom M-Pesa
    orange: ['85', '89', '88'],             // Orange Money
    airtel: ['90', '91', '97', '98', '99'], // Airtel Money
    africell: ['95', '96']                  // Africell Money
};

function detectOperatorFromPhone(phoneNumber) {
    // Nettoyer le numéro : +243827088682 → 827088682
    const cleaned = phoneNumber.replace(/[\s\-\+]/g, '');
    
    // Extraire les 2 chiffres après le code pays 243
    let prefix = '';
    
    if (cleaned.startsWith('243')) {
        prefix = cleaned.substring(3, 5); // 827088682 → 82
    } else if (cleaned.startsWith('0')) {
        prefix = cleaned.substring(1, 3); // 0827088682 → 82
    } else {
        prefix = cleaned.substring(0, 2); // 827088682 → 82
    }
    
    // Détecter l'opérateur
    for (const [operator, prefixes] of Object.entries(OPERATOR_PREFIXES)) {
        if (prefixes.includes(prefix)) {
            return operator;
        }
    }
    
    return null; // Opérateur non détecté
}

// Exemples
detectOperatorFromPhone('+243827088682'); // → 'vodacom'
detectOperatorFromPhone('+243850123456'); // → 'orange'
detectOperatorFromPhone('+243901234567'); // → 'airtel'
detectOperatorFromPhone('+243951234567'); // → 'africell'
```

### Validation pour le numéro +243827088682

```
Numéro : +243827088682
Préfixe : 82
Opérateur : 🔵 VODACOM (M-Pesa)

✅ Correct : Vodacom M-Pesa
❌ Erreur : Orange Money (comme dans la page actuelle)
```

---

## 🗺️ 2. CARTOGRAPHIE COMPLÈTE DES ROUTES API

### 2.1 Routes Wallet (`src/routes/wallet.routes.js`)

```javascript
POST /wallet/deposit
├─ Controller: wallet.controller.deposit
├─ Middleware: requireAuth
├─ Body: { amount, provider, phoneNumber }
├─ Service: walletService.deposit(userId, amount, provider, phoneNumber)
├─ Flow:
│  1. Validation montant et opérateur
│  2. Calcul frais 5%
│  3. Appel Unipesa C2B
│  4. Création transaction pending
│  5. Webhook confirme → crédit wallet
└─ Response: { success, transaction, message }

POST /wallet/withdraw
├─ Controller: wallet.controller.withdraw
├─ Middleware: requireAuth
├─ Body: { amount, provider, phoneNumber }
├─ Service: walletService.withdraw(userId, amount, provider, phoneNumber)
├─ Flow:
│  1. Vérification solde (montant + frais 5%)
│  2. Débit immédiat wallet
│  3. Appel Unipesa B2C
│  4. Webhook confirme → crédit Banque OLI
└─ Response: { success, transaction, message }

GET /wallet/balance
├─ Controller: wallet.controller.getBalance
├─ Middleware: requireAuth
├─ Service: walletService.getBalance(userId)
└─ Response: { balance }

GET /wallet/history
├─ Controller: wallet.controller.getHistory
├─ Middleware: requireAuth
├─ Query: ?limit=30
├─ Service: walletService.getHistory(userId, limit)
└─ Response: { transactions: [...] }

POST /wallet/transfer
├─ Controller: wallet.controller.transferToUser
├─ Middleware: requireAuth
├─ Body: { receiverId, amount, currency }
├─ Service: walletService.transferToUser(senderId, receiverId, amount, currency)
└─ Response: { success, reference, balances }
```

### 2.2 Routes Commandes (`src/routes/order.routes.js`)

```javascript
POST /orders
├─ Controller: order.controller.createOrder
├─ Middleware: requireAuth
├─ Body: { items, deliveryAddress, paymentMethod, deliveryFee }
├─ Service: orderService.createOrder(userId, data, io)
├─ Flow (paymentMethod='wallet'):
│  1. Validation items
│  2. Calcul total
│  3. Débit wallet (walletService.payOrder)
│  4. Création commande
│  5. Génération codes pickup/delivery
│  6. Notifications vendeur/acheteur
│  7. Création delivery_orders (si Circuit A)
└─ Response: { id, status, pickup_code, delivery_code }

GET /orders
├─ Controller: order.controller.getUserOrders
├─ Middleware: requireAuth
└─ Response: { orders: [...] }

GET /orders/:id
├─ Controller: order.controller.getOrderById
├─ Middleware: requireAuth
└─ Response: { order }

POST /orders/:id/process
├─ Controller: order.controller.markProcessing
├─ Middleware: requireAuth, requireSeller
├─ Service: orderService.markProcessing(orderId, sellerId, io)
└─ Response: { order, pickup_code }

POST /orders/:id/ready
├─ Controller: order.controller.markReady
├─ Middleware: requireAuth, requireSeller
└─ Response: { order }

POST /orders/:id/verify-pickup
├─ Controller: order.controller.verifyPickup
├─ Body: { code }
├─ Service: orderService.verifyPickup(orderId, code, userId, io)
├─ Circuit B (Pick&Go): → delivered + creditSeller
├─ Circuit A (Livreur): → shipped
└─ Response: { order, verified: true }

POST /orders/:id/verify-delivery
├─ Controller: order.controller.verifyDelivery
├─ Body: { code }
├─ Service: orderService.verifyDelivery(orderId, code, userId, io)
├─ → delivered + creditSeller + creditDeliverer
└─ Response: { order, verified: true }

GET /orders/:id/tracking
├─ Controller: order.controller.getOrderTracking
├─ Service: orderService.getOrderTracking(orderId, userId)
└─ Response: { steps, history, codes }
```

### 2.3 Routes Webhooks (`src/routes/unipesa.routes.js`)

```javascript
POST /webhooks/unipesa/deposit
├─ Controller: unipesa.controller.handleDepositWebhook
├─ Body: { merchant_id, order_id, amount, status, signature }
├─ Flow:
│  1. Vérification signature HMAC-SHA512
│  2. Si status=2 (SUCCESS):
│     a. Récupérer transaction pending
│     b. Calculer montant net (- frais 5%)
│     c. Créditer wallet utilisateur
│     d. Créditer Banque OLI (frais)
│     e. Mettre à jour status → completed
└─ Response: { received: true }

POST /webhooks/unipesa/withdrawal
├─ Controller: unipesa.controller.handleWithdrawalWebhook
├─ Similar flow pour les retraits
└─ Response: { received: true }
```

### 2.4 Routes Produits (`src/routes/product.routes.js`)

```javascript
GET /products
├─ Query: ?category=x&minPrice=10&maxPrice=100
├─ Service: productService.getAllProducts(filters, limit, offset)
└─ Response: { products: [...], total }

POST /products
├─ Middleware: requireAuth
├─ Body: { name, price, category, quantity, images, ... }
├─ Service: productService.createProduct(userId, data, files)
├─ Auto-catégorisation si category='other'
├─ Création variantes (colors, sizes)
└─ Response: { id, product }

GET /products/featured
├─ Filter: Produits de l'admin (+243827088682)
└─ Response: { products: [...] }

PUT /products/:id
├─ Middleware: requireAuth
├─ Vérification ownership
└─ Response: { product }

DELETE /products/:id
├─ Soft delete (status='deleted')
└─ Response: { success: true }
```

---

## 🗄️ 3. STRUCTURE DE LA BASE DE DONNÉES

### 3.1 Tables principales

```sql
-- USERS (Utilisateurs)
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20) UNIQUE NOT NULL,           -- +243827088682
    password VARCHAR(255),
    role VARCHAR(20) DEFAULT 'user',             -- user, seller, deliverer, admin
    wallet DECIMAL(10,2) DEFAULT 0,              -- Solde wallet USD
    reward_points INT DEFAULT 0,
    is_verified BOOLEAN DEFAULT FALSE,
    is_admin BOOLEAN DEFAULT FALSE,
    account_type VARCHAR(50),                    -- individual, entreprise
    has_certified_shop BOOLEAN DEFAULT FALSE,
    avatar_url TEXT,
    id_oli VARCHAR(50) UNIQUE,                   -- Identifiant OLI unique
    total_sales INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- WALLETS (Portefeuilles)
CREATE TABLE wallets (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    balance DECIMAL(10,2) DEFAULT 0,
    is_frozen BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- WALLET_TRANSACTIONS (Historique transactions)
CREATE TABLE wallet_transactions (
    id SERIAL PRIMARY KEY,
    wallet_id INT REFERENCES wallets(id),
    user_id INT REFERENCES users(id),
    type VARCHAR(50),                            -- deposit, withdrawal, payment, credit, transfer, reward, refund
    amount DECIMAL(10,2),                        -- Montant (positif ou négatif)
    balance_after DECIMAL(10,2),                 -- Solde après transaction
    provider VARCHAR(50),                        -- UNIPESA, OLI_PLATFORM, P2P, OLI_REWARDS, SYSTEM_FEE
    reference VARCHAR(255) UNIQUE,               -- DEP_123_1737766800000
    description TEXT,
    order_id INT REFERENCES orders(id),
    metadata JSONB,                              -- { netAmount, feeAmount, provider, ... }
    status VARCHAR(20) DEFAULT 'completed',      -- pending, completed, failed
    created_at TIMESTAMP DEFAULT NOW()
);

-- PRODUCTS (Produits)
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    seller_id INT REFERENCES users(id),
    shop_id INT REFERENCES shops(id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category VARCHAR(100),                       -- Électronique, Vêtements, etc.
    subcategory VARCHAR(100),
    images TEXT[],                               -- Array d'URLs
    quantity INT DEFAULT 1,
    condition VARCHAR(50),                       -- new, used, refurbished
    status VARCHAR(20) DEFAULT 'active',         -- active, inactive, deleted
    delivery_price DECIMAL(10,2) DEFAULT 0,
    delivery_time VARCHAR(50),
    location VARCHAR(255),
    is_negotiable BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    brand_certified BOOLEAN DEFAULT FALSE,
    view_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- PRODUCT_VARIANTS (Variantes de produits)
CREATE TABLE product_variants (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    variant_type VARCHAR(50),                    -- color, size, capacity
    variant_value VARCHAR(100),                  -- Rouge, XL, 256GB
    stock_quantity INT DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(product_id, variant_type, variant_value)
);

-- ORDERS (Commandes)
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),            -- Acheteur
    status VARCHAR(50) DEFAULT 'pending',        -- pending, paid, processing, ready, shipped, delivered, cancelled
    payment_status VARCHAR(50) DEFAULT 'pending',-- pending, completed, failed
    payment_method VARCHAR(50),                  -- wallet, mobile_money, cash_on_delivery
    total_amount DECIMAL(10,2) NOT NULL,
    delivery_fee DECIMAL(10,2) DEFAULT 0,
    delivery_address TEXT,
    delivery_method_id VARCHAR(50),              -- oli_express, oli_standard, pick_go, hand_delivery
    pickup_code VARCHAR(6),                      -- A3K9P7
    delivery_code VARCHAR(6),                    -- X7M2N5
    processing_at TIMESTAMP,
    ready_at TIMESTAMP,
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ORDER_ITEMS (Produits dans commande)
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id),
    product_id VARCHAR(50),                      -- Peut être supprimé après
    product_name VARCHAR(255),
    product_price DECIMAL(10,2),
    quantity INT DEFAULT 1,
    seller_id INT REFERENCES users(id)
);

-- ORDER_STATUS_HISTORY (Historique statuts commande)
CREATE TABLE order_status_history (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id),
    previous_status VARCHAR(50),
    new_status VARCHAR(50),
    changed_by INT REFERENCES users(id),
    changed_by_role VARCHAR(50),                 -- buyer, seller, deliverer, system
    created_at TIMESTAMP DEFAULT NOW()
);

-- DELIVERY_ORDERS (Livraisons)
CREATE TABLE delivery_orders (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id),
    deliverer_id INT REFERENCES users(id),
    pickup_address TEXT,
    delivery_address TEXT,
    delivery_fee DECIMAL(10,2),
    estimated_time VARCHAR(50),
    status VARCHAR(50) DEFAULT 'pending',        -- pending, assigned, picked_up, delivered
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- SHOPS (Boutiques)
CREATE TABLE shops (
    id SERIAL PRIMARY KEY,
    owner_id INT REFERENCES users(id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    logo_url TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- OLI_BANK_LEDGER (Grand livre OLI Bank)
CREATE TABLE oli_bank_ledger (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    transaction_type VARCHAR(50),                -- deposit, withdrawal, escrow_lock, escrow_release
    amount DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'USD',
    reference VARCHAR(255),
    metadata JSONB,                              -- { orderId, provider, fee, ... }
    portal_balance DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW()
);

-- OLI_BANK_PORTALS (Portails utilisateurs OLI Bank)
CREATE TABLE oli_bank_portals (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) UNIQUE,
    balance DECIMAL(10,2) DEFAULT 0,
    credit_limit DECIMAL(10,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 4. LOGIQUE MÉTIER COMPLÈTE

### 4.1 Flux de paiement Mobile Money (Dépôt)

```
1. CLIENT initie dépôt $15.00
   ↓
2. FRONTEND détecte opérateur automatiquement
   +243827088682 → préfixe 82 → Vodacom
   ↓
3. POST /wallet/deposit
   Body: { amount: 15, provider: 'vodacom', phoneNumber: '+243827088682' }
   ↓
4. BACKEND calcule frais 5%
   $15.00 × 1.05 = $15.75 total à payer
   ↓
5. BACKEND appelle Unipesa C2B
   unipesaService.depositC2B({
     amount: 15.75,
     provider: 'vodacom',
     phoneNumber: '+243827088682',
     provider_id: 9  // Vodacom dans Unipesa
   })
   ↓
6. UNIPESA envoie USSD au téléphone
   "Confirmez le paiement de 43 995 FC (15.75 USD)
    Entrez votre code PIN M-Pesa"
   ↓
7. CLIENT entre PIN sur téléphone
   ↓
8. UNIPESA confirme et envoie webhook
   POST https://oli-api.com/webhooks/unipesa/deposit
   {
     merchant_id: "...",
     order_id: "DEP_123_...",
     amount: 15.75,
     currency: "USD",
     status: 2,  // SUCCESS
     provider_id: 9,
     signature: "..."
   }
   ↓
9. BACKEND vérifie signature HMAC
   ↓
10. BACKEND crédite wallet
    - Wallet user: +$15.00
    - Banque OLI (user 0): +$0.75 (frais)
   ↓
11. FRONTEND affiche succès
    "Paiement réussi ! +$15.00"
```

### 4.2 Flux de commande avec codes de vérification

```
1. CLIENT crée commande
   POST /orders
   { items: [...], paymentMethod: 'wallet', deliveryFee: 2.00 }
   ↓
2. BACKEND débite wallet immédiatement
   Total: $17.00 (produit $15 + livraison $2)
   walletService.payOrder(userId, 17.00, orderId)
   ↓
3. BACKEND génère codes uniques
   pickup_code: "A3K9P7"    (pour vendeur/livreur)
   delivery_code: "X7M2N5"  (pour acheteur)
   ↓
4. BACKEND crée delivery_orders
   Si deliveryMethodId in ['oli_express', 'oli_standard', 'partner']
   ↓
5. BACKEND envoie notifications
   - Acheteur: "Commande confirmée ! Code de réception: X7M2N5"
   - Vendeur: "Nouvelle commande ! Code pickup: A3K9P7"
   ↓
6. VENDEUR prépare commande
   POST /orders/:id/process
   Status: paid → processing
   ↓
7. VENDEUR marque prêt
   POST /orders/:id/ready
   Status: processing → ready
   Notification livreur avec pickup_code
   ↓
8. LIVREUR récupère (Circuit A)
   POST /orders/:id/verify-pickup
   Body: { code: "A3K9P7" }
   Status: ready → shipped
   ↓
9. ACHETEUR confirme réception (Circuit A)
   POST /orders/:id/verify-delivery
   Body: { code: "X7M2N5" }
   Status: shipped → delivered
   ↓
10. BACKEND distribue les fonds
    - Vendeur: +$15.00 (walletService.creditSeller)
    - Livreur: +$2.00 (walletService.creditDeliverer)
```

### 4.3 Circuits de livraison

**Circuit A - Avec Livreur OLI:**
```
paid → processing → ready → shipped → delivered
        (vendeur)   (vendeur) (livreur) (acheteur)
                                         ↓
                                    PAIEMENT
```

**Circuit B - Pick & Go (Retrait guichet):**
```
paid → processing → delivered
        (vendeur)   (acheteur pickup)
                    ↓
               PAIEMENT IMMÉDIAT
```

**Circuit C - Hand Delivery (Remise main propre):**
```
paid → processing → delivered
        (vendeur)   (vendeur vérifie)
                    ↓
               PAIEMENT IMMÉDIAT
```

---

## 5. MAPPING PROVIDERS UNIPESA

```javascript
// Configuration Unipesa (src/config/unipesa.config.js)
PROVIDERS: {
    VODACOM:   9,    // M-Pesa (+24381, +24382, +24383, +24384)
    ORANGE:    10,   // Orange Money (+24385, +24389, +24388)
    AIRTEL:    17,   // Airtel Money (+24390, +24391, +24397, +24398, +24399)
    AFRICELL:  19,   // Africell Money (+24395, +24396)
    EQUITY:    20,   // Carte bancaire Equity
    ECOBANK:   23,   // Carte bancaire Ecobank
    VISA:      5002, // VISA RDC
    SIMULATOR: 14    // Mode test
}

// Résolution automatique
_resolveProviderId(provider) {
    const map = {
        'vodacom':  9,
        'mpesa':    9,
        'orange':   10,
        'orangemoney': 10,
        'airtel':   17,
        'africell': 19,
        'card':     20
    };
    return map[provider.toLowerCase()] ?? 14;
}
```

---

## 6. FICHIERS CLÉS DU PROJET

```
oli-core/
├── src/
│   ├── config/
│   │   ├── db.js                              ← Configuration PostgreSQL
│   │   ├── unipesa.config.js                  ← Clés Unipesa + Providers
│   │   └── index.js                           ← Config générale
│   │
│   ├── services/
│   │   ├── wallet.service.js                  ⭐ Logique wallet (8 flux)
│   │   ├── unipesa.service.js                 ⭐ API Unipesa C2B/B2C
│   │   ├── order.service.js                   ⭐ Gestion commandes
│   │   ├── product.service.js                 ⭐ Gestion produits/stock
│   │   ├── mobile-money.service.js            ← Simulateur MM
│   │   └── oli_bank.service.js                ← Grand Livre OLI
│   │
│   ├── repositories/
│   │   ├── wallet.repository.js               ← Accès DB wallet
│   │   ├── order.repository.js                ← Accès DB orders
│   │   └── product.repository.js              ← Accès DB products
│   │
│   ├── controllers/
│   │   ├── wallet.controller.js               ← Endpoints wallet
│   │   ├── order.controller.js                ← Endpoints orders
│   │   ├── unipesa.controller.js              ⭐ Webhooks Unipesa
│   │   └── product.controller.js              ← Endpoints products
│   │
│   ├── routes/
│   │   ├── wallet.routes.js                   ← Routes /wallet/*
│   │   ├── order.routes.js                    ← Routes /orders/*
│   │   ├── product.routes.js                  ← Routes /products/*
│   │   └── unipesa.routes.js                  ← Routes /webhooks/unipesa/*
│   │
│   ├── middlewares/
│   │   ├── auth.middleware.js                 ← JWT validation
│   │   ├── isAdmin.middleware.js              ← +243827088682 = MASTER
│   │   └── requireDeliverer.middleware.js     ← Role deliverer
│   │
│   └── server.js                              ⭐ Point d'entrée principal
│
├── migrations/                                 ← Scripts SQL
├── tests/                                      ← Tests unitaires
└── .env.local                                  ← Variables d'environnement
```

---

## 7. VARIABLES D'ENVIRONNEMENT CRITIQUES

```bash
# Base de données
DATABASE_URL=postgresql://user:pass@host:5432/oli_db

# Unipesa (Mobile Money)
UNIPESA_API_URL=https://api.unipesa.tech
UNIPESA_PUBLIC_ID=f54ec96649be...
UNIPESA_MERCHANT_ID=e0fecd91fcb2...
UNIPESA_SECRET_KEY=xxxxxxxxxxxxx

# URLs
APP_URL=https://api.oli-core.com
FRONTEND_URL=https://oli-core.com

# JWT
JWT_SECRET=oli_strong_secret_change_me
JWT_EXPIRES_IN=15m

# Taux de conversion
FC_TO_USD=2800

# Admin master
ADMIN_PHONE=+243827088682
```

---

## 8. SÉCURITÉ & VALIDATIONS

### Vérifications automatiques

```javascript
// 1. Validation numéro RDC
function validateRDCPhone(phone) {
    const cleaned = phone.replace(/[\s\-\+]/g, '');
    return /^(243|0)?[8-9][0-9]{7}$/.test(cleaned);
}

// 2. Vérification solde avant retrait
if (balance < totalToDeduct) {
    throw new Error('Solde insuffisant');
}

// 3. Vérification signature webhook
function verifyWebhookSignature(payload) {
    const receivedSignature = payload.signature;
    const computed = calculateHMAC(payload, SECRET_KEY);
    return computed === receivedSignature;
}

// 4. Protection double-retrait
// Débit AVANT l'appel API externe
await performWithdrawal(userId, amount, ...);
const result = await unipesaAPI.withdrawB2C(...);
if (!result.success) {
    await performDeposit(userId, amount, ...); // Remboursement
}

// 5. Vérification ownership
const isOwner = await checkOwnership(productId, userId);
if (!isOwner) throw new Error('Non autorisé');
```

---

## 9. POINTS D'ATTENTION

### ⚠️ Erreurs fréquentes

1. **Opérateur incorrect**
   ```
   ❌ +243827088682 → Orange Money
   ✅ +243827088682 → Vodacom M-Pesa (préfixe 82)
   ```

2. **Frais non inclus**
   ```
   ❌ Client paie $15.00 → erreur
   ✅ Client paie $15.75 ($15 + 5% frais)
   ```

3. **Codes non générés**
   ```
   ❌ Commande créée sans pickup_code/delivery_code
   ✅ Génération automatique à la création
   ```

4. **Webhook timeout**
   ```
   ⏱️ Webhook doit arriver en < 5 minutes
   Si timeout → transaction reste en "pending"
   ```

---

## 10. PROCHAINES AMÉLIORATIONS

### Court terme
- [ ] Détection automatique opérateur (frontend + backend)
- [ ] Validation préfixes RDC
- [ ] Dashboard analytics temps réel
- [ ] Alertes webhook timeout

### Moyen terme
- [ ] Support multi-devises (USD, CDF, EUR)
- [ ] Réconciliation automatique quotidienne
- [ ] API rate limiting
- [ ] Backup automatique ledger

### Long terme
- [ ] Intelligence artificielle (détection fraude)
- [ ] Blockchain pour transactions critiques
- [ ] Support crypto-monnaies
- [ ] Paiement en plusieurs fois

---

## ✅ CHECKLIST PRODUCTION

- [ ] Clés Unipesa production configurées
- [ ] HTTPS activé (certificat SSL)
- [ ] Détection opérateur automatique
- [ ] Webhooks accessibles publiquement
- [ ] Base de données sauvegardée quotidiennement
- [ ] Monitoring actif (Sentry, DataDog)
- [ ] Tests E2E avec vrais numéros
- [ ] Documentation API complète
- [ ] Rate limiting configuré
- [ ] Logs centralisés

---

**Architecture analysée et documentée - 25 Mai 2026**  
**Projet OLI - Marketplace E-commerce RDC**
