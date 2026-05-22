# 🚀 QUICK REFERENCE - Commandes Essentielles

## DÉMARRAGE RAPIDE (3 min)

### Étape 1: Entrer WSL Ubuntu
```bash
wsl -d Ubuntu
cd ~/oli-core
```

### Étape 2: Vérifier Status Infrastructure
```bash
# ✓ Backend Live?
curl https://oli-core.onrender.com/health

# ✓ Apps Vercel?
curl -I https://oli-seller.vercel.app
```

### Étape 3: Démarrer Backend (Terminal 1)
```bash
npm run dev
# ✓ Server running on http://localhost:5000
```

### Étape 4: Démarrer oli_seller (Terminal 2, optionnel)
```bash
cd oli_seller
npm run dev
# ✓ http://localhost:5173
```

### Étape 5: Tester IA Import (dans navigateur)
```
http://localhost:5173/products/import/ai
```

---

## COMMANDES ESSENTIELLES

### Backend
| Commande | Effet |
|----------|-------|
| `npm run dev` | Démarrage dev mode (auto-reload) |
| `npm start` | Démarrage production mode |
| `npm test` | Lancer tests |
| `npm run lint` | Vérifier style code |

### oli_seller
| Commande | Effet |
|----------|-------|
| `npm run dev` | Démarrage Vite dev server |
| `npm run build` | Build production |
| `npm run preview` | Prévisualiser build |

### Database PostgreSQL
```bash
# Connexion directe
psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com \
     -U oli_db_user -d oli_db

# Lister tables
\dt

# Compter avatars
SELECT COUNT(*) FROM user_avatar_history;

# Quitter
\q
```

### Git Workflow
```bash
# Voir status
git status

# Voir branches
git branch

# Créer branche
git checkout -b feature/nom

# Commit
git add .
git commit -m "message"

# Push
git push origin feature/nom
```

---

## VÉRIFICATIONS RAPIDES

### Backend Sain?
```bash
curl http://localhost:5000/health
# ✓ Status 200 OK
```

### Base de Données OK?
```bash
psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com \
     -U oli_db_user -d oli_db -c "SELECT 1"
# ✓ Should return 1
```

### Clés API Configurées?
```bash
# Backend
grep -E "OPENROUTER_API_KEY|DB_HOST|CLOUDINARY" .env.local

# Frontend (oli_seller)
grep VITE_OPENROUTER_API_KEY oli_seller/.env.local
```

### Migrations OK?
```bash
psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com \
     -U oli_db_user -d oli_db \
     -c "SELECT COUNT(*) FROM user_avatar_history"
# ✓ Should return number of avatars
```

---

## LOGS & DEBUGGING

### Backend Logs (Terminal)
```bash
npm run dev 2>&1 | tee backend.log
# Logs sauvegardés dans backend.log
```

### Render Logs (Cloud)
```
https://dashboard.render.com
→ Services > oli-core > Logs
```

### Vercel Logs (Cloud)
```
https://vercel.com/dashboard
→ oli-seller > Deployments > Logs
```

### Browser Console (F12)
```javascript
// Test API
fetch('http://localhost:5000/health')
  .then(r => r.json())
  .then(d => console.log(d))

// Test IA Import API
fetch('https://openrouter.ai/api/v1/models', {
  headers: {'Authorization': 'Bearer sk-or-v1-YOUR_KEY'}
})
.then(r => r.json())
.then(d => console.log(d))
```

---

## TROUBLESHOOTING EXPRESS

| Problème | Solution Rapide |
|----------|-----------------|
| **Backend crash** | `npm run dev` (regarde message erreur) |
| **Port 5000 utilisé** | `lsof -i :5000` puis `kill -9 PID` |
| **Module not found** | `npm install && npm run dev` |
| **Clé API invalide** | Vérifier `.env.local`, format: `sk-or-v1-...` |
| **DB connection refused** | Vérifier `DB_HOST`, `DB_USER`, `DB_PASSWORD` |
| **IA Import échoue** | Ouvrir F12 → Network → voir requête OpenRouter |
| **Vite dev lent** | `rm -rf .vite node_modules && npm install` |

---

## ENV VARIABLES MINIMALES

### Backend (.env.local racine)
```env
OPENROUTER_API_KEY=sk-or-v1-YOUR_KEY
DB_HOST=dpg-d5f5o9q4d50c73chl7ng-a.onrender.com
DB_USER=oli_db_user
DB_PASSWORD=YOUR_PASSWORD
DB_NAME=oli_db
```

### Frontend (oli_seller/.env.local)
```env
VITE_OPENROUTER_API_KEY=sk-or-v1-YOUR_KEY
VITE_API_URL=http://localhost:5000
```

---

## CHECKLIST 30 SEC

```bash
✓ wsl -d Ubuntu
✓ cd ~/oli-core
✓ curl https://oli-core.onrender.com/health
✓ npm run dev
✓ (New Terminal) cd oli_seller && npm run dev
✓ Open http://localhost:5173
✓ Ready!
```

---

## RESSOURCES RAPIDES

- **Render Dashboard**: https://dashboard.render.com
- **Vercel Dashboard**: https://vercel.com/dashboard
- **OpenRouter API**: https://openrouter.ai/api/v1/models
- **PostgreSQL Docs**: https://www.postgresql.org/docs/12/

---

**Dernière mise à jour**: Mai 2026
