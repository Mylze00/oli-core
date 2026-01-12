# 🚀 GUIDE D'IMPLÉMENTATION ÉTAPE PAR ÉTAPE

## Phase 1: Préparation (15 min)

### Étape 1.1: Créer une branche de développement
```bash
cd oli-core
git checkout -b fix/chat-system
git branch -v  # Vérifier qu'on est sur fix/chat-system
```

### Étape 1.2: Sauvegarder les fichiers actuels
```bash
mkdir -p backups/chat
cp oli_app/lib/chat/*.dart backups/chat/
cp src/routes/chat.routes.js backups/chat/
cp src/server.js backups/
```

### Étape 1.3: Vérifier les dépendances
```bash
# Flutter
cd oli_app
flutter pub get
flutter pub add socket_io_client  # Si pas déjà présent

# Node.js
cd ../src
npm list | grep -E "socket.io|express|pg"
# Doit avoir: socket.io, express, pg
```

---

## Phase 2: Corrections Backend (30 min)

### Étape 2.1: Corriger server.js - JWT Verification

**Fichier**: `src/server.js` (lignes 36-47)

Remplacer:
```javascript
io.use((socket, next) => {
    const token = (socket.handshake.auth && socket.handshake.auth.token)
        || socket.handshake.headers.authorization;

    if (!token) return next();

    const cleanToken = token.replace("Bearer ", "");
    try {
        const decoded = jwt.verify(cleanToken, config.JWT_SECRET);
        socket.user = decoded;
        next();
    } catch (err) {
        console.warn(`[SOCKET] Échec auth : ${err.message}`);
        next(new Error("Authentication error"));
    }
});
```

Par:
```javascript
io.use((socket, next) => {
    const token = (socket.handshake.auth && socket.handshake.auth.token)
        || socket.handshake.headers.authorization;

    if (!token) {
        console.warn("[SOCKET] Pas de token");
        return next(new Error("No auth token"));
    }

    const cleanToken = token.replace("Bearer ", "");
    try {
        const decoded = jwt.verify(cleanToken, config.JWT_SECRET, {
            ignoreExpiration: false  // ✅ Vérifier expiration
        });
        socket.user = decoded;
        console.log(`✅ [SOCKET] User ${decoded.id} authentifié`);
        next();
    } catch (err) {
        console.warn(`❌ [SOCKET] Échec auth : ${err.message}`);
        if (err.name === 'TokenExpiredError') {
            return next(new Error("Token expired"));
        }
        next(new Error("Authentication error"));
    }
});
```

### Étape 2.2: Ajouter Logs Détaillés

**Fichier**: `src/routes/chat.routes.js`

Ajouter au début de `router.post('/send', ...)` (ligne ~85):

```javascript
router.post('/send', async (req, res) => {
    const { recipientId, content, type = 'text', productId, conversationId: existingConvId } = req.body;
    const senderId = req.user.id;

    console.log('\n📨 [/SEND] Nouveau message:');
    console.log(`   Sender: ${senderId}`);
    console.log(`   Recipient: ${recipientId}`);
    console.log(`   Content: ${content.substring(0, 30)}...`);
    console.log(`   Product: ${productId}`);

    try {
        // ... rest of code
```

Ajouter après `INSERT INTO messages` (ligne ~152):

```javascript
const newMessage = msgResult.rows[0];

console.log(`✅ [BD] Message inséré:`, {
    id: newMessage.id,
    conversation_id: newMessage.conversation_id,
    sender_id: newMessage.sender_id,
});

// 3. ENVOI TEMPS RÉEL (SOCKET.IO)
const io = req.app.get('io');
if (io) {
    console.log(`🚀 [SOCKET] Émission vers user_${recipientId}`);
    // ... emit code
}
```

Faire pareil pour `router.post('/messages', ...)`.

### Étape 2.3: Tester le serveur

```bash
cd src
npm start

# Doit afficher:
# 🚀 OLI SERVER v1.0 - Port 3000 (development)
# 📡 WebSocket ready
# (pas d'erreurs)
```

Laisser tourner dans un terminal.

---

## Phase 3: Corrections Frontend (45 min)

### Étape 3.1: Corriger socket_service.dart

**Fichier**: `oli_app/lib/chat/socket_service.dart`

Remplacer entièrement par le code du fichier `SOLUTIONS_CHAT_CORRIGES.md`.

Ou faire manuellement:

1. Ajouter `bool _isConnected = false;` après `final _storage = SecureStorageService();`
2. Changer `bool get isConnected => _socket?.connected ?? false;` en `bool get isConnected => _isConnected;`
3. Dans `onConnect`, ajouter `_isConnected = true;` au début
4. Dans `onReconnect`, ajouter `_isConnected = true;` au début
5. Dans `onDisconnect`, ajouter `_isConnected = false;` au début
6. Dans `onConnectError`, ajouter `_isConnected = false;` au début

