import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import '../../config/api_config.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/user/user_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'socket_service.dart';

class ChatState {
  final bool isLoading;
  final List<Map<String, dynamic>> messages;
  final int? conversationId;
  final String? error;
  final String? friendshipStatus;
  final int? requesterId;

  ChatState({
    this.isLoading = true, 
    this.messages = const [], 
    this.conversationId,
    this.error,
    this.friendshipStatus,
    this.requesterId,
    this.isOtherUserOnline = false,
    this.isOtherUserTyping = false,
  });

  final bool isOtherUserOnline;
  final bool isOtherUserTyping;

  ChatState copyWith({
    bool? isLoading, 
    List<Map<String, dynamic>>? messages, 
    int? conversationId,
    String? error,
    String? friendshipStatus,
    int? requesterId,
    bool? isOtherUserOnline,
    bool? isOtherUserTyping,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
      error: error,
      friendshipStatus: friendshipStatus ?? this.friendshipStatus,
      requesterId: requesterId ?? this.requesterId,
      isOtherUserOnline: isOtherUserOnline ?? this.isOtherUserOnline,
      isOtherUserTyping: isOtherUserTyping ?? this.isOtherUserTyping,
    );
  }
}

final chatControllerProvider = StateNotifierProvider.family<ChatController, ChatState, String>((ref, otherUserId) {
  final user = ref.watch(userProvider).value;
  final socketService = ref.watch(socketServiceProvider);
  return ChatController(otherUserId, user?.id.toString(), socketService, ref);
});

class ChatController extends StateNotifier<ChatState> {
  final String otherUserId;
  final String? myId;
  final SocketService _socketService;
  final Ref _ref;
  final Dio _dio = Dio();
  final _storage = SecureStorageService();
  VoidCallback? _socketUnsubscribe;
  String? _productId;

  ChatController(this.otherUserId, this.myId, this._socketService, this._ref) : super(ChatState()) {
    _initChat();
  }

