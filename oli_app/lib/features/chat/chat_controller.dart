import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/user/user_provider.dart';
import 'socket_service.dart';
class ChatState {
  final bool isLoading;
  final List<Map<String, dynamic>> messages;
  final String? conversationId;

  ChatState({this.isLoading = true, this.messages = const [], this.conversationId});

  ChatState copyWith({bool? isLoading, List<Map<String, dynamic>>? messages, String? conversationId}) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
    );
  }
}

final chatControllerProvider = StateNotifierProvider.family<ChatController, ChatState, String>((ref, otherUserId) {
  final user = ref.watch(userProvider).value;
  return ChatController(otherUserId, user?.id.toString());
});

class ChatController extends StateNotifier<ChatState> {
  final String otherUserId;
  final String? myId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ChatController(this.otherUserId, this.myId) : super(ChatState()) {
    _initChat();
  }

  void _initChat() {
    if (myId == null) return;

    // Déterminer un ID de conversation unique entre les deux utilisateurs
    final List<String> ids = [myId!, otherUserId]..sort();
    final convId = ids.join('_');
    state = state.copyWith(conversationId: convId);

    // Écoute en temps réel
    _firestore
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      final messages = snapshot.docs.map((doc) => doc.data()).toList();
      state = state.copyWith(messages: messages, isLoading: false);
    });
  }

  Future<void> sendMessage({
    required String content,
    String type = 'text',
    String? productId,
    String? productName,
    String? productImage,
    double? productPrice,
  }) async {
    if (content.trim().isEmpty || myId == null || state.conversationId == null) return;

    final convRef = _firestore.collection('conversations').doc(state.conversationId);

    // 1. Mettre à jour/Créer le document de conversation (pour la liste des conversations)
    await convRef.set({
      'participants': [myId, otherUserId],
      'last_message': content,
      'last_message_time': FieldValue.serverTimestamp(),
      // Sauvegarde des infos produit pour l'affichage dans l'onglet
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (productImage != null) 'product_image': productImage,
      if (productPrice != null) 'product_price': productPrice,
    }, SetOptions(merge: true));

    // 2. Ajouter le message
    await convRef.collection('messages').add({
      'sender_id': myId,
      'content': content,
      'type': type,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}