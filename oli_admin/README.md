# Oli Admin Dashboard 🛡️

Dashboard d'administration pour la plateforme Oli (Marketplace, Livraison, Wallet).

🔗 **URL Production** : [https://oli-admin-smoky.vercel.app](https://oli-admin-smoky.vercel.app)
🔗 **Backend** : `https://oli-core.onrender.com`

---

## 🚀 Fonctionnalités

### 1. Vue d'ensemble (Dashboard)
- **KPIs** : Utilisateurs totaux, ventes du jour, revenus.
- **Graphiques** :
  - Évolution du chiffre d'affaires (30 derniers jours).
  - Nouveaux utilisateurs par jour.

### 2. Gestion Utilisateurs
- Liste de tous les utilisateurs (Clients, Vendeurs, Livreurs).
- Recherche par nom/téléphone.
- **Actions** :
  - Promouvoir Admin / Vendeur / Livreur.
  - Suspendre un compte (Bannir).

### 3. Gestion Commandes
- Liste complète avec statuts colorés.
- **Détails** : Voir les produits achetés et l'adresse de livraison.
- **Actions** : Changer le statut (Payé -> Expédié -> Livré).

### 4. Gestion Produits
- Liste des produits de la marketplace.
- **Featured** : Mettre un produit en avant sur la page d'accueil (Toggle Switch).
- Bannir un produit illégal.

### 5. Système de Litiges
- Voir les signalements des utilisateurs.
- **Actions** :
  - Accepter (Remboursement).
  - Rejeter (Fermer sans suite).

---

## 🛠️ Stack Technique

- **Frontend** : React (Vite)
- **Styling** : Tailwind CSS + HeadlessUI
- **Charts** : Recharts
- **Icons** : Heroicons
- **HTTP** : Axios
- **Déploiement** : Vercel

---

## 💻 Développement Local

1. Aller dans le dossier :
```bash
cd oli-core/oli_admin
```

2. Installer les dépendances :
```bash
npm install
```

3. Lancer le serveur de dev :
```bash
npm run dev
```
Accès sur `http://localhost:5173`

---

## 📦 Déploiement

Le déploiement est géré par **Vercel**.
Pour mettre à jour le site en production après des modifications :

```bash
cd oli_admin
npm run build      # Vérifier qu'il n'y a pas d'erreur
npx vercel --prod  # Déployer sur l'URL principale
```

---

## 🔐 Sécurité

- L'accès requiert un compte avec le flag `is_admin = true` dans la base de données.
- Authentification par OTP (numéro de téléphone).
- Token JWT stocké en LocalStorage.
- Redirection automatique vers `/login` si token expiré.
