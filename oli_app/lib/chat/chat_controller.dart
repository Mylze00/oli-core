import 'dart:ui'; // For VoidCallback
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../secure_storage_service.dart';
import 'socket_service.dart';
import '../core/user/user_provider.dart';

// ... (providers and state definitions remain the same) ...
// Wait, I can only replace one block.
// I will split this into two edits if needed, or use multi_replace.
// Let's use multi_replace.

// --- PROVIDERS ---


final chatControllerProvider = StateNotifierProvider.family<ChatController, ChatState, String>((ref, otherUserId) {
  final socketService = ref.watch(socketServiceProvider);
  final user = ref.watch(userProvider).value;
  return ChatController(otherUserId, user?.id.toString(), socketService);
});

// --- STATE ---

class ChatState {
  final bool isLoading;
  final List<Map<String, dynamic>> messages;
  final String? conversationId;
  final String? friendshipStatus; // 'pending', 'accepted'
  final String? requesterId;      // Qui a initié la conversation
  final String? error;

  ChatState({
    this.isLoading = true,
    this.messages = const [],
    this.conversationId,
    this.friendshipStatus,
    this.requesterId,
    this.error,
  });

  ChatState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? messages,
    String? conversationId,
    String? friendshipStatus,
    String? requesterId,
    String? error,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
      friendshipStatus: friendshipStatus ?? this.friendshipStatus,
      requesterId: requesterId ?? this.requesterId,
      error: error,
    );
  }
}

// --- CONTROLLER ---

class ChatController extends StateNotifier<ChatState> {
  final String otherUserId;
  final String? myId; // Ajout
  final SocketService socketService;
  final _storage = SecureStorageService();
  VoidCallback? _socketCleanup;

  ChatController(this.otherUserId, this.myId, this.socketService) : super(ChatState()) {
    _init();
  }

  Future<void> _init() async {
    await _connectSocket();
    await loadMessages();
  }

  Future<void> _connectSocket() async {
    if (myId != null) {
      await socketService.connect(myId!);
    }
    
    // Écoute des messages avec filtrage robuste
    _socketCleanup = socketService.onMessage((data) {
       print("Données reçues par socket: $data");

       // Cas : Request Accepted
       if (data['type'] == 'request_accepted' && data['by'].toString() == otherUserId) {
         state = state.copyWith(friendshipStatus: 'accepted');
         return;
       }
       
       final senderId = (data['sender_id'] ?? data['senderId']).toString();
       final convId = (data['conversation_id'] ?? data['conversationId']).toString();

       // Si le message vient de l'autre ou concerne cette conv
       if (senderId == otherUserId || 
           (state.conversationId != null && convId == state.conversationId)) {
         addMessage(data);
       }
    });
  }

  Future<void> loadMessages({String? productId, String? conversationId}) async {
    state = state.copyWith(isLoading: true, error: null);

    if (conversationId != null) {
      state = state.copyWith(conversationId: conversationId);
    }
    final token = await _storage.getToken();

    String urlStr = '${ApiConfig.baseUrl}/chat/messages/$otherUserId';
    if (productId != null) {
      urlStr += '?productId=$productId';
    }

    try {
      final response = await http.get(
        Uri.parse(urlStr), 
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final messages = data.map((e) => e as Map<String, dynamic>).toList();
        
        String? convId;
        String? friendshipStatus;
        String? requesterId;
        
        if (messages.isNotEmpty) {
          convId = messages[0]['conversation_id']?.toString();
          friendshipStatus = messages[0]['friendship_status']?.toString();
          requesterId = messages[0]['requester_id']?.toString();
        }

        state = state.copyWith(
          messages: messages,
          conversationId: convId,
          friendshipStatus: friendshipStatus,
          requesterId: requesterId,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: "Erreur chargement messages");
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> acceptConversation() async {
    final token = await _storage.getToken();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chat/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'requesterId': state.requesterId}),
      );

      if (response.statusCode == 200) {
        state = state.copyWith(friendshipStatus: 'accepted');
      }
    } catch (e) {
      print("Erreur acceptation: $e");
    }
  }

  Future<void> sendMessage({
    required String content,
    String? type = 'text',
    double? amount,
    String? productId,
    int? replyToId, // Support des réponses
  }) async {
    final token = await _storage.getToken();
    if (token == null) return;

    // 1. Si TYPE IMAGE, uploader d'abord
    String finalContent = content;
    if (type == 'image') {
      try {
        final imageUrl = await _uploadImage(content, token); // content est le path ici
        if (imageUrl == null) {
          state = state.copyWith(error: "Echec upload image");
          return;
        }
        finalContent = imageUrl;
      } catch (e) {
        state = state.copyWith(error: "Erreur upload: $e");
        return;
      }
    } else {
      if (content.trim().isEmpty && amount == null) return;
    }
    
    // 2. Envoyer le message
    final isNewRequest = state.messages.isEmpty && state.conversationId == null;
    final endpoint = isNewRequest ? '/chat/request' : '/chat/messages';

    final body = {
        'recipientId': otherUserId,
        'content': finalContent,
        'type': type,
        if (amount != null) 'amount': amount,
        if (replyToId != null) 'replyToId': replyToId,  // Ajout
        if (state.conversationId != null) 'conversationId': state.conversationId,
        if (productId != null) 'productId': productId,
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final newMsg = jsonDecode(response.body);
        final msgData = newMsg['message'] ?? newMsg; 
        
        addMessage(msgData);

        if (state.conversationId == null && msgData['conversation_id'] != null) {
          state = state.copyWith(
            conversationId: msgData['conversation_id'].toString(),
            friendshipStatus: 'pending',
            requesterId: msgData['sender_id'].toString(), // C'est moi qui ai envoyé
          );
        }
        
        // Si c'était un pending et que j'ai pu envoyer (parce que je suis l'addressee), ça devient accepted
        if (state.friendshipStatus == 'pending' && state.requesterId != otherUserId) {
           state = state.copyWith(friendshipStatus: 'accepted');
        }
      } else if (response.statusCode == 403) {
         final data = jsonDecode(response.body);
         state = state.copyWith(error: data['error'] ?? "Accès refusé");
      } else {
         state = state.copyWith(error: "Erreur envoi: ${response.statusCode}");
      }
    } catch (e) {
       state = state.copyWith(error: "Erreur réseau: $e");
    }
  }

  Future<String?> _uploadImage(String filePath, String token) async {
    final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/chat/upload'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('image', filePath));
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['url'];
    }
    return null;
  }

  void addMessage(Map<String, dynamic> msg) {
    if (state.messages.any((m) => m['id'] == msg['id'])) return;

    state = state.copyWith(
      messages: [...state.messages, msg],
    );
  }


  @override
  void dispose() {
    _socketCleanup?.call(); // Unsubscribe only
    super.dispose();
  }
}
