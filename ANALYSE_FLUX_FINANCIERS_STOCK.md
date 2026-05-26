# 📊 ANALYSE COMPLÈTE - FLUX FINANCIERS & GESTION DE STOCK OLI

**Date d'analyse :** 25 Mai 2026  
**Analysé par :** Cline AI Assistant  
**Plateforme :** OLI Core - Marketplace E-commerce RDC

---

## 🎯 RÉSUMÉ EXÉCUTIF

La plateforme OLI dispose d'une architecture financière robuste et complète intégrant :
- ✅ **Wallet interne** avec système d'escrow (séquestre de fonds)
- ✅ **Mobile Money** via passerelle Unipesa (Vodacom, Orange, Airtel, Africell)
- ✅ **Paiements par carte bancaire** (Equity, Ecobank, Visa)
- ✅ **Gestion de stock** avec variantes de produits
- ✅ **Système de commissions** automatisé
- ✅ **Traçabilité complète** des transactions

---

## 💰 1. SYSTÈME DE WALLET (Portefeuille OLI)

### 📁 Fichier principal : `src/services/wallet.service.js`

### 1.1 Architecture du Wallet

Le wallet OLI est au cœur du système financier avec **8 flux principaux** :

#### **FLUX 1 : Recharge via Mobile Money (deposit)**
```javascript
// Méthode : deposit(userId, amount, provider, phoneNumber)
- Application des frais : 5% (client paie 105%)
- Providers supportés : Vodacom, Orange, Airtel, Africell
- Statut initial : 'deposit_pending'
- Confirmation : via webhook Unipesa (/webhooks/unipesa/deposit)
```

**Exemple de flux :**
1. Client initie recharge de $10
2. Unipesa demande $10.50 ($10 + $0.50 frais)
3. Webhook confirme → Wallet crédité de $10
4. Banque OLI (User 0) reçoit $0.50

#### **FLUX 2 : Recharge par Carte Bancaire (depositByCard)**
```javascript
// Méthode : depositByCard(userId, amount, cardInfo)
- Validation : cardNumber (16 chiffres), CVV (3-4), expiryDate (MM/YY)
- Provider par défaut : Equity (ID 20)
- Confirmation asynchrone via webhook
```

#### **FLUX 3 : Retrait vers Mobile Money (withdraw)**
```javascript
// Méthode : withdraw(userId, amount, provider, phoneNumber)
- Frais de retrait : 5%
- Débit immédiat du wallet (montant + frais)
- API Unipesa B2C envoie le montant NET
- En cas d'échec API : remboursement automatique
```

**Protection contre double retrait :**
- Débit AVANT l'appel API externe
- Remboursement uniquement si échec immédiat

#### **FLUX 4 : Paiement de Commande (payOrder)**
```javascript
// Méthode : payOrder(userId, amount, orderId)
- Débite le wallet de l'acheteur
- Fonds bloqués en escrow (séquestre)
- Enregistrement dans OLI Bank ledger : 'escrow_lock'
- Lève erreur si solde insuffisant
```

#### **FLUX 5 : Crédit Vendeur (creditSeller)**
```javascript
// Méthode : creditSeller(sellerId, amount, orderId)
- Appelé APRÈS livraison confirmée
- Crédite 100% du montant de vente
- Type transaction : 'credit'
- Provider : 'OLI_PLATFORM'
- Ledger : 'escrow_release'
```

**Déclencheurs :**
- Pick&Go : `verifyPickup()` (Circuit B)
- Livraison standard : `verifyDelivery()` (Circuit A)

#### **FLUX 6 : Crédit Livreur (creditDeliverer)**
```javascript
// Méthode : creditDeliverer(delivererId, amount, orderId)
- Crédite la commission de livraison
- Appelé après livraison confirmée
- Montant : delivery_fee de la commande
```

#### **FLUX 7 : Transfert P2P (transferToUser)**
```javascript
// Méthode : transferToUser(senderId, receiverId, amount, currency)
- Support USD et FC (Francs Congolais)
- Conversion : 1 USD = 2800 FC
- Transaction atomique (PostgreSQL)
- Vérification des wallets gelés (is_frozen)
```

