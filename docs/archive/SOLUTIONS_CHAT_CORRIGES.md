# 🔧 SOLUTIONS POUR CORRIGER LE CHAT

## FAILLE 1: Unifier sur PostgreSQL + Socket.IO

### Step 1: Remplacer conversations_page.dart

```dart
// ✅ VERSION CORRIGÉE - Utiliser l'API PostgreSQL via HTTP

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_page.dart';
import '../core/user/user_provider.dart';
import '../config/api_config.dart';
import '../core/storage/secure_storage_service.dart';

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  final TextEditingController _searchController = TextEditingController();
  final _storage = SecureStorageService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _fetchConversations() async {
    try {
      final token = await _storage.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/conversations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint("Erreur fetch conversations: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;
    final String? myId = user?.id.toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Discussions',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: myId == null
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<List<dynamic>>(
                  future: _fetchConversations(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError || snapshot.data == null) {
                      return Center(child: Text("Erreur: ${snapshot.error}"));
                    }

                    final conversations = snapshot.data ?? [];

                    if (conversations.isEmpty) {
                      return const Center(
                        child: Text("Aucune discussion pour le moment"),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                      },
                      child: ListView.builder(
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conv = conversations[index];
                          final int unreadCount = conv['unread_count'] ?? 0;

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.blue.shade100,
                              backgroundImage: conv['other_avatar'] != null 
                                ? NetworkImage(conv['other_avatar'])
                                : null,
                              child: conv['other_avatar'] == null
                                ? Text(
                                    (conv['other_name'] ?? '')[0].toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold)
                                  )
                                : null,
                            ),
                            title: Text(
                              conv['other_name'] ?? 'Utilisateur',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              conv['last_message'] ?? 'Aucun message',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      "$unreadCount",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    myId: myId,
                                    otherId: conv['other_id'].toString(),
                                    otherName: conv['other_name'] ?? 'Chat',
                                    conversationId: conv['conversation_id'],
                                    productId: conv['product_id'],
                                    productName: conv['product_name'],
                                    productPrice: conv['product_price'],
                                    productImage: conv['product_image'],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
```

---

## FAILLE 2 & 3: Fixer Socket Connection + Endpoint Incohérent

### Step 2: Corriger socket_service.dart

```dart
// ✅ VERSION CORRIGÉE - Socket_service.dart

import 'dart:ui';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import '../core/storage/secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService();
});

class SocketService {
  IO.Socket? _socket;
  final _storage = SecureStorageService();
  bool _isConnected = false;  // ✅ NOUVEAU: Flag de connexion
  
  IO.Socket get socket {
    if (_socket == null) throw Exception("Socket non initialisé.");
    return _socket!;
  }

  bool get isConnected => _isConnected;

  Future<void> connect(String userId) async {
    final token = await _storage.getToken();
    final roomName = "user_$userId"; 
    
    if (_socket != null && _socket!.connected) {
      debugPrint("🟡 Socket déjà connecté, room: $roomName");
      return;
    }

    if (_socket != null && !_socket!.connected) {
      _socket!.connect();
      return;
    }

    _socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .setAuth({'token': token})
        .build()
    );

    // ✅ IMPORTANT: Ne pas joindre la room AVANT que onConnect soit appelé
    _socket!.onConnect((_) {
      _isConnected = true;  // ✅ NOUVEAU: Marquer comme connecté
      debugPrint('🟢 Socket connecté. Rejoins room: $roomName');
      _socket!.emit('join', roomName);
    });
    
    _socket!.onReconnect((_) {
      _isConnected = true;
      _socket!.emit('join', roomName);
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('🔌 Socket déconnecté');
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      debugPrint('❌ Erreur Socket: $err');
    });

    // ✅ Écoute du nouvel événement
    _socket!.on('new_message', (data) => _onMessageReceived(data));
  }

  // ✅ Système de callback amélioré
  Function(Map<String, dynamic>)? _messageHandler;

  VoidCallback onMessage(Function(Map<String, dynamic>) callback) {
    _messageHandler = callback;
    return () => _messageHandler = null;
  }

  void _onMessageReceived(dynamic data) {
    debugPrint('📩 Message reçu via Socket: $data');
    if (_messageHandler != null) {
      _messageHandler!(Map<String, dynamic>.from(data));
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _isConnected = false;
    debugPrint("🔌 Socket déconnecté manuellement");
  }
}
```

---

### Step 3: Corriger chat_controller.dart

