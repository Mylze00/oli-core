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

  ChatState({this.isLoading = true, this.messages = const [], this.conversationId, this.error});

  ChatState copyWith({bool? isLoading, List<Map<String, dynamic>>? messages, String? conversationId, String? error}) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
      error: error ?? this.error,
    );
  }
}

final chatControllerProvider = StateNotifierProvider.family<ChatController, ChatState, String>((ref, otherUserId) {
  final socketService = ref.watch(socketServiceProvider);
  final user = ref.watch(userProvider).value;
  return ChatController(otherUserId, user?.id.toString(), socketService);
});

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
    _socketCleanup = _socketService.onMessage((data) {
      final incomingConvId = data['conversation_id']?.toString();
      final senderId = data['sender_id']?.toString();

      // Filtrage : On accepte si c'est la même conv ou si ça vient de l'autre utilisateur
      bool isRelevant = (state.conversationId != null && incomingConvId == state.conversationId) ||
                        (senderId == otherUserId);

      if (isRelevant) {
        if (state.conversationId == null && incomingConvId != null) {
          state = state.copyWith(conversationId: incomingConvId);
        }
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
        final convId = msgs.isNotEmpty ? msgs.first['conversation_id']?.toString() : null;
        state = state.copyWith(messages: List<Map<String, dynamic>>.from(msgs), conversationId: convId, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

Future<void> sendMessage({required String content, String type = 'text'}) async {    if (content.trim().isEmpty) return;
    final token = await _storage.getToken();
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chat/messages'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipientId': otherUserId,
          'conversationId': state.conversationId,
          'content': content,
          'type': 'text',
        }),
      );
    } catch (e) { debugPrint("Erreur envoi: $e"); }
  }

  @override
  void dispose() {
    _socketCleanup?.call();
    super.dispose();
  }
}