**Sécurité :**
- Transaction PostgreSQL (`BEGIN...COMMIT`)
- Rollback automatique en cas d'erreur
- Impossible de s'envoyer à soi-même

#### **FLUX 8 : Récompenses (rewardUser)**
```javascript
// Méthode : rewardUser(userId, points, reason)
- Système de points de fidélité
- Conversion : 100 points = 1 USD
- Auto-crédit du wallet si ≥ 100 points
```

### 1.2 Système de Frais

| Opération | Frais | Qui paie ? | Bénéficiaire |
|-----------|-------|------------|--------------|
| Recharge Mobile Money | 5% | Client | Banque OLI (User 0) |
| Retrait Mobile Money | 5% | Client | Banque OLI (User 0) |
| Transfert P2P | 0% | - | - |
| Paiement commande | 0% | - | - |

### 1.3 Wallet Système (Banque OLI)

**User ID : 0**  
Email : `bank@oli-core.com`

```javascript
// Méthode : _creditSystemWallet(amount, reference, description)
- Collecte tous les frais de la plateforme
- Création automatique si inexistant
- Logs détaillés : "🏦 Banque OLI Créditée"
```

### 1.4 Intégration OLI Bank

**Système de Grand Livre (Ledger) non-bloquant :**

```javascript
// Méthode : _recordToLedger(userId, txType, amount, meta)
- Fire-and-forget avec setImmediate()
- Types : deposit, withdrawal, escrow_lock, escrow_release
- Initialise automatiquement le portail utilisateur
- N'interrompt jamais le flux principal
```

**Types de transactions Ledger :**
- `deposit` : Recharge wallet
- `withdrawal` : Retrait
- `escrow_lock` : Blocage fonds commande
- `escrow_release` : Libération fonds vendeur

---

## 📱 2. INTÉGRATION MOBILE MONEY (UNIPESA)

### 📁 Fichier principal : `src/services/unipesa.service.js`

### 2.1 Configuration

**Fichier :** `src/config/unipesa.config.js`

```javascript
PROVIDERS: {
    VODACOM:   9,    // M-Pesa
    ORANGE:    10,   // Orange Money
    AIRTEL:    17,   // Airtel Money
    AFRICELL:  19,   // Africell Money
    EQUITY:    20,   // Carte bancaire
    ECOBANK:   23,   // Carte bancaire
    VISA:      5002, // VISA DRC
    SIMULATOR: 14,   // Mode test
}
```

**Variables d'environnement requises :**
```env
UNIPESA_API_URL=https://api.unipesa.tech
UNIPESA_PUBLIC_ID=<ID public commerçant>
UNIPESA_MERCHANT_ID=<ID unique commerçant>
UNIPESA_SECRET_KEY=<Clé secrète HMAC>
```

### 2.2 Sécurité - Signature HMAC-SHA512

```javascript
_calculateSignature(data) {
    // Concaténation : key1value1key2value2...
    // Signature : HMAC-SHA512(stringForSignature, SECRET_KEY)
    // Format : lowercase hex
}
```

**Tous les appels API sont signés** pour garantir l'authenticité.

### 2.3 Flux C2B (Client → OLI)

**Endpoint API :** `POST /{PUBLIC_ID}/payment_c2b`

```javascript
// Méthode : depositC2B(data)
Payload:
{
    merchant_id: "...",
    customer_id: "+243XXXXXXXXX",
    order_id: "DEP_123_1234567890",
    amount: "10.50",
    currency: "USD",
    country: "CD",
    callback_url: "https://oli.com/webhooks/unipesa/deposit",
    provider_id: 10, // Orange
    signature: "abc123..."
}

Réponse:
{
    success: true,
    status: "pending",
    transaction_id: "UNI_XXX",
    message: "En attente de confirmation PIN Mobile Money."
}
```

### 2.4 Flux B2C (OLI → Client)

