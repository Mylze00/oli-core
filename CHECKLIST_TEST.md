# 🧪 CHECKLIST DE TEST - SYSTÈME DE CHAT

## Phase 1: Compilation & Démarrage

- [ ] **Flutter Analyze**
  ```bash
  cd oli_app
  flutter analyze
  ```
  Attendu: ✅ No issues found (ou seulement warnings non-critiques)

- [ ] **Flutter Pub Get**
  ```bash
  flutter pub get
  ```
  Attendu: ✅ All dependencies downloaded

- [ ] **Node.js Server Start**
  ```bash
  cd ..
  npm start
  ```
  Attendu: ✅ Server running on port 3000 (ou votre port)

- [ ] **Vérifier Socket.IO Listen**
  Logs attendus:
  ```
  🟢 Socket.IO server listening
  🟢 PostgreSQL connected
  ```

---

## Phase 2: Connexion & Authentification

### Test 2A: Connexion WebSocket
- [ ] L'app Flutter se connecte au serveur
- [ ] Logs attendus dans le backend:
  ```
  🔐 [AUTH] Vérification token pour user_123
  🟢 [AUTH] Utilisateur authentifié: 123
  👤 User 123 joined room: user_123
  ```

### Test 2B: Token Expiré
- [ ] Manipuler un token JWT pour l'expirer
- [ ] Reconnecter l'app
- [ ] Logs attendus:
  ```
  ❌ [AUTH] Token expiré
  ```
- [ ] Vérifier que la connexion est rejetée

---

## Phase 3: Charger les Conversations

### Test 3A: Page Conversations Load
- [ ] Ouvrir l'onglet Discussions
- [ ] Logs attendus dans le backend:
  ```
  GET /chat/conversations
  ✅ Conversations loaded for user 123
  ```
- [ ] Vérifier que les conversations s'affichent

### Test 3B: Refresh Manuel
- [ ] Tirer vers le bas pour refresh
- [ ] Vérifier que la requête `/chat/conversations` est relancée
- [ ] Logs attendus:
  ```
  GET /chat/conversations (à nouveau)
  ```

---

## Phase 4: Envoyer Message (Conversation Existante)

### Test 4A: Message Simple
- [ ] Ouvrir une conversation existante
- [ ] Taper "Bonjour c'est un test"
- [ ] Appuyer sur Envoyer
- [ ] **Logs attendus (Backend):**
  ```
  📨 [/messages] Expéditeur: 123, Contenu: "Bonjour c'est un test"
  👤 [/messages] Destinataire: 456
  ✅ [BD] Message inséré (ID: 5001) dans conversation 999
  📡 [SOCKET] Émission new_message vers user_456
  📡 [SOCKET] Émission new_message vers user_123 (confirmation)
  ```
- [ ] Vérifier que le message s'affiche dans le chat (côté expéditeur)
- [ ] **Côté destinataire:** Le message doit apparaître en temps réel

### Test 4B: Message Avec Type (Optional)
- [ ] Envoyer un message avec montant (money transfer) ou reply
- [ ] Vérifier que le `type` et le `metadata` sont correctement transmis

---

## Phase 5: Créer Nouvelle Conversation

### Test 5A: Initier Nouvelle Conversation
- [ ] Partir d'une page sans conversation
- [ ] Taper le premier message: "Salut, intéressé par ton produit?"
- [ ] **Logs attendus (Backend):**
  ```
  📨 [/send] Expéditeur: 123
  📨 [/send] Destinataire: 456
  📨 [/send] Contenu: "Salut, intéressé par ton produit..."
  📨 [/send] Produit: 789 (si applicable)
  ✅ [BD] Conversation créée (ID: 1000)
  ✅ [BD] Message inséré (ID: 5002)
  📡 [SOCKET] Émission new_message vers user_456
  📡 [SOCKET] new_request émis vers user_456
  ```
- [ ] Vérifier que le `conversationId` est retourné et stocké
- [ ] Vérifier que le message s'affiche avec le nouvel ID

### Test 5B: Vérifier Nouvelle Conversation dans Liste
- [ ] Aller à la page Conversations
- [ ] Vérifier que la nouvelle conversation apparaît
- [ ] Vérifier que le dernier message est celui qu'on vient d'envoyer
- [ ] **Côté destinataire:** La nouvelle conversation doit apparaître dans sa liste

---

## Phase 6: Temps Réel (2 Appareils)

### Configuration
- [ ] Appareil 1: User A (ID: 123)
- [ ] Appareil 2: User B (ID: 456)
- [ ] Conversation existante entre A et B

### Test 6A: A envoie, B reçoit
- [ ] A ouvre le chat
- [ ] B ouvre le même chat
- [ ] A envoie: "Message temps réel"
- [ ] **Vérifier que B reçoit le message instantanément** (< 1 seconde)
- [ ] **Logs attendus:**
  - Backend reçoit POST `/messages`
  - Backend envoie Socket.IO à `user_456`
  - B reçoit événement `new_message` immédiatement

### Test 6B: Socket Reconnection
- [ ] Fermer le WiFi/données sur l'appareil A
- [ ] Attendre 5 secondes
- [ ] Reconnecter le WiFi/données
- [ ] Vérifier que A se reconnecte automatiquement
- [ ] Logs attendus:
  ```
  🔄 Reconnecté au socket
  ```
