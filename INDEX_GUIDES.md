# 📚 DOCUMENTATION COMPLÈTE - oli-core (Mai 2026)

**Créée le**: 20 Mai 2026  
**Pour**: Démarrage après redémarrage Ubuntu + Configuration IA Import

---

## 📑 FICHIERS CRÉÉS

### 🎯 Guides Complets

| Fichier | Objectif | Durée | Publique |
|---------|----------|-------|----------|
| **GUIDE_STARTUP_UBUNTU.md** | Guide complet 6 phases après redémarrage | 15-20 min | ✅ Oui |
| **QUICK_COMMANDS.md** | Commandes essentielles + troubleshooting | 3 min | ✅ Oui |
| **ARCHITECTURE_DEPLOYMENT.md** | Diagrammes architecture + flux data | Référence | ✅ Oui |
| **.env.example** | Template variables d'environnement | Référence | ✅ Oui |

### 🚀 Scripts d'Automatisation

| Fichier | Objectif | Localisation |
|---------|----------|--------------|
| **startup.sh** | Vérification complète + démarrage backend | `/oli-core/` |
| **oli_seller/dev.sh** | Démarrage rapide oli_seller dev | `/oli_seller/` |

### 🔐 Configuration Environnement

| Fichier | Contenu | Statut |
|---------|---------|--------|
| **.env.local** | Backend config (root) | ✅ Créé |
| **oli_seller/.env.local** | Frontend config + clé OpenRouter | ✅ Créé |
| **oli_admin/.env.local** | Admin frontend config | ✅ Créé |

### 🗄️ Migrations

| Fichier | Status | Action |
|---------|--------|--------|
| **fix_avatar_history_table.sql** | Existait déjà | ✅ Documenté dans guide |

---

## 🎯 DÉMARRAGE RAPIDE (30 sec)

```bash
# 1. Entrer WSL
wsl -d Ubuntu
cd ~/oli-core

# 2. Exécuter script de démarrage
bash startup.sh

# 3. Laisser le script s'exécuter (il va):
#    ✓ Vérifier Node.js, npm
#    ✓ Vérifier .env.local
#    ✓ Vérifier infrastructure (Render, Vercel, PostgreSQL)
#    ✓ Installer dépendances
#    ✓ Vérifier migrations DB
#    ✓ Proposer de démarrer backend

# 4. Accepter démarrage backend (y/n)
# → Backend lancé sur http://localhost:5000

# 5. Dans nouveau terminal (optionnel):
cd oli_seller
bash dev.sh
# → Frontend lancé sur http://localhost:5173
```

---

## 📖 GUIDES DÉTAILLÉS

### Pour Démarrage Complet (20 min)
👉 **GUIDE_STARTUP_UBUNTU.md**

- ✅ Phase 1: Vérifications initiales
- ✅ Phase 2: État infrastructure  
- ✅ Phase 3: Configuration locale
- ✅ Phase 4: Tester localement
- ✅ Phase 5: Migrations DB
- ✅ Phase 6: Tests d'intégration
- ✅ Troubleshooting complet

### Pour Commandes Rapides (3 min)
👉 **QUICK_COMMANDS.md**

- ✅ Démarrage rapide 3 min
- ✅ Commandes essentielles par service
- ✅ Vérifications rapides
- ✅ Logs & Debugging
- ✅ Troubleshooting express
- ✅ Checklist 30 sec

### Pour Architecture Globale
👉 **ARCHITECTURE_DEPLOYMENT.md**

- ✅ Diagramme flux complet
- ✅ Infrastructure cloud (Render + Vercel)
- ✅ Déploiement CI/CD
- ✅ Flux data (IA Import example)
- ✅ Monitoring & logs
- ✅ Sécurité architecture
- ✅ Checklist démarrage

---

## ✨ NOUVEAUTÉS CRÉÉES

### 1. **Fichiers .env.local** ✅

#### Backend (.env.local à la racine)
```env
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxx
DB_HOST=dpg-d5f5o9q4d50c73chl7ng-a.onrender.com
DB_USER=oli_db_user
DB_PASSWORD=***
DB_NAME=oli_db
... (autres configs)
```

#### Frontend (oli_seller/.env.local)
```env
VITE_OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxx
VITE_API_URL=https://oli-core.onrender.com
```

### 2. **Scripts d'Automatisation** ✅

#### startup.sh (backend)
- ✓ Vérifie Node/npm
- ✓ Vérifie .env.local
- ✓ Vérifie infrastructure (Render, Vercel, PostgreSQL)
- ✓ Installe dépendances
- ✓ Vérifie migrations
- ✓ Lance backend

#### oli_seller/dev.sh
- ✓ Vérifie .env.local
- ✓ Clé OpenRouter configurée
- ✓ Lance Vite dev server

### 3. **Templates Environnement** ✅

#### .env.example (racine)
- Documentation de toutes les variables
- Backend + Frontend
- Commentaires explicatifs

---

## 🔧 CONFIGURATION IA IMPORT - RÉSUMÉ

### Problème Identifié ❌
oli_seller cherchait `import.meta.env.VITE_OPENROUTER_API_KEY` → **FILE NOT FOUND**

### Solution Appliquée ✅
1. Créé `oli_seller/.env.local` avec clé OpenRouter
2. Configuré `VITE_OPENROUTER_API_KEY` correctly
3. Format Vite (préfixe `VITE_*`)
4. Documenté dans guides