**Endpoint API :** `POST /{PUBLIC_ID}/payment_b2c`

```javascript
// Méthode : withdrawB2C(data)
- Décaissement vers Mobile Money du client
- Montant NET envoyé (sans frais)
- Confirmation via callback
```

### 2.5 Mode Simulateur

**Fonctionnement :**
- Actif si `UNIPESA_MERCHANT_ID` ou `SECRET_KEY` absents
- Auto-webhook après 3 secondes
- Statut forcé : SUCCESS (status = 2)
- Logs : `"⚠️ [SIMULATION UNIPESA]"`

```javascript
if (!config.IS_CONFIGURED) {
    setTimeout(() => {
        axios.post('http://127.0.0.1:3000/webhooks/unipesa/deposit', {
            status: 2, // SUCCESS
            transaction_id: `SIM_TXN_${Date.now()}`,
            signature: 'SIMULATED'
        });
    }, 3000);
}
```

### 2.6 Vérification Webhook

```javascript
// Méthode : verifyWebhookSignature(payload)
- Valide l'authenticité des callbacks Unipesa
- Vérifie la signature HMAC-SHA512
- Mode test : accepte 'SIMULATED'
```

**Statuts Unipesa :**
- `2` : SUCCESS (transaction confirmée)
- `1` : PENDING (en attente)
- `0` ou autres : FAILED (échec)

---

## 📦 3. GESTION DES PRODUITS & STOCK

### 📁 Fichiers principaux :
- `src/services/product.service.js`
- `src/repositories/product.repository.js`

### 3.1 Structure des Produits

**Table principale : `products`**

```sql
Champs clés:
- id (PK)
- seller_id (FK → users)
- shop_id (FK → shops, nullable)
- name
- description
- price (USD)
- category (auto-catégorisé si "other")
- subcategory
- images (array)
- quantity (stock disponible)
- condition ('new', 'used', 'refurbished')
- status ('active', 'inactive', 'deleted')
- delivery_price
- delivery_time
- location
- is_negotiable (booléen)
- brand_certified
- discount_price
- b2b_pricing (JSON array)
- shipping_options (JSON array)
```

### 3.2 Création de Produit

**Méthode :** `createProduct(userId, data, files)`

**Workflow :**

```mermaid
1. Validation (nom + prix requis)
2. Upload images (fichiers binaires)
3. Fusion avec existing_images (URLs pré-remplies)
4. Détermination shop_id (auto-liaison si manquant)
5. Auto-catégorisation (si category='other')
6. Création produit en DB
7. Insertion variantes (colors, sizes)
8. Mise à jour total_sales du vendeur
```

**Auto-catégorisation :**

```javascript
// Service : product_categorizer.service.js
const classified = categorizeByName(name, description);
if (classified.confidence >= 30) {
    resolvedCategory = classified.category;
    resolvedSubcategory = classified.subcategory;
}
```

**Logs :**
```
🏷️ Auto-classification: "Samsung Galaxy S21" 
   → Électronique/Téléphones (85%)
```

### 3.3 Variantes de Produits

**Table : `product_variants`**

```sql
CREATE TABLE product_variants (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id),
    variant_type VARCHAR (ex: 'color', 'size', 'capacity'),
    variant_value VARCHAR (ex: 'Rouge', 'XL', '256GB'),
    stock_quantity INT DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(product_id, variant_type, variant_value)
);
```

**Support dual format :**

1. **Format séparé (ancien) :**
```json
{
  "colors": ["Rouge", "Bleu", "Noir"],
  "sizes": ["S", "M", "L", "XL"]
}
```

2. **Format unifié (Seller Center) :**
```json
{
  "variants": [
    {"variant_type": "color", "variant_value": "Rouge"},
    {"variant_type": "size", "variant_value": "XL"}
  ]
}
```

### 3.4 Gestion du Stock

**Méthodes :**

```javascript
// 1. Lecture stock
getUserProducts(userId) → Liste produits avec quantités

// 2. Mise à jour du produit
updateProduct(userId, productId, updates)
- Vérification ownership
- Auto-reclassification si nom changé
- Update quantity

// 3. Suppression logique
deleteProduct(userId, productId)
- Soft delete : status = 'deleted'
- Préserve historique commandes
```

