import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import '../../config/api_config.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/user/user_provider.dart';
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
  });

  ChatState copyWith({
    bool? isLoading, 
    List<Map<String, dynamic>>? messages, 
    int? conversationId,
    String? error,
    String? friendshipStatus,
    int? requesterId,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
      error: error,
      friendshipStatus: friendshipStatus ?? this.friendshipStatus,
      requesterId: requesterId ?? this.requesterId,
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
        return; // Déjà présent
      }

      // 2. Gestion Optimiste : Si c'est MON message, vérifier s'il existe déjà en "temp"
      if (senderId == myId) {
        final pendingIndex = state.messages.lastIndexWhere((m) {
          final isOptimistic = m['id'] == null || m['id'].toString().startsWith('temp_');
          return isOptimistic && m['content'] == data['content'];
        });

        if (pendingIndex != -1) {
          // On remplace le message optimiste par le vrai
          final newMessages = List<Map<String, dynamic>>.from(state.messages);
          newMessages[pendingIndex] = data;
          state = state.copyWith(messages: newMessages);
          return;
        }
      }

      // Sinon, on ajoute simplement à la fin
      state = state.copyWith(
        messages: [...state.messages, data],
      );
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

  Future<String?> uploadImage(dynamic fileObj) async {
    try {
      final token = await _storage.getToken();
      
      String fileName;
      List<int> fileBytes;
      String? mimeType;
      
      // Support pour XFile (mobile/web) ou File (mobile)
      if (fileObj.runtimeType.toString().contains('XFile')) {
         fileName = fileObj.name;
         fileBytes = await fileObj.readAsBytes();
         mimeType = fileObj.mimeType;
      } else {
        // Fallback générique
         throw Exception("Type de fichier non supporté: ${fileObj.runtimeType}");
      }

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
  }) async {
    // Si pas de contenu et pas de média, on n'envoie rien
    if ((content.trim().isEmpty && mediaUrl == null) || myId == null) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Ajout Optimiste Immédiat
    final optimisticMessage = {
      'id': tempId,
      'sender_id': int.parse(myId!),
      'content': content.isEmpty && mediaUrl != null ? (mediaType == 'image' ? '📷 Image' : '📎 Fichier') : content,
      'type': type,
      'created_at': DateTime.now().toIso8601String(),
      'metadata': mediaUrl != null ? jsonEncode({
        'mediaUrl': mediaUrl,
        'mediaType': mediaType ?? 'file'
      }) : null
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