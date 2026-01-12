# Plan de Restructuration `oli-core`

Ce plan vise à améliorer la maintenabilité du projet en appliquant les recommandations de l'audit.

## Backend Restructuring

### Objectifs
1.  Alléger `src/server.js`.
2.  Séparer la logique métier (Controllers) du routing (Routes).
3.  Standardiser le nommage des fichiers.

### Étapes
#### 1. Création de la couche Controllers
- [NEW] `src/controllers/auth.controller.js`: Pour la logique user/me et upload.
- [NEW] `src/controllers/chat.controller.js`: Pour extraire la logique massive de `chat.routes.js`.

#### 2. Nettoyage `src/server.js`
- Déplacer la route `/auth/me` vers `auth.routes.js` + `auth.controller.js`.
- Déplacer la route `/auth/upload-avatar` vers `auth.routes.js` + `auth.controller.js`.

#### 3. Standardisation
- [RENAME] `src/routes/shop.routes.js` -> `src/routes/shops.routes.js` (si applicable, ou vérifier l'usage). *Note: L'audit a révélé deux fichiers: `shop.routes.js` et `shops.routes.js`. Il faudra vérifier si c'est un doublon.*

## Frontend Restructuring (`oli_app`)

### Objectifs
1.  Respecter l'architecture "Feature-first".
2.  Nettoyer la racine de `lib/`.

### Étapes
#### 1. Réorganisation des dossiers
- Déplacer `lib/chat` -> `lib/features/chat`
- Déplacer `lib/home` -> `lib/features/home`
- Déplacer `lib/tabs` -> `lib/features/tabs` (ou `lib/features/navigation`)

#### 2. Mise à jour des imports
- Mettre à jour `main.dart` et les autres fichiers impactés par le déplacement.

#### 3. Nettoyage Root (`lib/`)
- Mettre à jour les imports pour `market_provider.dart` etc. (les déplacer ultérieurement si nécessaire, focus sur les gros dossiers d'abord).

## Verification Plan

### Backend
- Démarrer le serveur (`npm run dev`) et vérifier qu'il n'y a pas d'erreur au lancement.
- Tester `/auth/me` via un client API (si possible) ou vérifier les logs.

### Frontend
- Lancer `flutter pub get`.
- Tenter un `flutter build web` pour vérifier que tous les imports sont corrects.