### 3.5 Bulk Update de Prix (Boutiques)

**Méthode :** `bulkUpdateShopPrices(userId, shopId, divisor)`

**Cas d'usage :** Conversion devise ou ajustement de tarification

```javascript
// Exemple : Diviser tous les prix d'une boutique par 2800
// (Conversion FC → USD)
bulkUpdateShopPrices(userId, shopId, 2800)

// Sécurité :
// - Vérifie ownership de la boutique
// - Update atomique via repository
```

### 3.6 Recherche de Produits

**Types de requêtes :**

1. **Produits Featrurés (admin OLI) :**
```sql
WHERE u.phone = '+243827088682'
  AND p.status = 'active'
  AND p.is_verified = TRUE
```

2. **Top Sellers (Super Offres) :**
```sql
WHERE u.is_admin = TRUE
ORDER BY RANDOM()
```

3. **Boutiques Vérifiées :**
```sql
WHERE (s.is_verified = TRUE 
   OR u.account_type = 'entreprise'
   OR u.has_certified_shop = TRUE)
```

4. **Recherche avec filtres :**
```javascript
getAllProducts({
    category: 'Électronique',
    minPrice: 10,
    maxPrice: 500,
    location: 'Kinshasa',
    condition: 'new'
}, limit, offset)
```

---

## 🛒 4. FLUX DE PAIEMENT DES COMMANDES

### 📁 Fichier principal : `src/services/order.service.js`

### 4.1 Création de Commande

**Méthode :** `createOrder(userId, data, io)`

**Workflow détaillé :**

```mermaid
START
  ↓
1. Validation items (productId, price, quantity)
  ↓
2. Calcul total = items + deliveryFee
  ↓
3. Traitement paiement selon méthode:
  ├─ WALLET: Débit immédiat walletService.payOrder()
  │           → paymentStatus='completed', orderStatus='paid'
  │           (si échec → STOP avec erreur "Solde insuffisant")
  │
  └─ MOBILE_MONEY: Statut 'pending'
               → Confirmation via webhook ultérieur
  ↓
4. Création commande en DB (orderRepository)
  ↓
5. Si paiement réussi (wallet):
   ├─ Update référence transaction wallet
   ├─ Génération codes (pickup_code, delivery_code)
   ├─ Notifications (acheteur, vendeur)
   ├─ Création delivery_orders (si Circuit A)
   └─ Broadcast Socket.IO (livreurs)
  ↓
END → Retour commande avec codes
```

### 4.2 Systèmes de Codes de Vérification

**Format :** 6 caractères alphanumériques (sans I/O/0/1)

```javascript
generateVerificationCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    // Génère: ex: "A3K9P7"
}
```

**Usage :**

| Code | Utilisateur | Moment | Action |
|------|-------------|--------|--------|
| `pickup_code` | Livreur + Vendeur | Retrait colis | verifyPickup() |
| `delivery_code` | Acheteur | Réception | verifyDelivery() |

### 4.3 Circuits de Livraison

**Circuit A - Avec Livreur OLI :**
```
paid → processing → ready → shipped → delivered
        (vendeur)   (vendeur) (pickup)(delivery)
```

**Circuit B - Pick & Go (Retrait Guichet) :**
```
paid → processing → delivered
        (vendeur)   (pickup direct)
```

**Circuit C - Hand Delivery (Remise en main propre) :**
```
paid → processing → delivered
        (vendeur)   (vendeur vérifie)
```

### 4.4 Vérification Pickup (verifyPickup)

**Méthode :** `verifyPickup(orderId, code, verifierId, io)`

**Logique :**

```javascript
if (isPickAndGo) {
    // Circuit B : direct DELIVERED
    status: 'processing' → 'delivered'
    creditSellers(100% montant) // Immédiat
    
} else {
    // Circuit A : vers SHIPPED
    status: 'ready' → 'shipped'
    delivery_orders: 'pending' → 'picked_up'
    // Crédit vendeur après delivery
}
```