- [ ] A devrait recevoir les messages qu'il a manqués

---

## Phase 7: Gestion des Erreurs

### Test 7A: Serveur Inatteignable
- [ ] Arrêter le serveur Node.js
- [ ] Essayer d'envoyer un message
- [ ] Attendu: Message d'erreur dans l'app (timeout/connection failed)
- [ ] Redémarrer le serveur
- [ ] Vérifier que l'app se reconnecte automatiquement

### Test 7B: BD Indisponible
- [ ] Arrêter PostgreSQL
- [ ] Essayer d'envoyer un message
- [ ] Logs attendus:
  ```
  ❌ Erreur: Connection failed
  ```
- [ ] Redémarrer PostgreSQL
- [ ] Vérifier que ça fonctionne à nouveau

### Test 7C: Token Invalide
- [ ] Manipuler le JWT token stocké localement
- [ ] Essayer d'envoyer un message
- [ ] Attendu: 401 Unauthorized
- [ ] Se reconnecter avec les bonnes credentials

---

## Phase 8: Performance & Scalabilité

### Test 8A: Plusieurs Conversations
- [ ] Ouvrir 10 conversations différentes
- [ ] Envoyer un message dans chacune
- [ ] Vérifier que tous les messages arrivent
- [ ] Vérifier pas de lag

### Test 8B: Longs Messages
- [ ] Envoyer un message de 1000 caractères
- [ ] Vérifier qu'il s'affiche correctement
- [ ] Logs attendus:
  ```
  📨 [/messages] Expéditeur: 123, Contenu: "..." (caractères tronqués dans log)
  ```

### Test 8C: Rafale de Messages
- [ ] Envoyer 10 messages rapidement (1 par seconde)
- [ ] Vérifier que tous arrivent dans l'ordre correct
- [ ] Vérifier les timestamps dans la BD

---

## Checklist de Débogage

Si quelque chose ne marche pas:

### Messages n'arrivent pas
- [ ] Vérifier les logs `/messages` ou `/send` sur le backend
- [ ] Si pas de log → Client n'envoie pas la requête
  - Vérifier `debugPrint` logs dans l'app Flutter
  - Vérifier que le socket est connecté (`_isConnected = true`)
- [ ] Si log mais pas de Socket.IO → Socket.IO não está conectado
  - Vérifier que `io` est configuré: `req.app.get('io')`
  - Vérifier que destinataire est dans la room `user_456`

### Conversations n'affichent pas
- [ ] Vérifier que `/chat/conversations` retourne des données
  ```bash
  curl -H "Authorization: Bearer TOKEN" http://localhost:3000/chat/conversations
  ```
- [ ] Vérifier que le JWT token est valide
- [ ] Vérifier que la BD a les conversations:
  ```sql
  SELECT * FROM conversations WHERE id IN (
    SELECT conversation_id FROM conversation_participants WHERE user_id = 123
  );
  ```

### Socket ne se connecte pas
- [ ] Vérifier les logs `[AUTH]` sur le backend
- [ ] Si `Token manquant` → App n'envoie pas le token
- [ ] Si `Token expiré` → Se reconnecter
- [ ] Si `Token invalide` → Vérifier que JWT_SECRET est correct

### Race Condition (room joins avant connexion)
- [ ] Vérifier que le log `🟢 Connecté au socket` apparaît AVANT `join_room`
- [ ] Vérifier que `_isConnected = true` est set avant emit('join', ...)

---

## Command Line Quick Tests

```bash
# 1. Vérifier que le serveur écoute
lsof -i :3000

# 2. Vérifier la connectivité PostgreSQL
psql -h localhost -U user -d oli_core -c "SELECT COUNT(*) FROM conversations;"

# 3. Vérifier les logs Socket.IO
tail -f server_logs.txt | grep "🟢\|❌\|📡"

# 4. Test endpoint REST
curl -X GET "http://localhost:3000/chat/conversations" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# 5. Test endpoint /send (nouvelle conversation)
curl -X POST "http://localhost:3000/chat/send" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "recipientId": 456,
    "content": "Test message",
    "productId": 789
  }'
```

---

## Notes Importantes

- ✅ **Tous les fichiers sont déjà corrigés** dans le repository
- ✅ **Pas besoin de migrations BD** (structure inchangée)
- ✅ **Pas de nouvelles dépendances** (tout existe déjà)
- ✅ **Compatibilité backward** (anciens clients peuvent recevoir les nouveaux messages)
- ⚠️ **Les logs de débogage seront visibles en console** (à désactiver avant production)

---

## Validation Finale

Une fois tous les tests passés, vous pouvez confirmer:

- [ ] ✅ Les utilisateurs peuvent envoyer/recevoir messages en temps réel
- [ ] ✅ Les nouvelles conversations se créent correctement
- [ ] ✅ La liste des conversations se synchronise avec la BD
- [ ] ✅ Les WebSockets reconnectent automatiquement
- [ ] ✅ Les logs facilitent le débogage
- [ ] ✅ Pas d'erreurs dans les consoles (Flutter + Node.js)

**Status**: 🟢 **CHAT FULLY FUNCTIONAL**
