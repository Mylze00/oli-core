# 🏗️ ARCHITECTURE DÉPLOIEMENT - oli-core (Mai 2026)

## DIAGRAMME FLUX COMPLET

```
┌─────────────────────────────────────────────────────────────────────┐
│                         UTILISATEURS FINAUX                         │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                 ┌────────────────┼────────────────┐
                 │                │                │
        ┌────────▼────┐   ┌──────▼──────┐   ┌────▼────────┐
        │   Navigateur │   │ Mobile App  │   │ Admin      │
        │ (Web)        │   │ (Flutter)   │   │ Dashboard  │
        │              │   │             │   │ (Vercel)   │
        └────────┬─────┘   └──────┬──────┘   └────┬───────┘
                 │                │               │
          ┌──────▼──────────────────▼──────────┬──┴─────────┐
          │     HTTP + WebSocket               │            │
          │     (HTTPS en Production)          │            │
          │                                    │            │
    ┌─────▼─────────────────────────────────┐ │            │
    │     VERCEL (Frontend)                 │ │            │
    │ ┌──────────────────────────────────┐  │ │            │
    │ │ oli_seller.vercel.app            │  │ │            │
    │ │ • Vite + React 19                │  │ │            │
    │ │ • Tailwind CSS                   │  │ │            │
    │ │ • Socket.io Client               │  │ │            │
    │ │ • OpenRouter API (IA Import)     │  │ │            │
    │ └──────────────────────────────────┘  │ │            │
    │ ┌──────────────────────────────────┐  │ │            │
    │ │ oli-admin-smoky.vercel.app       │  │ │            │
    │ │ • Dashboard Admin                │  │ │            │
    │ └──────────────────────────────────┘  │ │            │
    └─────┬──────────────────────────────────┘ │            │
          │                                    │            │
          │                                    │            │
    ┌─────▼────────────────────────────────────▼────────────▼─────┐
    │              RENDER - Backend API                           │
    │              oli-core.onrender.com                          │
    │                                                              │
    │  ┌────────────────────────────────────────────────────────┐ │
    │  │ Node.js Express Server (Port 5000)                     │ │
    │  │                                                        │ │
    │  │  ✓ /auth/send-otp, /auth/verify-otp                   │ │
    │  │  ✓ /products/* (CRUD + Search)                        │ │
    │  │  ✓ /orders/* (Commandes)                              │ │
    │  │  ✓ /chat/* (Messagerie)                               │ │
    │  │  ✓ /wallet/* (Portefeuille)                           │ │
    │  │  ✓ /delivery/* (Livraisons)                           │ │
    │  │  ✓ /admin/* (14 routes admin)                         │ │
    │  │                                                        │ │
    │  │  Middleware:                                           │ │
    │  │  • JWT Verification (15 min TTL)                       │ │
    │  │  • CORS (9 origins allowed)                            │ │
    │  │  • Helmet Security Headers                             │ │
    │  │  • Multer File Upload                                  │ │
    │  └────────────────────────────────────────────────────────┘ │
    │                                                              │
    │  ┌────────────────────────────────────────────────────────┐ │
    │  │ Socket.io Server (WebSocket)                           │ │
    │  │                                                        │ │
    │  │  ✓ Real-time Messaging                                │ │
    │  │  ✓ User Presence                                      │ │
    │  │  ✓ Notifications                                      │ │
    │  │  ✓ Chat Rooms                                         │ │
    │  └────────────────────────────────────────────────────────┘ │
    │                                                              │
    │  Intégrations Externes:                                     │
    │  • 📍 Google Maps API (Livreurs GPS)                        │
    │  • 🖼️  Cloudinary (Image CDN)                              │
    │  • 💳 Stripe API (Paiements)                               │
    │  • 💰 Unipesa (Mobile Money RDC)                           │
    │  • 🤖 OpenRouter (LLM - Recommendations)                   │
    │  • 👁️  Google Cloud Vision (Image Recognition)            │
    │  • 🔔 Firebase Admin SDK (Push Notifications)              │
    │  • 🔐 JWT (Authentication)                                │
    └─────┬────────────────────────────────────────────────────────┘
          │
          │ SQL Queries (Port 5432)
          │
    ┌─────▼───────────────────────────────────────────────────────┐
    │        RENDER - PostgreSQL Database                         │
    │        dpg-d5f5o9q4d50c73chl7ng-a.onrender.com             │
    │                                                              │
    │  ┌──────────────────────────────────────────────────────┐   │
    │  │ Tables Principales:                                  │   │
    │  │                                                      │   │
    │  │ • users (id, phone, avatar_url, is_seller, etc)     │   │
    │  │ • products (id, shop_id, name, price, etc)          │   │
    │  │ • orders (id, user_id, total, status, etc)          │   │
    │  │ • conversations (id, participants)                  │   │
    │  │ • messages (id, conversation_id, content)           │   │
    │  │ • user_avatar_history (id, user_id, avatar_url)     │   │
    │  │ • shops (id, owner_id, name, verified)              │   │
    │  │ • delivery_tracking (id, order_id, location)        │   │
    │  │ • wallet_transactions (id, user_id, amount)         │   │
    │  │ • verifications (id, user_id, status, docs)         │   │
    │  └──────────────────────────────────────────────────────┘   │
    │                                                              │
    │  ✓ Backup: Wasabi/S3 Automated                              │
    │  ✓ Replicas: Configurable sur Render                        │
    │  ✓ SSL: Secured Connections                                 │
    └──────────────────────────────────────────────────────────────┘
```