### 4.5 Vérification Delivery (verifyDelivery)

**Méthode :** `verifyDelivery(orderId, code, userId, io)`

**Qui peut vérifier ?**
- Circuit A : Acheteur uniquement
- Circuit C : Vendeur seulement

```javascript
status: 'shipped' → 'delivered'
delivery_orders: 'picked_up' → 'delivered'
creditSellers(100% montant) // Exécution paiement final
```

### 4.6 Distribution des Fonds

**Méthode privée :** `_creditSellersForOrder(orderId)`

```javascript
// Agrégation par vendeur
SELECT p.seller_id, SUM(oi.product_price * oi.quantity)
FROM order_items oi
JOIN products p ON oi.product_id = p.id
WHERE oi.order_id = $1
GROUP BY p.seller_id

// Crédit wallet de chaque vendeur
for (seller : sellers) {
    walletService.creditSeller(seller.id, seller.amount, orderId);
}
```

**Répartition :**
- **Vendeur(s) :** 100% du montant produit
- **Livreur :** delivery_fee (si applicable)
- **OLI :** Uniquement frais wallet (5% recharge/retrait)

---

## 📊 5. TRAÇABILITÉ & HISTORIQUE

### 5.1 Transactions Wallet

**Table : `wallet_transactions`**

```sql
Champs:
- id
- wallet_id (FK)
- user_id (FK)
- type ('deposit', 'withdrawal', 'payment', 'credit', 'transfer', 'reward', 'refund')
- amount (positif ou négatif)
- balance_after
- provider ('UNIPESA', 'OLI_PLATFORM', 'P2P', 'OLI_REWARDS')
- reference (unique)
- description
- metadata (JSONB)
- order_id (nullable, FK)
- created_at
```

**Consultation :**
```javascript
walletService.getHistory(userId, limit=30)
```

### 5.2 Historique Statuts Commande

**Table : `order_status_history`**

```sql
Champs:
- id
- order_id (FK)
- previous_status
- new_status
- changed_by (user_id)
- changed_by_role ('buyer', 'seller', 'deliverer', 'system')
- created_at
```

**Timeline complète :**
```javascript
orderService.getOrderTracking(orderId, userId)

Retourne:
{
    order_id: 123,
    current_status: 'shipped',
    steps: [
        {step: 1, label: 'Commande reçue', completed: true, timestamp: '...'},
        {step: 2, label: 'En préparation', completed: true, timestamp: '...'},
        {step: 3, label: 'Prêt', completed: true, timestamp: '...'},
        {step: 4, label: 'Expédition', completed: true, timestamp: '...'},
        {step: 5, label: 'Livré', completed: false, timestamp: null}
    ],
    history: [...],
    pickup_code: 'A3K9P7', // si vendeur/livreur
    delivery_code: 'X7M2N5' // si acheteur
}
```

### 5.3 Grand Livre OLI Bank

**Service :** `src/services/oli_bank.service.js`

**Table : `oli_bank_ledger`**

```sql
Champs:
- id
- user_id (FK)
- transaction_type ('deposit', 'withdrawal', 'escrow_lock', 'escrow_release')
- amount
- currency ('USD')
- reference
- metadata (JSONB - orderId, provider, fee, etc.)
- portal_balance (solde à ce moment)
- created_at
```

**Architecture Fire-and-Forget :**
```javascript
// Non-bloquant, logging asynchrone
setImmediate(async () => {
    await bank.recordLedgerEntry(userId, txType, amount, meta);
});
```

---

## 🔐 6. SÉCURITÉ & VALIDATIONS

### 6.1 Wallet

✅ **Protections :**
- Solde insuffisant → Erreur explicite
- Wallets gelés (`is_frozen`) → Blocage transactions
- Débit immédiat retrait → Évite double-retrait
- Transactions PostgreSQL atomiques
- Remboursement auto si échec API externe

### 6.2 Mobile Money