**Tester la compilation**:
```bash
cd oli_app
flutter analyze lib/chat/socket_service.dart
# Pas d'erreurs?
```

### Étape 3.2: Corriger chat_controller.dart

**Fichier**: `oli_app/lib/chat/chat_controller.dart`

Remplacer entièrement par le code du fichier `SOLUTIONS_CHAT_CORRIGES.md`.

Ou faire manuellement si vous connaissez le code:

1. Ajouter attente de connexion dans `_init()`:
```dart
if (!_socketService.isConnected) {
    int attempts = 0;
    while (!_socketService.isConnected && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
    }
}
```

2. Changer `sendMessage()` pour utiliser l'endpoint correct:
```dart
final endpoint = state.conversationId == null ? '/chat/send' : '/chat/messages';
final response = await http.post(
    Uri.parse('${ApiConfig.baseUrl}/chat$endpoint'),
    // ... rest
);
```

3. Ajouter gestion du `conversationId` retourné:
```dart
if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (state.conversationId == null && data['conversationId'] != null) {
        state = state.copyWith(conversationId: data['conversationId']);
    }
}
```

### Étape 3.3: Corriger conversations_page.dart

**Fichier**: `oli_app/lib/chat/conversations_page.dart`

Remplacer entièrement par le code du fichier `SOLUTIONS_CHAT_CORRIGES.md`.

Ou à minima:
1. Remplacer tous les `FirebaseFirestore` par `http.get()`
2. Remplacer `stream:` par `FutureBuilder<List<dynamic>>`
3. Ajouter `RefreshIndicator` pour refresh manuel

**Vérifier**: L'import de Firestore doit être supprimé:
```bash
grep -n "firebase" oli_app/lib/chat/conversations_page.dart
# Doit être vide (0 résultats)
```

### Étape 3.4: Tester la compilation

```bash
cd oli_app
flutter pub get
flutter analyze lib/chat/
# Pas d'erreurs?

# Essayer de compiler
flutter run -d web --release
# Aucune erreur?
```

---

## Phase 4: Intégration (30 min)

### Étape 4.1: Démarrer le serveur

```bash
# Terminal 1
cd /path/to/oli-core/src
npm start
```

Attendre le message:
```
🚀 OLI SERVER v1.0 - Port 3000
📡 WebSocket ready
```

### Étape 4.2: Lancer l'app Flutter

```bash
# Terminal 2
cd /path/to/oli-core/oli_app
flutter run -d web
```

Attendre que l'app se charge.

### Étape 4.3: Tests Manuels

**Scénario 1: Ouvrir le chat**
```
1. Se connecter avec votre compte
2. Aller à l'onglet "Chats"
3. Vérifier que les conversations s'affichent (pas Firestore vide)
   ✅ Success: Voir la liste des discussions
   ❌ Fail: Écran vide ou erreur HTTP 401
```

**Scénario 2: Envoyer un message**
```
1. Cliquer sur une conversation existante
2. Taper un message
3. Appuyer sur "Envoyer"
4. Vérifier les logs serveur: "📨 [/SEND]" ou "📨 [/MESSAGES]"
   ✅ Success: Message apparaît dans la liste
   ❌ Fail: Rien ne change
```

**Scénario 3: Recevoir un message**
```
1. Dans une autre instance (autre navigateur/téléphone), envoyer un message
2. Vérifier que vous le recevez
3. Vérifier les logs: "📩 REÇU dans ChatController"
   ✅ Success: Message arrive en <500ms
   ❌ Fail: Rien ne s'affiche
```

**Scénario 4: Nouvelle conversation**
```
1. Aller à la page d'accueil
2. Trouver un produit
3. Cliquer sur "Chat Vendeur"
4. Envoyer un premier message
   ✅ Success: Nouvelle conversation créée
   ❌ Fail: Erreur 400/500 ou timeout
```

### Étape 4.4: Vérifier les Logs

**Terminal Server**:
```
✅ Doit afficher:
   - [SOCKET] User 12345 authentifié
   - [/SEND] Nouveau message
   - ✅ [BD] Message inséré
   - 🚀 [SOCKET] Émission vers user_67890
   - 📨 [/MESSAGES] Nouveau message

❌ Ne doit PAS afficher:
   - ❌ [SOCKET] Pas de token
   - ❌ [SOCKET] Échec auth
   - Error: Cannot find module
```

**DevTools Flutter**:
```
✅ Doit afficher:
   - 🟢 Socket connecté. Room: user_XXXXX
   - 🎧 Enregistrement du handler Socket
   - 📩 REÇU dans ChatController (après envoi)

❌ Ne doit PAS afficher:
   - ❌ Erreur envoi
   - ❌ Socket non initialisé
   - ❌ 401 Unauthorized
```