---

## LOCALISATION - DÉVELOPPEMENT LOCAL

```
┌──────────────────────────────────────────────────────┐
│  Windows (PowerShell)                                │
│  wsl -d Ubuntu                                       │
└────────────┬─────────────────────────────────────────┘
             │
             │ WSL 2
             │
    ┌────────▼──────────────────────────────────────┐
    │  Ubuntu WSL Environment                       │
    │  /home/paolice-mylze/oli-core                 │
    │                                                │
    │  ┌────────────────────────────────────────┐   │
    │  │ Terminal 1: Backend (Port 5000)        │   │
    │  │ $ npm run dev                          │   │
    │  │ ✓ Express Server                       │   │
    │  │ ✓ Socket.io Connected                  │   │
    │  │ ✓ PostgreSQL Connected                 │   │
    │  └────────────────────────────────────────┘   │
    │                                                │
    │  ┌────────────────────────────────────────┐   │
    │  │ Terminal 2: oli_seller (Port 5173)     │   │
    │  │ $ cd oli_seller && npm run dev         │   │
    │  │ ✓ Vite Dev Server                      │   │
    │  │ ✓ Hot Module Replacement (HMR)         │   │
    │  └────────────────────────────────────────┘   │
    │                                                │
    │  ┌────────────────────────────────────────┐   │
    │  │ Config Files:                          │   │
    │  │ • .env.local (Backend)                 │   │
    │  │ • oli_seller/.env.local (Frontend)     │   │
    │  │ • oli_admin/.env.local (Admin)         │   │
    │  └────────────────────────────────────────┘   │
    │                                                │
    │  ┌────────────────────────────────────────┐   │
    │  │ Browsers:                              │   │
    │  │ • localhost:5173 (oli_seller)         │   │
    │  │ • localhost:5000/health (Backend)     │   │
    │  └────────────────────────────────────────┘   │
    └────────────────────────────────────────────────┘
```

---

## DÉPLOIEMENT CI/CD

### Render (Backend)
```
GitHub Push (main/develop)
        ↓
Render Webhook Triggered
        ↓
┌─────────────────────────────┐
│ Auto Build:                 │
│ • npm install               │
│ • npm start                 │
│ • PostgreSQL Migration      │
│ • Health Check              │
└─────────────────────────────┘
        ↓
Deploy (auto)
        ↓
✓ oli-core.onrender.com LIVE
```

### Vercel (Frontends)
```
GitHub Push (main/develop)
        ↓
Vercel Webhook Triggered
        ↓
┌─────────────────────────────┐
│ Auto Build:                 │
│ • npm install               │
│ • npm run build             │
│ • Env Vars Injected         │
│ • Optimization              │
└─────────────────────────────┘
        ↓
Deploy (auto)
        ↓
✓ oli-seller.vercel.app LIVE
✓ oli-admin-smoky.vercel.app LIVE
```

---

## FLUX DATA - IA IMPORT EXAMPLE