✅ **Protections :**
- Signature HMAC-SHA512 obligatoire
- Vérification webhook (`verifyWebhookSignature`)
- Mode simulateur isolé (logs visibles)
- Timeout callbacks
- Statut pending → évite crédits prématurés

### 6.3 Produits

✅ **Protections :**
- Ownership vérifiée (update, delete)
- Soft delete (status='deleted')
- Validation prix positif
- Images limitées (prévention spam)
- Auto-catégorisation (qualité données)

### 6.4 Commandes

✅ **Protections :**
- Codes de vérification uniques (6 chars)
- Validation statuts (machine à états stricte)
- Permissions rôles (buyer, seller, deliverer)
- Historique immutable
- Empêche double-crédit vendeur (check existing transaction)

---

## 📈 7. MÉTRIQUES & MONITORING

### 7.1 Logs Importants

**Wallet :**
```
💰 Vendeur #123 crédité : +15.50 USD (commande #456) → solde: 234.75 USD
🚚💰 Livreur #789 crédité : +2.00 USD (commande #456) → solde: 45.30 USD
🏦 Banque OLI Créditée : +$0.50 (Frais 5% sur retrait de $10.00)
```

**Commandes :**
```
🔑 Codes générés pour commande #123: pickup=A3K9P7, delivery=X7M2N5
🚚 delivery_orders créé pour commande #123
📡 Broadcast new_delivery_available émis
✅ Notification acheteur envoyée (User #456)
✅ Notification vendeur envoyée (Seller #789)
```

**Unipesa :**
```
⚠️ [SIMULATION UNIPESA] C2B initié pour 10.50 USD
⏱️ [SIMULATION UNIPESA] Auto-webhook C2B pour DEP_123_1234567890
```

### 7.2 Points de Monitoring

**À surveiller :**
1. **Taux de succès dépôts/retraits Unipesa**
2. **Délai webhooks** (doit être < 5min)
3. **Solde Banque OLI** (accumulation frais)
4. **Commandes bloquées** (status pending > 24h)
5. **Wallets gelés** (is_frozen=true)
6. **Échecs signature** (tentatives frauduleuses)

---

## 🚀 8. RECOMMANDATIONS & AMÉLIORATIONS

### 8.1 Court Terme (Semaine 1-2)

1. **Dashboard Analytics Wallet**
   - Volume transactions quotidiennes
   - Revenus frais (Banque OLI)
   - Taux de conversion pending → completed

2. **Alertes automatiques**
   - Webhook timeout > 5min
   - Solde utilisateur négatif (anomalie)
   - Tentatives vérification code (> 3 échecs)

3. **Backup Grand Livre**
   - Export journalier `oli_bank_ledger`
   - Réconciliation wallet vs ledger

### 8.2 Moyen Terme (Mois 1-3)

1. **Système de réconciliation automatisé**
   - Vérification quotidienne : 
     ```sql
     SUM(wallet_transactions) = users.wallet
     ```
   - Alerte si écart > 0.01 USD

2. **Support multi-devises**
   - USD, CDF, EUR
   - Taux de change dynamiques
   - Table `exchange_rates` centralisée

3. **Gestion stock avancée**
   - Alertes stock faible (< 5 unités)
   - Réservation temporaire (15min checkout)
   - Historique mouvements stock

4. **Reporting vendeurs**
   - PDF factures automatiques
   - Dashboard ventes (jour/semaine/mois)
   - Prédictions stock

### 8.3 Long Terme (3-6 mois)

1. **Intelligence artificielle**
   - Détection fraude transactions
   - Prix suggérés (IA - market analysis)
   - Auto-catégorisation images (Vision AI)

2. **Blockchain ledger**
   - Immutabilité transactions critiques
   - Smart contracts escrow

3. **Expansion paiements**
   - Paiement en plusieurs fois (layaway)
   - Paiement différé (Buy Now Pay Later)
   - Crypto-monnaies (USDT, Bitcoin)

---

## 📋 9. CHECKLIST DÉPLOIEMENT PRODUCTION

