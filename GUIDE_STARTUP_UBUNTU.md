# 🚀 GUIDE DE DÉMARRAGE APRÈS REDÉMARRAGE UBUNTU

**Date**: Mai 2026  
**Architecture**: Vercel (Frontend) + Render (Backend) + PostgreSQL  
**Durée estimée**: 15-20 minutes

---

## 📋 TABLE DES MATIÈRES
1. [Phase 1: Vérifications Initiales](#phase-1--vérifications-initiales)
2. [Phase 2: Vérifier État Infrastructure](#phase-2--vérifier-état-infrastructure)
3. [Phase 3: Configuration Locale](#phase-3--configuration-locale)
4. [Phase 4: Tester Localement](#phase-4--tester-localement)
5. [Phase 5: Migrations DB](#phase-5--migrations-db)
6. [Phase 6: Tests d'Intégration](#phase-6--tests-dintégration)
7. [Troubleshooting](#troubleshooting)

---

## PHASE 1 – Vérifications Initiales

### ✅ Étape 1.1: Ubuntu est actif?

```powershell
# Depuis Windows (PowerShell)
wsl --list --verbose
```

**Résultat attendu**:
```
NAME      STATE           TYPE
Ubuntu    Running         Distribution
```

Si `STOPPED`, relancer:
```powershell
wsl -d Ubuntu
```

---

### ✅ Étape 1.2: WSL accès au projet

```bash
# Une fois dans Ubuntu
cd /home/paolice-mylze/oli-core
pwd
ls -la
```

**Résultat attendu**: Liste des fichiers du projet (package.json, migrations/, oli_seller/, etc.)

---

### ✅ Étape 1.3: Vérifier Node.js et npm

```bash
node --version     # Doit être 18+
npm --version      # Doit être 9+
```

**Si erreur "node not found"**:
```bash
# Installer Node.js
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 18
nvm use 18
```

---

### ✅ Étape 1.4: Vérifier Git

```bash
git status
git branch
```

**Résultat attendu**: Branche actuelle (probablement `main` ou `develop`)

---

## PHASE 2 – Vérifier État Infrastructure

### 🌐 Étape 2.1: Backend Render - Vérifier Status

#### Via Dashboard Render (simple)
```
1. Aller à https://dashboard.render.com
2. Se connecter avec tes identifiants
3. Cliquer sur "oli-core" ou "Backend Service"
4. Vérifier "Status: Live" (vert)
```

#### Via Terminal (expert)
```bash
# Test que le backend répond
curl -i https://oli-core.onrender.com/health

# Résultat attendu:
# HTTP/1.1 200 OK
# ou
# {"status":"ok"}
```

**Si le backend est DOWN** ❌:
```bash
# Redéployer manuellement depuis Render Dashboard
# Services > oli-core > Manual Deploy
```

---

### ✅ Étape 2.2: Base de Données PostgreSQL - Vérifier Connexion

```bash
# Depuis Ubuntu, vérifier que PostgreSQL est accessible
# (Render PostgreSQL accessible de partout via connexion TCP)

# Si tu as psql installé localement:
psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com \
     -U oli_db_user \
     -d oli_db \
     -c "SELECT 1"
```

**Résultat attendu**:
```
 ?column?
----------
        1
(1 row)
```

**Si psql pas installé**:
```bash
sudo apt-get update
sudo apt-get install -y postgresql-client
```

---

### 🎨 Étape 2.3: Vercel Apps - Vérifier Deployments

#### **oli_seller** (Dashboard Vendeurs)
```
1. Aller à https://vercel.com/dashboard
2. Cliquer sur "oli-seller"
3. Chercher l'onglet "Deployments"
4. Vérifier que le dernier déploiement est "Ready" (vert)
```

**URL en Production**:
```
https://oli-seller.vercel.app
```

#### **oli_admin** (Dashboard Admin)
```
1. Même procédure pour "oli-admin"
2. URL: https://oli-admin-smoky.vercel.app
```

---

### ✅ Étape 2.4: Résumé Status Infrastructure

**Créer un checklist**:
```bash
# Test tous les endpoints
echo "=== BACKEND RENDER ==="
curl -s https://oli-core.onrender.com/health | head -20

echo ""
echo "=== DATABASE ==="
echo "Tester manuellement depuis Dashboard Render"

echo ""
echo "=== VERCEL APPS ==="
curl -s https://oli-seller.vercel.app | head -20
curl -s https://oli-admin-smoky.vercel.app | head -20
```

---

## PHASE 3 – Configuration Locale

### 📝 Étape 3.1: Vérifier .env.local Files

```bash
# À la racine du projet
ls -la .env.local        # Backend config
cat .env.local | head -20

# Dans oli_seller/
ls -la oli_seller/.env.local
cat oli_seller/.env.local

# Dans oli_admin/
ls -la oli_admin/.env.local
```

**Résultat attendu**: Fichiers présents avec clés API ✅

**Si fichiers manquants**:
```bash
# Copier depuis .env.example
cp .env.example .env.local
cp oli_seller/.env.example oli_seller/.env.local
cp oli_admin/.env.example oli_admin/.env.local

# ⚠️ Puis ÉDITER et ajouter les vraies clés
nano .env.local
```

---

### ✅ Étape 3.2: Vérifier Clés API Critiques

```bash
# Vérifier que les 3 clés essentielles sont présentes:

echo "1. OpenRouter API:"
grep "OPENROUTER_API_KEY" .env.local

echo "2. Base de données:"
grep "DB_HOST\|DB_USER" .env.local

echo "3. Cloudinary:"
grep "CLOUDINARY_NAME" .env.local
```

**Si l'une manque** ❌:
```bash
# Éditer le fichier
nano .env.local

# Chercher la clé manquante et l'ajouter
# Exemple:
# OPENROUTER_API_KEY=sk-or-v1-YOUR_KEY
```

---

## PHASE 4 – Tester Localement

### 🔧 Étape 4.1: Installer Dépendances Backend

```bash
cd /home/paolice-mylze/oli-core

# Nettoyer ancien node_modules (recommandé)
rm -rf node_modules package-lock.json

# Installer les dépendances
npm install

# Vérifier pas d'erreurs
npm list | head -30
```

**Durée estimée**: 2-3 minutes

---

### 🚀 Étape 4.2: Démarrer le Backend Localement

```bash
# Terminal 1 - Backend
npm start
# ou avec dev mode (auto-reload)
npm run dev

# Résultat attendu:
# ✅ Server running on port 5000
# ✅ PostgreSQL connected
# ✅ Socket.io initialized
```

---

### ✅ Étape 4.3: Tester Endpoint Santé Backend

```bash
# Terminal 2 - Test API
curl -i http://localhost:5000/health

# Résultat attendu:
# HTTP/1.1 200 OK
# {"status":"ok"}
```

---

### 🎨 Étape 4.4: Démarrer oli_seller Localement (Optionnel)

```bash
# Terminal 3 - oli_seller dev
cd oli_seller
npm install
npm run dev

# Résultat attendu:
# ✅ Vite app running at http://localhost:5173
```

**Tester dans le navigateur**:
```
http://localhost:5173
```

---

## PHASE 5 – Migrations DB

### 📊 Étape 5.1: Vérifier État Tables

```bash
# Vérifier que la table user_avatar_history existe

psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com \
     -U oli_db_user \
     -d oli_db \
     -c "\dt user_avatar_history"

# Résultat attendu:
# Si TABLE EXISTE:
# List of relations
# Schema | Name                  | Type  | Owner
# public | user_avatar_history   | table | oli_db_user

# Si TABLE N'EXISTE PAS:
# Did not find any relation named "user_avatar_history".
```

---

### ✅ Étape 5.2: Exécuter Migration Avatar History

**SI la table N'existe pas**:

```bash
# Option 1: Depuis psql CLI
psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com \
     -U oli_db_user \
     -d oli_db \
     -f fix_avatar_history_table.sql

# Résultat attendu:
# CREATE TABLE
# CREATE INDEX
# COMMENT
# INSERT 0 (X avatars migrated)
# NOTICE: ✅ Table user_avatar_history créée avec succès!
```

**Option 2: Via pgAdmin (Web UI)**
```
1. Aller à https://render.com > Database Dashboard
2. Ouvrir pgAdmin
3. Copier contenu de fix_avatar_history_table.sql
4. Exécuter dans la console SQL
```

---

### 📝 Étape 5.3: Vérifier Migration Réussie

```bash
# Compter les avatars migrés
psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com \
     -U oli_db_user \
     -d oli_db \
     -c "SELECT COUNT(*) FROM user_avatar_history;"

# Résultat attendu:
# count
# -------
#   N (nombre d'avatars)
```

---

## PHASE 6 – Tests d'Intégration

### ✅ Étape 6.1: Test Connexion Frontend → Backend

```bash
# Dans oli_seller ou oli_admin (dev mode)
# Ouvrir Console Navigateur (F12)

# Essayer une requête simple:
fetch('http://localhost:5000/auth/me', {
  headers: {'Authorization': 'Bearer YOUR_TOKEN'}
})
.then(r => r.json())
.then(d => console.log(d))

# Résultat attendu (sans token):
# {"error":"Unauthorized"} ou
# {"error":"Token required"}
```

---

### 🔐 Étape 6.2: Test Authentification

```bash
# 1. Envoyer OTP
curl -X POST http://localhost:5000/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone":"+243123456789"}'

# Résultat attendu:
# {"success":true,"otp":"XXXX","expiresIn":300}

# 2. Vérifier OTP
curl -X POST http://localhost:5000/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"phone":"+243123456789","otp":"XXXX"}'

# Résultat attendu:
# {"token":"eyJhbGc...","user":{"id":1,"phone":"..."},...}
```

---

### 📱 Étape 6.3: Test Upload Image (IA Import)

```bash
# Via oli_seller UI:
1. Aller à "Ajouter Produit" → "Importation IA"
2. Sélectionner une image de produit
3. Cliquer "Analyser par IA"

# Vérifier dans Console Navigateur:
# Doit voir requête vers https://openrouter.ai/api/v1/chat/completions
# Status 200 OK
# Réponse contient JSON avec produits
```

---

### 🔥 Étape 6.4: Test Socket.io (Real-time)

```bash
# Depuis Terminal backend (logs)
npm run dev

# Depuis oli_seller UI:
1. Ouvrir 2 onglets de oli_seller
2. Envoyer un message d'un onglet à l'autre
3. Vérifier dans backend logs:
   ✅ [Socket.io] Client connected
   ✅ [Chat] Message sent
   ✅ Message received (autre client)
```

---

## Troubleshooting

### ❌ Problème: Backend Down (Render)

**Symptômes**:
- `curl https://oli-core.onrender.com` → Connection refused
- Dashboard Render → Status: Red/Crashed

**Solutions**:

```bash
# 1. Vérifier les logs Render
# Via Dashboard > Logs > View logs

# 2. Redéployer manuellement
# Dashboard > Services > oli-core > Manual Deploy > Deploy

# 3. Si toujours down, vérifier en local
cd /home/paolice-mylze/oli-core
npm install
npm start

# 4. Si local ✅ mais Render ❌
# → Problème de variables d'environnement
# → Aller Dashboard > Environment Variables
# → Vérifier que OPENROUTER_API_KEY, DB_*, etc. sont set
```

---

### ❌ Problème: Connection DB Timeout

**Symptômes**:
- Backend: `error: connect ECONNREFUSED`
- psql: `could not connect to server`

**Solutions**:

```bash
# 1. Vérifier que PostgreSQL Render est UP
# Dashboard > Databases > Status: Should be "Available"

# 2. Vérifier credentials dans .env.local
grep DB_ .env.local

# 3. Tester connexion directe
psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com \
     -U oli_db_user \
     -d oli_db

# 4. Si error "role does not exist"
# → Vérifier DB_USER exactement (case-sensitive)

# 5. Si "password authentication failed"
# → Réinitialiser mot de passe dans Dashboard Render
```

---

### ❌ Problème: IA Import Échoue

**Symptômes**:
- Erreur: "Clé API OpenRouter manquante"
- Ou: "401 Unauthorized"

**Solutions**:

```bash
# 1. Vérifier clé dans oli_seller/.env.local
cat oli_seller/.env.local | grep VITE_OPENROUTER

# 2. Format correct?
# ✅ sk-or-v1-155971db...
# ❌ sk-or-v1 (incomplet)
# ❌ Bearer sk-or-v1-... (n'ajoute PAS Bearer)

# 3. Clé valide? (Test OpenRouter API directement)
curl https://openrouter.ai/api/v1/models \
  -H "Authorization: Bearer sk-or-v1-YOUR_KEY"

# 4. Vérifier dans Dev Tools (F12)
# Network tab → Request vers openrouter
# Voir status et réponse erreur
```

---

### ❌ Problème: Vercel Apps N'affichent Rien

**Symptômes**:
- https://oli-seller.vercel.app → White screen
- Ou: 404 Not Found

**Solutions**:

```bash
# 1. Vérifier Vercel Deployments
# https://vercel.com/dashboard > oli-seller > Deployments
# Doit avoir "Ready" (vert) au moins

# 2. Si pas de déploiement récent
# → Redéployer depuis GitHub:
#    Vercel Dashboard > Deployments > Redeploy

# 3. Vérifier env vars sur Vercel
# Settings > Environment Variables
# Doit avoir: VITE_OPENROUTER_API_KEY, VITE_API_URL

# 4. Vérifier source sur GitHub
git log --oneline | head -5
# Si derniers commits ne sont pas pushés:
git push origin main
```

---

### ❌ Problème: Local Dev Mode Lent

**Symptômes**:
- `npm run dev` dans oli_seller → Prend 30+ sec
- Hot reload ne fonctionne pas

**Solutions**:

```bash
# 1. Vider cache Vite
cd oli_seller
rm -rf .vite node_modules/.vite

# 2. Relancer dev
npm run dev

# 3. Attendre 10-20 sec pour HMR

# 4. Si toujours lent, rebâtir
rm -rf node_modules package-lock.json
npm install
npm run dev
```

---

## 📋 Checklist Finale

```bash
# Copier et exécuter cette checklist à chaque startup:

echo "=== CHECKLIST DÉMARRAGE ==="

echo "✓ Ubuntu: WSL actif"
wsl --list --verbose

echo "✓ Node.js: Versions"
node --version && npm --version

echo "✓ Backend: Code à jour"
cd ~/oli-core && git status

echo "✓ Render: Backend live"
curl -s https://oli-core.onrender.com/health

echo "✓ PostgreSQL: Accessible"
psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com -U oli_db_user -d oli_db -c "SELECT 1"

echo "✓ Vercel: Apps déployées"
curl -I https://oli-seller.vercel.app | head -1
curl -I https://oli-admin-smoky.vercel.app | head -1

echo "✓ Env vars: Présentes"
grep OPENROUTER .env.local && echo "  OPENROUTER_API_KEY: ✓"
grep DB_HOST .env.local && echo "  DB_HOST: ✓"

echo "✓ Migrations: Applied"
psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com -U oli_db_user -d oli_db \
     -c "SELECT count(*) as avatar_history_count FROM user_avatar_history"

echo ""
echo "🎉 PRÊT À DÉMARRER!"
```

---

## 🚀 Quick Start (3 min)

```bash
# 1. Entrer WSL
wsl -d Ubuntu

# 2. Aller au projet
cd ~/oli-core

# 3. Vérifier status backend (5 sec)
curl -s https://oli-core.onrender.com/health

# 4. Démarrer backend local (en dev)
npm run dev

# (En parallèle, dans another terminal)

# 5. Démarrer oli_seller (optionnel)
cd oli_seller && npm run dev

# 6. Tester
# Browser: http://localhost:5173 (oli_seller)
# API: http://localhost:5000/health
```

---

## 📞 Support

**Si problème persiste**:
```bash
# 1. Récupérer logs détaillés
npm run dev 2>&1 | tee backend.log

# 2. Logs Render
# Dashboard > Services > oli-core > Logs

# 3. Logs Vercel
# Dashboard > Deployments > Logs

# 4. Commande debug
curl -v https://oli-core.onrender.com/health
```

---

**Dernière mise à jour**: Mai 2026