```dart
// ✅ VERSION CORRIGÉE - chat_controller.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/user/user_provider.dart';
import 'socket_service.dart';

class ChatState {
  final bool isLoading;
  final List<Map<String, dynamic>> messages;
  final String? conversationId;
  final String? error;

  ChatState({
    this.isLoading = true,
    this.messages = const [],
    this.conversationId,
    this.error,
  });

  ChatState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? messages,
    String? conversationId,
    String? error,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
      error: error ?? this.error,
    );
  }
}

final chatControllerProvider = StateNotifierProvider.family<ChatController, ChatState, String>(
  (ref, otherUserId) {
    final socketService = ref.watch(socketServiceProvider);
    final user = ref.watch(userProvider).value;
    return ChatController(otherUserId, user?.id.toString(), socketService);
  },
);

class ChatController extends StateNotifier<ChatState> {
  final String otherUserId;
  final String? myId;
  final SocketService _socketService;
  final _storage = SecureStorageService();
  VoidCallback? _socketCleanup;

  ChatController(this.otherUserId, this.myId, this._socketService) : super(ChatState()) {
    _init();
  }

  Future<void> _init() async {
    await loadMessages();
    
    // ✅ Attendre que le socket soit vraiment connecté avant d'enregistrer le handler
    if (!_socketService.isConnected) {
      debugPrint("⏳ Attente de la connexion Socket...");
      // Attendre max 5 secondes
      int attempts = 0;
      while (!_socketService.isConnected && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (!_socketService.isConnected) {
        debugPrint("⚠️ Socket n'est pas connecté après 5s");
      }
    }

    _socketCleanup = _socketService.onMessage((data) {
      final incomingConvId = data['conversation_id']?.toString();
      final senderId = data['sender_id']?.toString();

      // Filtrage
      bool isRelevant = (state.conversationId != null && incomingConvId == state.conversationId) ||
                        (senderId == otherUserId);

      if (isRelevant) {
        if (state.conversationId == null && incomingConvId != null) {
          state = state.copyWith(conversationId: incomingConvId);
        }
        // ✅ Ajouter au début (messages les plus récents en haut)
        state = state.copyWith(messages: [data, ...state.messages]);
      }
    });
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true);
    final token = await _storage.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/messages/$otherUserId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> msgs = data['messages'] ?? [];
        final convId = msgs.isNotEmpty ? msgs.first['conversation_id']?.toString() : null;
        
        state = state.copyWith(
          messages: List<Map<String, dynamic>>.from(msgs),
          conversationId: convId,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> sendMessage({
    required String content,
    String type = 'text',
    String? productId,
  }) async {
    if (content.trim().isEmpty) return;
    
    final token = await _storage.getToken();
    
    try {
      // ✅ CORRECTION: Utiliser le bon endpoint en fonction de conversationId
      final endpoint = state.conversationId == null ? '/chat/send' : '/chat/messages';
      
      final body = {
        'recipientId': otherUserId,
        'content': content,
        'type': type,
        if (state.conversationId != null) 'conversationId': state.conversationId,
        if (productId != null) 'productId': productId,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chat$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // ✅ Mettre à jour conversationId si c'était une nouvelle conversation
        if (state.conversationId == null && data['conversationId'] != null) {
          state = state.copyWith(conversationId: data['conversationId']);
        }

        debugPrint("✅ Message envoyé avec succès");
      } else {
        state = state.copyWith(error: "Erreur d'envoi: ${response.statusCode}");
        debugPrint("❌ Erreur envoi: ${response.body}");
      }
    } catch (e) {
      state = state.copyWith(error: "Erreur: $e");
      debugPrint("❌ Erreur envoi: $e");
    }
  }

  @override
  void dispose() {
    _socketCleanup?.call();
    super.dispose();
  }
}
```

---

## FAILLE 4: Ajouter Validation de Token

### Step 4: Corriger server.js

```javascript
// ✅ VERSION CORRIGÉE - src/server.js (sections pertinentes)

// --- SOCKET.IO AUTH MIDDLEWARE ---
io.use((socket, next) => {
    const token = (socket.handshake.auth && socket.handshake.auth.token)
        || socket.handshake.headers.authorization;

    if (!token) {
        console.warn("❌ [SOCKET] Pas de token fourni");
        return next(new Error("No authentication token"));
    }

    const cleanToken = token.replace("Bearer ", "");
    try {
        const decoded = jwt.verify(cleanToken, config.JWT_SECRET, {
            ignoreExpiration: false  // ✅ NOUVEAU: Vérifier l'expiration
        });
        socket.user = decoded;
        console.log(`✅ [SOCKET] User ${decoded.id} authentifié`);
        next();
    } catch (err) {
        console.warn(`❌ [SOCKET] Échec auth : ${err.message}`);
        // ✅ NOUVEAU: Accepter token expiré et laisser le client faire refresh
        if (err.name === 'TokenExpiredError') {
            return next(new Error("Token expired - please refresh"));
        }
        next(new Error("Authentication error"));
    }
});

// --- SOCKET.IO EVENTS ---
io.on('connection', (socket) => {
    const userId = socket.user ? socket.user.id : null;

    if (!userId) {
        console.warn("⚠️ [SOCKET] Connexion sans user_id");
        socket.disconnect();
        return;
    }

    const userRoom = `user_${userId}`;
    socket.join(userRoom);
    console.log(`✅ Room rejoint : ${userRoom}`);

    io.emit('user_online', { userId, online: true });

    // ... reste du code ...
});
```

---

## 📋 CHECKLIST DE DÉPLOIEMENT

- [ ] Remplacer `conversations_page.dart`
- [ ] Remplacer `socket_service.dart` 
- [ ] Remplacer `chat_controller.dart`
- [ ] Mettre à jour `server.js` pour la validation de token
- [ ] Supprimer toute référence à Firestore dans le chat
- [ ] Tester envoi/réception de messages en local
- [ ] Vérifier les logs WebSocket dans DevTools
- [ ] Tester conversation existante
- [ ] Tester nouvelle conversation
- [ ] Tester reconnexion après déconnexion
- [ ] Déployer sur production

---

## 🧪 TEST LOCAL

```bash
# Terminal 1: Lancer le serveur Node
cd oli-core
npm install
npm start

# Terminal 2: Lancer l'app Flutter
cd oli_app
flutter pub get
flutter run -d web

# Dans l'app:
# 1. Se connecter
# 2. Ouvrir le chat
# 3. Envoyer un message
# 4. DevTools Console doit afficher: "✅ Message envoyé avec succès"
# 5. Server logs doit afficher: "📩 Message reçu via Socket"
```