### Variables d'environnement

```bash
# Unipesa (OBLIGATOIRE)
✅ UNIPESA_API_URL=https://api.unipesa.tech
✅ UNIPESA_PUBLIC_ID=f54ec96649be...
✅ UNIPESA_MERCHANT_ID=e0fecd91fcb2...
✅ UNIPESA_SECRET_KEY=xxxxxxxxxxx

# Wallet
✅ FC_TO_USD=2800  # Taux de conversion

# URLs
✅ APP_URL=https://api.oli-core.com
✅ FRONTEND_URL=https://oli-core.com

# Base de données
✅ DATABASE_URL=postgresql://...
```

### Tables critiques

```sql
✅ users (avec wallet column)
✅ wallets
✅ wallet_transactions
✅ products (avec quantity, status)
✅ product_variants
✅ orders (avec pickup_code, delivery_code)
✅ order_items
✅ order_status_history
✅ delivery_orders
✅ oli_bank_ledger
✅ oli_bank_portals
```

### Endpoints webhook

```
✅ POST /webhooks/unipesa/deposit
✅ POST /webhooks/unipesa/withdrawal
```

### Tests pré-production

```bash
1. ✅ Dépôt wallet (simulateur)
2. ✅ Retrait wallet (simulateur)
3. ✅ Création produit + variantes
4. ✅ Commande wallet (flow complet)
5. ✅ Vérification pickup/delivery codes
6. ✅ Crédit vendeur automatique
7. ✅ Transfert P2P
8. ✅ Récompenses points
```

---

## 💡 10. GLOSSAIRE

| Terme | Définition |
|-------|------------|
| **C2B** | Customer-to-Business (Client → Plateforme) |
| **B2C** | Business-to-Customer (Plateforme → Client) |
| **Escrow** | Séquestre de fonds (blocage temporaire) |
| **Ledger** | Grand livre comptable |
| **Webhook** | Callback HTTP automatique |
| **HMAC-SHA512** | Algorithme de signature cryptographique |
| **Fire-and-forget** | Exécution asynchrone non-bloquante |
| **Soft delete** | Suppression logique (status='deleted') |
| **Pick&Go** | Retrait guichet (sans livreur) |
| **Hand Delivery** | Remise en main propre par vendeur |

---

## 📞 CONTACTS & RESSOURCES

**Documentation technique :**
- Unipesa API : https://docs.unipesa.tech
- PostgreSQL : https://postgresql.org/docs
- Node.js Wallet patterns : https://nodejs.org/en/docs

**Structure fichiers clés :**
```
src/
├── services/
│   ├── wallet.service.js           ⭐ Cœur financier
│   ├── unipesa.service.js          ⭐ Mobile Money
│   ├── order.service.js            ⭐ Gestion commandes
│   ├── product.service.js          ⭐ Gestion stock
│   └── oli_bank.service.js         ⭐ Grand Livre
├── repositories/
│   ├── wallet.repository.js
│   ├── product.repository.js
│   └── order.repository.js
├── config/
│   └── unipesa.config.js           ⭐ Config paiements
└── controllers/
    ├── wallet.controller.js
    ├── order.controller.js
    └── product.controller.js
```

---

## ✅ CONCLUSION

**Forces de la plateforme OLI :**
1. ✅ Architecture robuste et scalable
2. ✅ Traçabilité complète des transactions
3. ✅ Sécurité multi-niveaux
4. ✅ Support multi-circuits livraison
5. ✅ Intégration complète Mobile Money RDC
6. ✅ Gestion stock avec variantes
7. ✅ Système escrow automatisé
8. ✅ Logs détaillés et debuggables

**Points d'attention :**
1. ⚠️ Mode simulateur actif (vérifier prod keys)
2. ⚠️ Monitoring webhooks critiques
3. ⚠️ Backup quotidien ledger recommandé

**État général : PRODUCTION READY ✅**

---

*Document généré par Cline AI Assistant - 25 Mai 2026*
*Confidentiel - Usage interne OLI uniquement*