```
1. USER ACTION (Browser - oli_seller)
   ↓
   Upload Image(s) → ProductAiImport.jsx

2. COMPRESSION & ENCODING (Browser)
   ↓
   Convert to Base64 (800px max)
   Compress to JPEG 70% quality

3. API CALL (Browser → OpenRouter)
   ↓
   POST https://openrouter.ai/api/v1/chat/completions
   Headers:
     • Authorization: Bearer VITE_OPENROUTER_API_KEY
     • Content-Type: application/json
   Body:
     • model: gpt-4o-mini
     • messages: [system_prompt, user_images]

4. AI PROCESSING (OpenRouter → OpenAI)
   ↓
   GPT-4o-mini analyzes images
   Returns: JSON with product data

5. DATA ENRICHMENT (Browser - ProductAiImport.jsx)
   ↓
   Calculate:
   • Price CNY → USD conversion
   • Freight cost (air + maritime)
   • Validate sizes (shoes/clothing)
   • Generate shipping options

6. BATCH SUBMISSION (Browser → Backend)
   ↓
   POST http://localhost:5000/products/batch
   Body:
     • products: [{name, description, price, ...}]
     • images: [base64_urls]

7. BACKEND PROCESSING (Node.js)
   ↓
   • Verify JWT Token
   • Save Products to PostgreSQL
   • Upload Images to Cloudinary
   • Store metadata in DB

8. CONFIRMATION (Response)
   ↓
   {
     "success": true,
     "productsCreated": 5,
     "errors": []
   }

9. USER SEES PRODUCTS (Browser)
   ↓
   Redirect to ProductList
   Show newly created products with success toast
```

---

## MONITORING & OBSERVABILITY

### Logs Locations

| Service | Logs | URL |
|---------|------|-----|
| Backend | Render Logs | https://dashboard.render.com |
| Vercel Apps | Deployments | https://vercel.com/dashboard |
| Database | Render Postgres | https://dashboard.render.com |
| Browser | DevTools (F12) | localhost:5173 |

### Health Checks

| Endpoint | Purpose | Command |
|----------|---------|---------|
| `/health` | Backend Status | `curl http://localhost:5000/health` |
| PostgreSQL | DB Status | `psql ... -c "SELECT 1"` |
| OpenRouter | API Status | `curl https://api.openrouter.ai/` |
| Cloudinary | CDN Status | Via Dashboard |

---

## SÉCURITÉ - Architecture

```
┌─────────────────────────────────────────┐
│ HTTPS/TLS                               │
│ (Render + Vercel Certs)                 │
└──────────────┬──────────────────────────┘
               │
               ↓
        ┌────────────────────┐
        │ CORS Middleware    │
        │ (9 allowed origins)│
        └────────────────────┘
               │
               ↓
        ┌────────────────────┐
        │ Helmet Headers     │
        │ (Security)         │
        └────────────────────┘
               │
               ↓
        ┌────────────────────────┐
        │ JWT Authentication     │
        │ (15 min expiration)    │
        └────────────────────────┘
               │
               ↓
        ┌────────────────────────┐
        │ Multer File Upload     │
        │ (Max 5MB, validated)   │
        └────────────────────────┘
               │
               ↓
        ┌────────────────────────┐
        │ PostgreSQL Prepared    │
        │ Statements (SQL Inject │
        │ Protection)            │
        └────────────────────────┘
               │
               ↓
        ┌────────────────────────┐
        │ Cloudinary CDN         │
        │ (Secure Image Serving) │
        └────────────────────────┘
```

---

## DÉMARRAGE CHECKLIST

### 1. Infrastructure Ready?
- [ ] Render Backend: https://oli-core.onrender.com/health → 200 OK
- [ ] PostgreSQL: Accessible via psql
- [ ] Vercel Apps: https://oli-seller.vercel.app → 200 OK

### 2. Configuration Ready?
- [ ] `.env.local` présent (Backend)
- [ ] `oli_seller/.env.local` présent (Frontend)
- [ ] `OPENROUTER_API_KEY` configured
- [ ] `DB_*` credentials correct

### 3. Code Ready?
- [ ] `git status` → clean (no uncommitted changes)
- [ ] `node --version` → v18+
- [ ] `npm --version` → v9+

### 4. Migrations Ready?
- [ ] `user_avatar_history` table exists
- [ ] Old avatars migrated (> 0 rows)

### 5. Launch!
- [ ] Terminal 1: `npm run dev` (Backend)
- [ ] Terminal 2: `cd oli_seller && npm run dev` (Frontend)
- [ ] Browser: http://localhost:5173

---

**Dernière mise à jour**: Mai 2026
**Architecture Version**: 1.0 (Monorepo Hybrid)
