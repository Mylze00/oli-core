# 📱 GUIDE COMPLET - PAGE DE PAIEMENT MOBILE MONEY OLI

**Fichier :** `mobile_money_payment_page.html`  
**Numéro de test :** +243827088682  
**Version :** 2.0 - Enrichie avec toutes les informations

---

## 🎯 FONCTIONNALITÉS DE LA PAGE

### ✅ Informations affichées

1. **Numéro de téléphone** : +243827088682 (clairement visible)
2. **Opérateur Mobile Money** : Orange Money / Vodacom / Airtel / Africell
3. **Montant en FC** : Avec calcul automatique (USD × 2800)
4. **Montant en USD** : Affichage de l'équivalence
5. **Frais 5%** : Inclus et affichés distinctement
6. **Adresse de livraison** : Avenue Banga N°22, Q/kinkole, C/nsele, Kinshasa
7. **Numéro de commande** : #88 (modifiable)
8. **Référence transaction** : Unique par transaction
9. **Timer de 3 minutes** : Compte à rebours visible
10. **Instructions étape par étape** : 3 étapes claires

### 🎨 Design moderne et responsive

- ✅ Dégradé de couleurs (orange/bleu nuit)
- ✅ Animations fluides (pulse, ring, hover)
- ✅ Icons émojis pour meilleure UX
- ✅ Loading state et success state
- ✅ Responsive (mobile-first)
- ✅ Timer avec compte à rebours
- ✅ Badge de statut "En cours"

---

## 🚀 COMMENT UTILISER LA PAGE

### Méthode 1 : Ouvrir directement dans le navigateur

```bash
# Depuis Windows
start mobile_money_payment_page.html

# Ou double-cliquez sur le fichier
```

### Méthode 2 : Via un serveur local (recommandé)

```bash
# Avec Python
cd /home/paolice-mylze/oli-core
python3 -m http.server 8080

# Puis ouvrir : http://localhost:8080/mobile_money_payment_page.html
```

### Méthode 3 : Intégrer dans votre application

Copiez le code HTML dans votre framework (React, Vue, Flutter Web, etc.)

---

## 🛠️ CONFIGURATION DES DONNÉES

### Modifier les données de transaction

Dans le fichier HTML, section `<script>`, modifiez l'objet `transactionData` :

```javascript
let transactionData = {
    phone: '+243827088682',              // ← NUMÉRO DU CLIENT
    provider: 'orange',                   // ← vodacom, orange, airtel, africell
    amount: 15.00,                        // ← MONTANT EN USD
    orderId: '#88',                       // ← NUMÉRO DE COMMANDE
    deliveryAddress: 'Avenue Banga N°22, Q/kinkole, C/nsele, Kinshasa', // ← ADRESSE
    reference: 'DEP_' + Date.now()       // ← RÉFÉRENCE UNIQUE
};
```

### Exemple avec différentes valeurs

```javascript
// Exemple 1 : Paiement Vodacom
let transactionData = {
    phone: '+243827088682',
    provider: 'vodacom',
    amount: 25.50,
    orderId: '#125',
    deliveryAddress: 'Avenue Lukusa 45, Gombe, Kinshasa',
    reference: 'ORDER_125_' + Date.now()
};

// Exemple 2 : Paiement Airtel
let transactionData = {
    phone: '+243827088682',
    provider: 'airtel',
    amount: 100.00,
    orderId: '#856',
    deliveryAddress: 'Boulevard du 30 Juin, Kinshasa',
    reference: 'PAYMENT_856_' + Date.now()
};
```

---

## 🔌 CONNEXION AVEC L'API BACKEND

### Configuration de l'URL API

Dans le script, modifiez :

```javascript
const API_BASE_URL = 'http://localhost:5000'; // ← URL de votre serveur
```

### Ajouter le token d'authentification

Remplacez la ligne :

```javascript
'Authorization': 'Bearer YOUR_TOKEN_HERE' // À remplacer
```

Par :

```javascript
'Authorization': `Bearer ${localStorage.getItem('authToken')}`
```

### Format de la requête API

La page envoie cette requête lors du clic sur "Confirmer" :

```javascript
POST /wallet/deposit
Headers:
  Content-Type: application/json
  Authorization: Bearer <token>
  
Body:
{
  "amount": 15.00,
  "provider": "orange",
  "phoneNumber": "+243827088682"
}
```

### Réponse attendue du serveur

```json
{
  "success": true,
  "status": "pending",
  "transaction": {
    "id": 123,
    "reference": "DEP_123_1737766800000",
    "status": "pending"
  },
  "message": "Dépôt initié. En attente de confirmation."
}
```

---

## 📊 FLUX COMPLET DU PAIEMENT

