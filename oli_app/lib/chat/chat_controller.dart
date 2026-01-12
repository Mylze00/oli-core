import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/user/user_provider.dart';
import 'socket_service.dart';

// --- STATE ---
class ChatState {
  final bool isLoading;
  final List<Map<String, dynamic>> messages;
  final String? error;

  ChatState({this.isLoading = true, this.messages = const [], this.error});

  ChatState copyWith({bool? isLoading, List<Map<String, dynamic>>? messages, String? error}) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      error: error ?? this.error,
    );
  }
}

// --- PROVIDER ---
final chatControllerProvider = StateNotifierProvider.family<ChatController, ChatState, String>((ref, otherUserId) {
  final socketService = ref.watch(socketServiceProvider);
  final user = ref.watch(userProvider).value;
  return ChatController(otherUserId, user?.id.toString(), socketService);
});

// --- CONTROLLER ---
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
    _listenToSocket();
  }

  void _listenToSocket() {
    _socketCleanup = _socketService.onMessage((data) {
      // On vérifie si le message appartient à cette conversation
      final senderId = data['sender_id'].toString();
      if (senderId == otherUserId || senderId == myId) {
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
        final List<dynamic> msgs = data['messages'];
        state = state.copyWith(
          messages: List<Map<String, dynamic>>.from(msgs),
          isLoading: false
        );
      }
    } catch (e) {
      state = state.copyWith(error: "Erreur chargement: $e", isLoading: false);
    }
  }

  Future<void> sendMessage({required String content, String type = 'text'}) async {
    if (content.trim().isEmpty) return;
    final token = await _storage.getToken();
    try {
      // On n'ajoute pas le message localement ici, 
      // car le Socket le recevra et l'ajoutera via _listenToSocket
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chat/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipientId': otherUserId,
          'content': content,
          'type': type,
          // Ajoute ici le conversationId si tu l'as
        }),
      );
    } catch (e) {
      debugPrint("Erreur envoi: $e");
    }
  }

  @override
  void dispose() {
    _socketCleanup?.call();
    super.dispose();
  }
}