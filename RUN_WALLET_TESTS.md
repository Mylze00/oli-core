# 🧪 GUIDE D'EXÉCUTION DES TESTS WALLET

## Pré-requis

Le système de test va effectuer les opérations suivantes avec le numéro **+243827088682** :

✅ Connexion/Création de compte  
✅ Dépôt via Mobile Money (Simulateur Unipesa)  
✅ Vérification solde  
✅ Création commande + Paiement wallet  
✅ Retrait vers Mobile Money  
✅ Historique des transactions  

---

## 🚀 Méthode 1 : Exécution Rapide (Script combiné)

### Étape 1 : Démarrer le serveur

```bash
cd /home/paolice-mylze/oli-core
npm start
```

### Étape 2 : Dans un NOUVEAU terminal, exécuter les tests

```bash
cd /home/paolice-mylze/oli-core
node test_wallet_operations.js
```

---

## 🔧 Méthode 2 : Tests manuels via curl

Si vous préférez tester manuellement chaque opération :

### 1. Créer/Connexion compte

```bash
# Connexion (si compte existe)
curl -X POST http://localhost:5000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+243827088682",
    "password": "Test123!"
  }'

# OU Création compte (si nouveau)
curl -X POST http://localhost:5000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Utilisateur",
    "phone": "+243827088682",
    "email": "test@oli.com",
    "password": "Test123!"
  }'
```

**Récupérer le TOKEN de la réponse**

### 2. Vérifier solde

```bash
curl http://localhost:5000/wallet/balance \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

### 3. Dépôt Mobile Money

```bash
curl -X POST http://localhost:5000/wallet/deposit \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 50,
    "provider": "orange",
    "phoneNumber": "+243827088682"
  }'
```

**Attendre 3-4 secondes** (webhook simulateur)

### 4. Vérifier nouveau solde

```bash
curl http://localhost:5000/wallet/balance \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

### 5. Créer une commande (paiement wallet)

```bash
curl -X POST http://localhost:5000/orders \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "items": [
      {
        "productId": 1,
        "productName": "Produit Test",
        "price": 15,
        "quantity": 1,
        "sellerId": 1
      }
    ],
    "deliveryAddress": "Avenue Lukusa 123, Kinshasa",
    "deliveryFee": 2,
    "paymentMethod": "wallet",
    "deliveryMethodId": "oli_standard"
  }'
```

### 6. Retrait Mobile Money

```bash
curl -X POST http://localhost:5000/wallet/withdraw \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 10,
    "provider": "orange",
    "phoneNumber": "+243827088682"
  }'
```

**Attendre 3-4 secondes** (webhook simulateur)

### 7. Historique transactions

```bash
curl http://localhost:5000/wallet/history \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

---

## 📊 Que surveiller pendant les tests

### Logs du serveur

Le serveur affichera des logs détaillés :

```
💳 DÉPÔT initié...
⚠️ [SIMULATION UNIPESA] C2B initié pour 50 USD
⏱️ [SIMULATION UNIPESA] Auto-webhook C2B pour DEP_123_...
💰 Vendeur #123 crédité : +15.00 USD (commande #456)
🏦 Banque OLI Créditée : +$0.50 (Frais 5% sur retrait...)
🔑 Codes générés pour commande #123: pickup=A3K9P7, delivery=X7M2N5
```

### Base de données

Vérifier les tables après les tests :

```sql
-- Wallet de l'utilisateur
SELECT * FROM users WHERE phone = '+243827088682';

-- Transactions
SELECT * FROM wallet_transactions 
WHERE user_id = (SELECT id FROM users WHERE phone = '+243827088682')
ORDER BY created_at DESC
LIMIT 10;

-- Commandes
SELECT * FROM orders 
WHERE user_id = (SELECT id FROM users WHERE phone = '+243827088682')
ORDER BY created_at DESC;

-- Banque OLI (accumulation des frais)
SELECT * FROM users WHERE id = 0;
```

---

## ⚡ Script tout-en-un (Recommandé)

Créer un fichier `start_and_test.sh` :

```bash
#!/bin/bash

echo "🚀 Démarrage du serveur OLI..."
cd /home/paolice-mylze/oli-core

# Démarrer le serveur en arrière-plan
npm start &
SERVER_PID=$!

echo "⏳ Attente du démarrage du serveur (10 secondes)..."
sleep 10

# Vérifier que le serveur est up
if curl -s http://localhost:5000/health > /dev/null; then
    echo "✅ Serveur démarré avec succès !"
    
    echo ""
    echo "🧪 Lancement des tests wallet..."
    node test_wallet_operations.js
    
    TEST_EXIT=$?
    
    # Arrêter le serveur
    echo ""
    echo "🛑 Arrêt du serveur..."
    kill $SERVER_PID
    
    if [ $TEST_EXIT -eq 0 ]; then
        echo "✅ Tous les tests ont réussi !"
    else
        echo "❌ Certains tests ont échoué."
    fi
    
    exit $TEST_EXIT
else
    echo "❌ Le serveur n'a pas démarré correctement."
    kill $SERVER_PID 2>/dev/null
    exit 1
fi
```

Rendre exécutable et lancer :

```bash
chmod +x start_and_test.sh
./start_and_test.sh
```

---

## ❓ Dépannage

### Erreur : "Cannot connect to localhost:5000"
→ Le serveur n'est pas démarré. Lancer `npm start` dans un terminal séparé.

### Erreur : "Solde insuffisant"
→ Le dépôt n'a pas été confirmé. Attendre 3-4 secondes après l'appel à `/wallet/deposit`.

### Erreur : "Invalid token"
→ Le token JWT a expiré (15min par défaut). Se reconnecter.

### Erreur : "Phone number already exists"
→ Le compte existe déjà. Utiliser `/auth/login` au lieu de `/auth/register`.

### Le webhook ne se déclenche pas
→ Vérifier que `UNIPESA_MERCHANT_ID` est absent du `.env` (pour activer le mode simulateur).

---

## 📝 Résultats attendus

Après l'exécution complète, vous devriez voir :

✅ **Compte créé/connecté** : User ID affiché  
✅ **Solde initial** : Affiché (probablement $0.00)  
✅ **Dépôt réussi** : +$50.00  
✅ **Commande créée** : ID commande + codes pickup/delivery  
✅ **Solde débité** : -$17.00 (produit $15 + livraison $2)  
✅ **Retrait demandé** : -$10.50 ($10 + $0.50 frais)  
✅ **Historique complet** : Toutes les transactions listées  

**Solde final attendu** : ~$21.50 USD

---

## 🎯 Prochaines étapes après les tests

1. ✅ Analyser les logs du serveur
2. ✅ Vérifier les données en base
3. ✅ Tester le flow de livraison (verifyPickup, verifyDelivery)
4. ✅ Configurer les vraies clés Unipesa pour la production
5. ✅ Mettre en place le monitoring des webhooks

---

**Bon test ! 🚀**