  Future<void> _initChat() async {
    if (myId == null) {
      state = state.copyWith(isLoading: false, error: "Non connecté");
      return;
    }

    try {
      // Connecter le socket et écouter les nouveaux messages
      await _socketService.connect(myId!);
      _socketUnsubscribe = _socketService.onMessage(_handleNewMessage);
      
      // Écouter les reçus de lecture
      _socketService.on('messages_read', _handleMessagesRead);
      
      // Écouter le statut en ligne (global ou spécifique)
      _socketService.on('user_online', _handleUserOnline);

      // Écouter le typing
      _socketService.on('user_typing', _handleUserTyping);
      
      // Charger les messages depuis le backend
      await loadMessages();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    final senderId = data['sender_id']?.toString();
    
    // Vérifier si le message nous concerne
    if (senderId == otherUserId || senderId == myId) {
      final incomingId = data['id']?.toString();
      
      // 1. Déduplication stricte par ID (String vs Int fix)
      final existingIds = state.messages.map((m) => m['id']?.toString()).toSet();
      if (incomingId != null && existingIds.contains(incomingId)) {
        return; 
      }

      // 2. Gestion Optimiste : Remplacement du message temporaire par le réel
      if (senderId == myId) {
        // On cherche un message temporaire avec le même contenu ET qui est récent (pour éviter les faux positifs)
        final pendingIndex = state.messages.lastIndexWhere((m) {
          final isOptimistic = m['id'] != null && m['id'].toString().startsWith('temp_');
          // Comparaison simple sur le contenu. Idéalement on utiliserait un UUID temporaire envoyé au back.
          return isOptimistic && m['content'] == data['content'];
        });

        if (pendingIndex != -1) {
          final newMessages = List<Map<String, dynamic>>.from(state.messages);
          newMessages[pendingIndex] = data; // Remplacement in-place
          state = state.copyWith(messages: newMessages);
          return;
        }
      }

      // Sinon, ajout normal
      state = state.copyWith(
        messages: [...state.messages, data],
      );
    }
  }

  void _handleMessagesRead(dynamic rawData) {
    if (rawData is! Map<String, dynamic>) return;
    final data = rawData;
    
    // Si l'autre utilisateur a lu la conversation
    if (data['conversation_id'] == state.conversationId && data['reader_id'].toString() == otherUserId) {
      // On marque tous NOS messages comme lus
      final updatedMessages = state.messages.map((m) {
        if (m['sender_id'].toString() == myId && (m['is_read'] == false || m['is_read'] == null)) {
          return {...m, 'is_read': true};
        }
        return m;
      }).toList();
      
      state = state.copyWith(messages: updatedMessages);
    }
  }

  void _handleUserOnline(dynamic data) {
    if (data is Map && data['userId'].toString() == otherUserId) {
      state = state.copyWith(isOtherUserOnline: data['online'] == true);
    }
  }

  void _handleUserTyping(dynamic data) {
    if (data is Map && data['userId'].toString() == otherUserId) {
       state = state.copyWith(isOtherUserTyping: data['isTyping'] == true);
    }
  }
  
  void sendTyping(bool isTyping) {
    if (state.conversationId != null) {
      _socketService.emit('typing', {
        'conversationId': state.conversationId,
        'isTyping': isTyping
      });
    }
  }

  Future<void> loadMessages({String? productId}) async {
    _productId = productId ?? _productId;
    
    try {
      final token = await _storage.getToken();
      
      String url = '${ApiConfig.baseUrl}/chat/messages/$otherUserId';
      if (_productId != null) {
        url += '?productId=$_productId';
      }
      
      final response = await _dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        
        int? convId;
        String? friendshipStatus;
        int? requesterId;
        
        if (messages.isNotEmpty) {
          convId = messages.first['conversation_id'];
          friendshipStatus = messages.first['friendship_status'];
          requesterId = messages.first['requester_id'];
        }
        
        state = state.copyWith(
          isLoading: false,
          messages: messages,
          conversationId: convId,
          friendshipStatus: friendshipStatus,
          requesterId: requesterId,
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur loadMessages: $e');
      state = state.copyWith(isLoading: false, error: "Erreur de chargement: $e");
    }
  }

  Future<String?> uploadImage(XFile file) async {
    try {
      final token = await _storage.getToken();
      
      final fileName = file.name;
      final fileBytes = await file.readAsBytes();
      final mimeType = file.mimeType;

      FormData formData = FormData.fromMap({
        'chat_file': MultipartFile.fromBytes(
          fileBytes, 
          filename: fileName,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        ),
      });

      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chat/upload',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        return response.data['mediaUrl']; 
      }
    } catch (e) {
      debugPrint('❌ Erreur uploadImage: $e');
    }
    return null;
  }

  Future<void> sendMessage({
    required String content,
    String type = 'text',
    String? mediaUrl,
    String? mediaType,
    String? productId,
    String? productName,
    String? productImage,
    double? productPrice,
    Map<String, dynamic>? customMetadata,
  }) async {
    // Si pas de contenu, pas de média, et pas de metadata custom, on n'envoie rien
    if ((content.trim().isEmpty && mediaUrl == null && customMetadata == null) || myId == null) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Ajout Optimiste Immédiat
    final optimisticMessage = {
      'id': tempId,
      'sender_id': int.parse(myId!),
      'content': content.isEmpty && mediaUrl != null 
          ? (mediaType == 'image' ? '📷 Image' : '📎 Fichier') 
          : (type == 'location' ? '📍 Position partagée' : content),
      'type': type,
      'created_at': DateTime.now().toIso8601String(),
      'metadata': jsonEncode({
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaUrl != null) 'mediaType': mediaType ?? 'file',
        ...?customMetadata,
      })
    };
    
    // On ajoute tout de suite
    state = state.copyWith(messages: [...state.messages, optimisticMessage]);

    try {
      final token = await _storage.getToken();
      
      dynamic data;
      String url;

      final Map<String, dynamic> metadata = {
          if (productName != null) 'product_name': productName,
          if (productImage != null) 'product_image': productImage,
          if (productPrice != null) 'product_price': productPrice,
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
          if (mediaUrl != null) 'mediaType': mediaType ?? 'file',
          ...?customMetadata,
      };

      if (state.conversationId == null) {
        url = '${ApiConfig.baseUrl}/chat/send';
        data = {
          'recipientId': int.parse(otherUserId),
          'content': content,
          'type': type,
          'mediaUrl': mediaUrl,
          'mediaType': mediaType,
          'productId': productId != null ? int.parse(productId) : null,
          'metadata': metadata,
        };
      } else {
        url = '${ApiConfig.baseUrl}/chat/messages';
        data = {
          'conversationId': state.conversationId,
          'recipientId': int.parse(otherUserId),
          'content': content,
          'type': type,
          'mediaUrl': mediaUrl,
          'mediaType': mediaType,
          'metadata': metadata,
        };
      }

      final response = await _dio.post(
        url,
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (response.statusCode == 200) {
        final resData = response.data;
        // Mise à jour des infos de conversation si c'est le premier message
        if (state.conversationId == null) {
          state = state.copyWith(
            conversationId: resData['conversationId'],
            friendshipStatus: resData['friendship_status'],
            requesterId: resData['requester_id'],
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur sendMessage: $e');
      state = state.copyWith(
        error: "Erreur d'envoi",
        messages: state.messages.where((m) => m['id'] != tempId).toList(), // Retrait si erreur
      );
    }
  }

  @override
  void dispose() {
    _socketUnsubscribe?.call();
    super.dispose();
  }
}