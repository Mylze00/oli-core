import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../config/api_config.dart';
import '../../../core/user/user_provider.dart';
import '../../../core/router/network/dio_provider.dart';
import '../../../core/services/hive_cache_service.dart';

final callHistoryProvider = StateNotifierProvider<CallHistoryNotifier, AsyncValue<List<dynamic>>>((ref) {
  return CallHistoryNotifier(ref);
});

class CallHistoryNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final Ref ref;

  CallHistoryNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchCallHistory();
  }

  Future<void> fetchCallHistory() async {
    final user = ref.read(userProvider).value;
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }

    final cacheKey = 'call_history_cache_${user.id}';

    // 1. Charger depuis le cache (Offline-first)
    if (!state.hasValue || state.value!.isEmpty) {
      try {
        final cachedData = HiveCacheService.getCache(cacheKey);
        if (cachedData != null) {
          final data = jsonDecode(cachedData);
          state = AsyncValue.data(List<dynamic>.from(data));
        }
      } catch (e) {
        // Ignorer les erreurs de cache
      }
    }

    // 2. Fetch API
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/calls/history');
      
      if (response.statusCode == 200) {
        state = AsyncValue.data(response.data);
        // Sauvegarder dans le cache
        HiveCacheService.setCache(cacheKey, jsonEncode(response.data));
      } else if (!state.hasValue) {
        state = AsyncValue.error('Erreur de chargement', StackTrace.current);
      }
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }
}