---

## Phase 5: Validation (15 min)

### Étape 5.1: Checklist Fonctionnalités

```
□ Conversations se chargent
□ Nouveaux messages s'affichent instantanément
□ Envoi de message fonctionne
□ Réception de message fonctionne
□ Nouvelle conversation peut être créée
□ Conversation existante peut être réouvert
□ Socket reconnecte après déconnexion
□ Aucun message perdu après reconnexion
□ Performance acceptable (<1 sec latence)
□ Pas d'erreurs dans les logs
```

### Étape 5.2: Tests de Stress

```bash
# Envoyer 10 messages d'affilée
for i in {1..10}; do
    # Envoyer via API ou UI
    echo "Message $i"
    sleep 0.5
done

# Vérifier:
# - Tous les 10 messages arrivent
# - Pas de dédupliquant
# - Pas de perte
```

### Étape 5.3: Redémarrage Serveur

```bash
# Arrêter le serveur (Ctrl+C)
# Attendre 5 secondes
# Relancer

npm start

# Vérifier:
# - Socket reconnecte automatiquement
# - Ancien messages restent visibles
# - Peut envoyer nouveau message
```

---

## Phase 6: Commit & Push (10 min)

### Étape 6.1: Vérifier les changements

```bash
git status
# Doit montrer les fichiers modifiés:
#   - oli_app/lib/chat/socket_service.dart
#   - oli_app/lib/chat/chat_controller.dart
#   - oli_app/lib/chat/conversations_page.dart
#   - src/server.js
#   - src/routes/chat.routes.js
```

### Étape 6.2: Ajouter les changements

```bash
git add \
    oli_app/lib/chat/socket_service.dart \
    oli_app/lib/chat/chat_controller.dart \
    oli_app/lib/chat/conversations_page.dart \
    src/server.js \
    src/routes/chat.routes.js

git status  # Vérifier qu'ils sont stagés (green)
```

### Étape 6.3: Créer le commit

```bash
git commit -m "fix(chat): Corriger les 5 failles critiques du système de chat

- Faille 1: Unifier sur PostgreSQL (supprimer Firestore)
- Faille 2: Endpoint cohérent (/send vs /messages)
- Faille 3: Socket connection timing (wait onConnect)
- Faille 4: Handler registration (wait isConnected)
- Faille 5: JWT security (verifyExpiration)

Tests:
- Conversations se chargent depuis PostgreSQL
- Messages reçus en temps réel via WebSocket
- Nouvelle conversation créée avec /send
- Reconnexion automatique après déconnexion

Fixes #chat-broken"
```

### Étape 6.4: Push vers main

```bash
git push origin fix/chat-system

# Aller sur GitHub/GitLab et créer une Pull Request
# Avec le message du commit comme description
```

---

## 📋 Checklist Finale

### Avant de déclarer "Terminé"

- [ ] Tous les 5 fichiers modifiés
- [ ] Aucune erreur de compilation
- [ ] Tests manuels passent
- [ ] Logs serveur propres (pas d'erreurs)
- [ ] Logs Flutter propres (pas d'erreurs)
- [ ] Performance acceptable
- [ ] Commit poussé sur la branche
- [ ] Pull Request créée
- [ ] Revue de code faite
- [ ] Merge en main

### Après le merge

- [ ] Tester sur staging
- [ ] Tester sur production
- [ ] Monitorer les logs 24h
- [ ] Communiquer aux utilisateurs
- [ ] Documenter les changements dans la wiki

---

## 🆘 Si Ça Ne Marche Pas

### Erreur: `Cannot find module 'socket.io'`
```bash
cd src
npm install socket.io
npm install socket.io-client
```

### Erreur: `Socket connection timeout`
Vérifier que le serveur est en cours d'exécution:
```bash
lsof -i :3000
# Doit montrer un processus Node
```

### Erreur: `401 Unauthorized`
Vérifier que le token JWT est valide:
```bash
# Dans DevTools Flutter, vérifier localStorage:
# -> token doit exister et ne pas être expiré
```

### Erreur: `Connection refused`
Vérifier que `ApiConfig.baseUrl` pointe au bon serveur:
```dart
// oli_app/lib/config/api_config.dart
static const String baseUrl = 'http://localhost:3000';  // Dev
// ou
static const String baseUrl = 'https://oli-core.onrender.com';  // Prod
```

---

## ⏱️ Temps Estimé Total

| Phase | Temps |
|-------|-------|
| 1. Préparation | 15 min |
| 2. Backend | 30 min |
| 3. Frontend | 45 min |
| 4. Intégration | 30 min |
| 5. Validation | 15 min |
| 6. Commit | 10 min |
| **TOTAL** | **2h 45min** |

**Plus temps de debugging: +30 min - 2h** (selon les erreurs)

---

**Status**: Prêt à déployer ✅