### Vérification ✅
```bash
# Vérifier clé présente
grep VITE_OPENROUTER_API_KEY oli_seller/.env.local

# Tester l'import IA
# http://localhost:5173 → Products → Import IA
```

---

## 📊 CHECKLIST - QU'EST-CE QUI EST PRÊT?

### ✅ Configuration
- [x] .env.local Backend créé
- [x] oli_seller/.env.local créé
- [x] oli_admin/.env.local créé
- [x] Clés API configurées
- [x] .env.example documenté

### ✅ Documentation
- [x] Guide complet 6 phases
- [x] Quick reference commands
- [x] Architecture diagrams
- [x] Troubleshooting
- [x] Checklist démarrage

### ✅ Automatisation
- [x] startup.sh (backend)
- [x] oli_seller/dev.sh
- [x] Scripts de vérification

### ⏳ À FAIRE ENSUITE (Optional)
- [ ] Rendre scripts exécutables: `chmod +x *.sh`
- [ ] Tester scripts en local
- [ ] Créer guide pour oli_delivery (mobile)
- [ ] Ajouter GitHub Actions CI/CD
- [ ] Monitoring Sentry/Datadog

---

## 🚀 PROCHAINES ÉTAPES

### Immédiat (Après Redémarrage Ubuntu)

```bash
1. wsl -d Ubuntu
2. cd ~/oli-core
3. bash startup.sh
4. (Accepter "Démarrer backend?" → y)
5. ✓ Backend lancé
```

### Frontend (Optionnel, nouveau terminal)

```bash
cd oli_seller
npm run dev
# ✓ Frontend sur http://localhost:5173
```

### Tester IA Import

```bash
1. Aller http://localhost:5173
2. Menu → "Ajouter Produit" → "Importation IA"
3. Upload image(s) de produit
4. Cliquer "Analyser par IA"
5. ✓ Produits extraits automatiquement
```

---

## 📞 SUPPORT RAPIDE

### Backend pas de réponse?
👉 Voir **QUICK_COMMANDS.md** → "Backend crash"

### IA Import échoue?
👉 Voir **GUIDE_STARTUP_UBUNTU.md** → "Problème: IA Import échoue"

### Connection DB timeout?
👉 Voir **GUIDE_STARTUP_UBUNTU.md** → "Connection DB Timeout"

### Vercel apps blanches?
👉 Voir **GUIDE_STARTUP_UBUNTU.md** → "Vercel Apps N'affichent Rien"

---

## 📋 STRUCTURE FICHIERS CRÉÉS

```
oli-core/
├── GUIDE_STARTUP_UBUNTU.md      (← Guide complet 6 phases)
├── QUICK_COMMANDS.md             (← Commandes rapides)
├── ARCHITECTURE_DEPLOYMENT.md    (← Diagrammes)
├── .env.example                  (← Template variables)
├── .env.local                    (← ✅ CRÉÉ - Backend config)
├── startup.sh                    (← ✅ CRÉÉ - Script démarrage)
│
├── oli_seller/
│   ├── .env.local               (← ✅ CRÉÉ - Frontend config)
│   └── dev.sh                   (← ✅ CRÉÉ - Script dev)
│
├── oli_admin/
│   └── .env.local               (← ✅ CRÉÉ - Admin config)
│
└── fix_avatar_history_table.sql (← Existait - documenté)
```

---

## 🎓 APPRENDRE DAVANTAGE

### Concepts
- **WebSockets**: Voir ARCHITECTURE_DEPLOYMENT.md → Socket.io
- **JWT Auth**: Voir GUIDE_STARTUP_UBUNTU.md → Phase 6.2
- **IA Integration**: Voir ARCHITECTURE_DEPLOYMENT.md → Flux Data
- **Deployment**: Voir ARCHITECTURE_DEPLOYMENT.md → Déploiement CI/CD

### Liens Utiles
- Render Dashboard: https://dashboard.render.com
- Vercel Dashboard: https://vercel.com/dashboard
- OpenRouter API: https://openrouter.ai/
- PostgreSQL Docs: https://www.postgresql.org/docs/12/

---

## 📝 CHANGELOG

**20 Mai 2026 - Version 1.0**
- ✅ Créé GUIDE_STARTUP_UBUNTU.md (6 phases complètes)
- ✅ Créé QUICK_COMMANDS.md (commandes essentielles)
- ✅ Créé ARCHITECTURE_DEPLOYMENT.md (diagrammes)
- ✅ Créé .env.local files (3 fichiers)
- ✅ Créé startup.sh + dev.sh (scripts auto)
- ✅ Configuré clé OpenRouter (IA Import)
- ✅ Documenté fix_avatar_history_table.sql

**Durée totale setup**: ~30 min
**Fichiers créés**: 10
**Scripts**: 2
**Configurations**: 3

---

## 🎉 CONCLUSION

**Tous les guides sont prêts pour redémarrage Ubuntu!**

Pour démarrer immédiatement après reboot Ubuntu:
```bash
bash startup.sh
```

Pour consulter les guides:
- 📖 **GUIDE_STARTUP_UBUNTU.md** - Guide complet
- ⚡ **QUICK_COMMANDS.md** - Commandes rapides
- 🏗️ **ARCHITECTURE_DEPLOYMENT.md** - Référence technique

**Bon démarrage! 🚀**
