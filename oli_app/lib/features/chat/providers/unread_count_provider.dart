import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';

/// Retourne le nombre total de messages non lus (somme de toutes les conversations)
/// Poll toutes les 20 secondes en arrière-plan.
class UnreadCountNotifier extends StateNotifier<int> {
  Timer? _pollTimer;
  final _storage = SecureStorageService();

  UnreadCountNotifier() : super(0) {
    _fetch();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final token = await _storage.getToken();
      if (token == null) return;

      final uri = Uri.parse(ApiConfig.chatConversations);
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      });

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final total = data.fold<int>(
          0,
          (sum, conv) => sum + (int.tryParse(conv['unread_count'].toString()) ?? 0),
        );
        if (total != state) state = total;
      }
    } catch (e) {
      debugPrint('UnreadCount fetch error: $e');
    }
  }

  /// Appelé quand l'utilisateur ouvre l'onglet Messages → refresh immédiat
  void refresh() => _fetch();

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final unreadCountProvider =
    StateNotifierProvider<UnreadCountNotifier, int>((ref) => UnreadCountNotifier());