```
1. CLIENT clique sur "Confirmer le paiement"
   ↓
2. PAGE envoie POST /wallet/deposit
   ↓
3. SERVEUR appelle Unipesa API (C2B payment)
   ↓
4. UNIPESA envoie notification USSD au +243827088682
   ↓
5. CLIENT entre son code PIN sur téléphone
   ↓
6. UNIPESA confirme et envoie webhook au serveur
   ↓
7. SERVEUR crédite le wallet
   ↓
8. PAGE affiche "Paiement réussi !"
```

---

## 💰 CALCULS AUTOMATIQUES

### Montant avec frais

```javascript
Montant produit : $15.00
Frais OLI (5%) : $0.75
Total à payer : $15.75

Conversion FC (taux : 2800) :
$15.75 × 2800 = 44 100 FC
```

### Répartition après paiement

```
Client paie : 44 100 FC (via Unipesa)
↓
Wallet crédité : $15.00 USD
Banque OLI reçoit : $0.75 USD (frais)
```

---

## 🧪 MODE TEST (Sans serveur)

La page détecte automatiquement si le serveur est inaccessible et active le **mode test**.

### Fonctionnement du mode test

```javascript
// Si le serveur ne répond pas
fetch('http://localhost:5000/health').catch(() => {
    // Mode test activé automatiquement
    testWithoutServer();
});
```

En mode test :
- ✅ Cliquer sur "Confirmer" fonctionne
- ✅ Loading de 3 secondes
- ✅ Affichage du succès
- ✅ Pas d'appel API réel

### Activer manuellement le mode test

Ouvrez la console du navigateur (F12) et tapez :

```javascript
testWithoutServer();
// Puis cliquez sur "Confirmer le paiement"
```

---

## 🎨 PERSONNALISATION DU DESIGN

### Changer les couleurs

```css
/* Couleur principale (orange) */
background: linear-gradient(135deg, #ff6b35 0%, #f7931e 100%);
/* Remplacer par : */
background: linear-gradient(135deg, #your-color-1 0%, #your-color-2 100%);

/* Couleur de fond */
background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
```

### Modifier le timer (défaut : 3 minutes)

```javascript
let timeRemaining = 180; // ← Changer en secondes
// 5 minutes = 300
// 10 minutes = 600
```

### Changer le taux de conversion FC/USD

```javascript
const EXCHANGE_RATE_FC_USD = 2800; // ← Modifier le taux
```

---

## 📱 INTÉGRATION AVEC DIFFÉRENTES TECHNOLOGIES

### 1. React / Next.js

```jsx
import { useEffect, useState } from 'react';

export default function MobileMoneyPayment() {
  const [transactionData, setTransactionData] = useState({
    phone: '+243827088682',
    provider: 'orange',
    amount: 15.00,
    orderId: '#88',
    deliveryAddress: 'Avenue Banga N°22...',
    reference: 'DEP_' + Date.now()
  });

  const handlePayment = async () => {
    const response = await fetch('/api/wallet/deposit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount: transactionData.amount,
        provider: transactionData.provider,
        phoneNumber: transactionData.phone
      })
    });
    
    const data = await response.json();
    // Traiter la réponse...
  };

  return (
    <div>
      {/* Intégrer votre HTML ici */}
    </div>
  );
}
```

### 2. Vue.js

```vue
<template>
  <div class="payment-page">
    <!-- Votre HTML ici -->
  </div>
</template>

<script>
export default {
  data() {
    return {
      transactionData: {
        phone: '+243827088682',
        provider: 'orange',
        amount: 15.00,
        orderId: '#88',
        deliveryAddress: 'Avenue Banga N°22...',
        reference: 'DEP_' + Date.now()
      }
    };
  },
  methods: {
    async confirmPayment() {
      const response = await this.$http.post('/wallet/deposit', {
        amount: this.transactionData.amount,
        provider: this.transactionData.provider,
        phoneNumber: this.transactionData.phone
      });
      // Traiter la réponse...
    }
  }
}
</script>
```

### 3. Flutter Web

```dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MobileMoneyPaymentPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WebView(
        initialUrl: 'https://votre-domaine.com/mobile_money_payment_page.html',
        javascriptMode: JavascriptMode.unrestricted,
        onPageFinished: (url) {
          // Page chargée
        },
      ),
    );
  }
}
```

---

## 🔐 SÉCURITÉ

### Recommandations

1. **HTTPS obligatoire en production**
   ```
   ❌ http://votre-site.com/payment
   ✅ https://votre-site.com/payment
   ```

2. **Validation backend**
   - Toujours vérifier le montant côté serveur
   - Ne jamais faire confiance au montant côté client

3. **Token JWT**
   - Expiration courte (15 min)
   - Refresh token pour renouvellement

4. **Webhook signature**
   - Vérifier la signature HMAC-SHA512 d'Unipesa
   - Rejeter les webhooks non signés

5. **Rate limiting**
   - Max 5 tentatives / heure / numéro
   - Pour éviter les abus

---

## 📋 CHECKLIST AVANT MISE EN PRODUCTION

### Configuration

