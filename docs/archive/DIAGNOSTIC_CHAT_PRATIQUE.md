# 🔍 DIAGNOSTIC PRATIQUE DU CHAT

## Commandes pour identifier les problèmes

### 1️⃣ Vérifier la Connexion Socket.IO

**Dans le navigateur (DevTools Console)**:

```javascript
// Vérifier si Socket.IO est chargé
console.log(io); // Doit afficher l'objet socket.io

// Vérifier les événements WebSocket
// Onglet Network > WS (WebSocket)
// Chercher: /socket.io/?... avec status 101 (Switching Protocols)
```

**En Flutter**:

```dart
// Ajouter des logs détaillés dans socket_service.dart
debugPrint('🔵 Socket Status: ${_socket?.connected}');
debugPrint('🔵 Is Connected: $_isConnected');

// Attendre la connexion
await Future.delayed(Duration(seconds: 2));
debugPrint('🔵 Socket connecté après 2s: ${_socket?.connected}');
```

---

### 2️⃣ Vérifier les Événements Socket

**Dans le serveur (Terminal)**:

```bash
# Ajouter ce log dans server.js après io.on('connection')
console.log('📊 Statistiques Socket:');
console.log('  - Clients connectés:', io.engine.clientsCount);
console.log('  - Rooms actifs:', Object.keys(io.sockets.adapter.rooms));

# Doit afficher quelque chose comme:
# 📊 Statistiques Socket:
#   - Clients connectés: 1
#   - Rooms actifs: [ 'user_12345', 'user_12345' ]
```

---

### 3️⃣ Vérifier l'Envoi de Message Pas-à-Pas

**Étape 1: Vérifier que le message arrive au serveur**

```bash
# Dans chat.routes.js, ajouter au début de POST /chat/messages:

router.post('/messages', async (req, res) => {
    const { conversationId, content, type, recipientId } = req.body;
    const senderId = req.user.id;

    console.log('📨 [CHAT/MESSAGES] Reçu:');
    console.log('   - Sender:', senderId);
    console.log('   - Recipient:', recipientId);
    console.log('   - Conversation:', conversationId);
    console.log('   - Content:', content.substring(0, 50));
    
    // ... reste du code
});
```

**Étape 2: Vérifier que le message est inséré en BD**

```bash
# Après INSERT INTO messages, ajouter:
const newMessage = msgResult.rows[0];
console.log('✅ Message inséré en BD:', newMessage.id);
console.log('   Conversation:', newMessage.conversation_id);
```

**Étape 3: Vérifier que l'événement Socket est envoyé**

```bash
# Avant io.to().emit, ajouter:
const io = req.app.get('io');
if (io) {
    console.log(`🚀 Émission Socket vers user_${recipientId}`);
    console.log('   Payload:', socketPayload);
    io.to(`user_${recipientId}`).emit('new_message', socketPayload);
} else {
    console.log('❌ Socket.IO non disponible!');
}
```

---

### 4️⃣ Vérifier la Réception en Flutter

**Dans chat_controller.dart**:

```dart
Future<void> _init() async {
    await loadMessages();
    
    debugPrint('🎧 Enregistrement du handler Socket');
    _socketCleanup = _socketService.onMessage((data) {
        debugPrint('📩 REÇU dans ChatController:');
        debugPrint('   - Sender: ${data['sender_id']}');
        debugPrint('   - Conversation: ${data['conversation_id']}');
        debugPrint('   - Content: ${data['content']}');
        
        final incomingConvId = data['conversation_id']?.toString();
        final senderId = data['sender_id']?.toString();

        bool isRelevant = (state.conversationId != null && incomingConvId == state.conversationId) ||
                          (senderId == otherUserId);

        debugPrint('   - IsRelevant: $isRelevant');
        
        if (isRelevant) {
            if (state.conversationId == null && incomingConvId != null) {
                state = state.copyWith(conversationId: incomingConvId);
            }
            state = state.copyWith(messages: [data, ...state.messages]);
            debugPrint('   ✅ Message ajouté à la liste!');
        }
    });
}
```

---

### 5️⃣ Vérifier la Requête HTTP

