# Audit Complet du Projet `oli-core`

**Date:** 12 Janvier 2026
**Projet:** oli-core (Backend + Frontend)

## 1. Vue d'ensemble
Le projet est un monorepo (ou structure hybride) contenant :
- **Backend**: API REST Node.js/Express avec PostgreSQL et Socket.io.
- **Frontend**: Application Mobile/Web Flutter (`oli_app`).
- **Documentation**: Dossier `docs/` présent.

## 2. Audit Backend (`/src`)

### Architecture & Structure
- **Global**: Architecture MVC simple mais avec des fuites de responsabilité.
- **Entry Point**: `server.js` est monolithique. Il gère la config Express, Socket.io, et des routes spécifiques (Auth/Me, Upload).
    - *Problème*: Logique métier dans `server.js` (ex: requêtes SQL directes lignes 151-155).
- **Routing**: Les fichiers de routes (`src/routes/`) contiennent beaucoup de logique métier.
    - *Problème*: `chat.routes.js` fait 16KB. Les contrôleurs ne sont pas clairement séparés.
    - *Incohérence*: `shop.routes.js` (singulier) vs `shops.routes.js` (pluriel).

### Base de Données
- **Techno**: PostgreSQL via `pg`.
- **Migrations**: Gestion manuelle via scripts SQL et `run_migration.js`.
    - *Risque*: Pas de suivi de version robuste (type Liquibase, Flyway ou ORM migrations).
    - *Code*: Requêtes SQL en dur dans le code (Hardcoded SQL). Risque d'injection si mal paramétré (bien que `$1` soit utilisé) et difficulté de maintenance.

### Sécurité & Auth
- **Auth**: JWT standard.
- **Socket.io**: Authentification par token implémentée (Middleware Socket).
- **Uploads**: Cloudinary utilisé via `multer`.

### Recommandations Backend
1.  **Refactor Server**: Déplacer la logique de `server.js` vers des contrôleurs dédiés.
2.  **Controller Layer**: Extraire la logique des routes vers des fichiers `controllers/`.
3.  **ORM/Query Builder**: Envisager un Query Builder (Knex.js) ou au moins un Repository Pattern strict pour éviter le SQL dans les routes.
4.  **Migrations**: Adopter un outil de migration standard.
5.  **Standardisation**: Renommer `shop.routes.js` en `shops.routes.js`.

## 3. Audit Frontend (`oli_app`)

### Architecture & Structure
- **Techno**: Flutter 3.10.x.
- **Structure des dossiers (`lib/`)**:
    - Une tentative d'architecture "Feature-first" est visible (`features/`), MAIS...
    - *Incohérence*: Des dossiers features sont à la racine (`chat/`, `home/`, `tabs/`) au lieu d'être dans `features/`.
    - *Vrac*: Fichiers à la racine de `lib/` (`market_provider.dart`, `theme_provider.dart`).
- **State Management**:
    - **Flutter Riverpod** est utilisé (moderne, bon choix).
    - **Provider** est aussi listé dans `pubspec.yaml`. Risque de mélange ou dette technique.

### Dépendances & Code
- **HTTP Client**: Présence de `dio` ET `http`.
    - *Problème*: Redondance. Il faut choisir l'un des deux (recommandation : `dio` pour ses interceptors).
- **Socket**: `socket_io_client` pour le temps réel.
- **Firebase**: Présence de `firebase_core`, `cloud_firestore`.
    - *Question*: Pourquoi Firestore si le backend est PostgreSQL ? Usage hybride à clarifier.
- **Point d'entrée (`main.dart`)**:
    - Logique de connexion Socket mélangée à l'UI (`ref.listen` dans `build`). Devrait être dans un Service ou un Controller initialisé au démarrage.

### Recommandations Frontend
1.  **Dossiers**: Déplacer `chat`, `home`, `tabs` dans `features/`.
2.  **Nettoyage Lib**: Déplacer les providers racine dans `core/providers` ou les features respectives.
3.  **Dépendances**: Supprimer `http` si `dio` est utilisé. Supprimer `provider` si tout est migré sur `riverpod`.
4.  **Logique Métier**: Sortir la logique de connexion socket du `build` method de `main.dart`.

## 4. Bilan Global
Le projet est fonctionnel mais souffre de **dette technique structurelle**.
- Le Backend a besoin de séparer proprement Routes et Contrôleurs.
- Le Frontend a besoin d'une réorganisation stricte des dossiers pour respecter l'architecture choisie (Feature-first).
- Des incohérences de nommage et de librairies (Dio/Http) doivent être résolues.

Cette base est saine pour un prototype mais nécessite ce refactoring pour passer à l'échelle (Production).