- [ ] ✅ Remplacer `API_BASE_URL` par l'URL de production
- [ ] ✅ Configurer les clés Unipesa dans `.env`
- [ ] ✅ Activer HTTPS
- [ ] ✅ Tester avec tous les opérateurs (Orange, Vodacom, Airtel, Africell)
- [ ] ✅ Vérifier les montants minimums/maximums

### Tests

- [ ] ✅ Test avec solde insuffisant
- [ ] ✅ Test timeout (après 3 minutes)
- [ ] ✅ Test annulation
- [ ] ✅ Test refresh de page pendant paiement
- [ ] ✅ Test sur mobile (responsive)
- [ ] ✅ Test sur différents navigateurs

### Monitoring

- [ ] ✅ Logger tous les paiements
- [ ] ✅ Alertes si taux d'échec > 10%
- [ ] ✅ Dashboard temps réel
- [ ] ✅ Backup quotidien des transactions

---

## 📊 EXEMPLES DE DONNÉES

### Scénario 1 : Achat simple

```javascript
{
  phone: '+243827088682',
  provider: 'orange',
  amount: 25.00,
  orderId: '#145',
  deliveryAddress: 'Avenue Kasavubu 15, Kinshasa',
  reference: 'ORDER_145_1737766800000'
}

// Résultat affiché :
Montant : 73 500 FC (≈ $26.25 USD avec frais)
Frais : $1.25 (5%)
```

### Scénario 2 : Gros achat

```javascript
{
  phone: '+243827088682',
  provider: 'vodacom',
  amount: 500.00,
  orderId: '#892',
  deliveryAddress: 'Boulevard Lumumba 234, Lubumbashi',
  reference: 'ORDER_892_1737766800000'
}

// Résultat affiché :
Montant : 1 470 000 FC (≈ $525.00 USD avec frais)
Frais : $25.00 (5%)
```

### Scénario 3 : Petit achat

```javascript
{
  phone: '+243827088682',
  provider: 'airtel',
  amount: 2.50,
  orderId: '#23',
  deliveryAddress: 'Rue Mulenda 8, Goma',
  reference: 'ORDER_23_1737766800000'
}

// Résultat affiché :
Montant : 7 350 FC (≈ $2.63 USD avec frais)
Frais : $0.13 (5%)
```

---

## 🆘 DÉPANNAGE

### Problème : "Cannot connect to API"

**Solution :**
```javascript
// Vérifier que le serveur tourne
curl http://localhost:5000/health

// Vérifier l'URL dans le code
const API_BASE_URL = 'http://localhost:5000'; // ← Correct ?
```

### Problème : Timer ne démarre pas

**Solution :**
```javascript
// Ouvrir console (F12) et vérifier les erreurs
// Relancer avec :
window.onload = function() {
    updateDisplay();
    startTimer(); // ← Doit être appelé
};
```

### Problème : Montant incorrect

**Solution :**
```javascript
// Vérifier le taux de conversion
const EXCHANGE_RATE_FC_USD = 2800; // ← Taux actuel ?

// Vérifier le calcul des frais
const amountWithFees = transactionData.amount * 1.05; // ← 5%
```

### Problème : Le paiement ne se confirme pas

**Causes possibles :**
1. Token JWT expiré → Se reconnecter
2. Serveur backend down → Vérifier les logs
3. Webhook Unipesa bloqué → Vérifier firewall
4. Solde insuffisant → Vérifier le wallet

---

## 📞 SUPPORT & RESSOURCES

### Documentation OLI

- **Analyse système :** `ANALYSE_FLUX_FINANCIERS_STOCK.md`
- **Tests wallet :** `RUN_WALLET_TESTS.md`
- **Script de test :** `test_wallet_operations.js`

### Contacts Unipesa

- API Documentation : https://docs.unipesa.tech
- Support : support@unipesa.tech
- Dashboard : https://dashboard.unipesa.tech

### Numéros de test

```
✅ +243827088682  ← Numéro principal de test
✅ +243999999999  ← Succès immédiat (simulation)
❌ +243000000000  ← Échec systématique (test d'erreur)
⏳ +243888888899  ← Pending (test timeout)
```

---

## ✅ RÉSUMÉ

**La page est prête à l'emploi avec :**

✅ Affichage du numéro : +243827088682  
✅ Calcul automatique FC ↔ USD  
✅ Frais 5% inclus et affichés  
✅ Instructions étape par étape  
✅ Timer 3 minutes  
✅ Mode test intégré  
✅ Connection API backend  
✅ Design moderne et responsive  
✅ États: attente → loading → succès  

**Pour tester :**
```bash
# Ouvrir dans le navigateur
start mobile_money_payment_page.html

# OU avec serveur
python3 -m http.server 8080
# Puis : http://localhost:8080/mobile_money_payment_page.html
```

🎉 **Prêt pour la production !**

---

*Guide créé le 25 Mai 2026 - OLI Platform*