**Utiliser Postman/Insomnia**:

```
POST http://localhost:3000/chat/messages
Headers:
  Authorization: Bearer <TOKEN>
  Content-Type: application/json

Body:
{
  "conversationId": "123",
  "recipientId": "456",
  "content": "Test message",
  "type": "text"
}

Réponse attendue:
{
  "success": true,
  "message": {
    "id": 1,
    "conversation_id": "123",
    "sender_id": "789",
    "content": "Test message",
    "created_at": "2026-01-12T10:00:00Z"
  }
}
```

---

## 🔧 Quick Fixes à Essayer

### Fix 1: Relancer Socket
```dart
// Dans chat_page.dart, ajouter:
@override
void initState() {
    super.initState();
    final socket = ref.read(socketServiceProvider);
    if (!socket.isConnected) {
        debugPrint('🔄 Reconnexion Socket...');
        socket.connect(widget.myId);
    }
}
```

### Fix 2: Forcer le Refresh
```dart
// Après sendMessage, ajouter:
Future<void> sendMessage({required String content}) async {
    // ... code existant ...
    
    // ✅ Forcer un refresh après 1 seconde
    await Future.delayed(Duration(seconds: 1));
    await loadMessages();
}
```

### Fix 3: Vérifier le Token
```dart
// Dans socket_service.dart, avant connect():
final token = await _storage.getToken();
if (token == null || token.isEmpty) {
    debugPrint('❌ Pas de token trouvé!');
    return;
}
debugPrint('✅ Token trouvé: ${token.substring(0, 20)}...');
```

---

## 📊 Tableau de Débogage

| Symptôme | Vérifier | Solution |
|----------|----------|----------|
| Messages ne s'envoient pas | HTTP 200? | Vérifier DevTools > Network > XHR |
| Messages reçus mais pas affichés | Handler enregistré? | Vérifier logs "📩 REÇU dans ChatController" |
| Socket déconnecté immédiatement | Token valide? | Vérifier expiration JWT |
| Conversation vide au démarrage | GET /chat/messages 200? | Vérifier query DB |
| Ancien message réapparaît | conversationId null? | Force state update avec copyWith |

---

## 📝 Template de Log Complet

Copier-coller ce bloc pour un débogage exhaustif:

```javascript
// SERVER SIDE - server.js
io.on('connection', (socket) => {
    const userId = socket.user?.id;
    console.log(`\n${'='.repeat(60)}`);
    console.log(`✅ NOUVELLE CONNEXION SOCKET`);
    console.log(`   User ID: ${userId}`);
    console.log(`   Socket ID: ${socket.id}`);
    console.log(`${'='.repeat(60)}\n`);

    socket.on('join', (roomName) => {
        console.log(`👤 User ${userId} rejoint room: ${roomName}`);
    });

    socket.on('disconnect', () => {
        console.log(`❌ User ${userId} déconnecté`);
    });
});
```

```dart
// CLIENT SIDE - socket_service.dart
_socket!.onConnect((_) {
    debugPrint('\n${'='*60}');
    debugPrint('✅ SOCKET CONNECTÉ');
    debugPrint('   User: $userId');
    debugPrint('   Room: $roomName');
    debugPrint('   Time: ${DateTime.now()}');
    debugPrint('${'='*60}\n');
});
```

---

## ✅ Checklist de Débogage

- [ ] Vérifier que le serveur démarre sans erreur
- [ ] Vérifier que le token JWT n'est pas expiré
- [ ] Vérifier que Socket.IO se connecte (logs server)
- [ ] Vérifier que le handler est enregistré (logs Flutter)
- [ ] Envoyer un message test
- [ ] Vérifier que l'événement arrive au serveur
- [ ] Vérifier que l'émission Socket est envoyée
- [ ] Vérifier que le client reçoit l'événement
- [ ] Vérifier que le message s'ajoute à la liste
- [ ] Vérifier que l'UI se rafraîchit

---

**Suggestion**: Ouvrez 3 terminaux:
1. `npm start` (serveur)
2. `flutter run -d web` (app)
3. `tail -f server.log` (logs temps réel)

Puis envoyer un message et suivre le flux en temps réel!
