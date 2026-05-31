import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../storage/secure_storage_service.dart';
import '../services/hive_cache_service.dart';
import '../router/network/dio_provider.dart';
import 'user_model.dart';

final userProvider = StateNotifierProvider<UserNotifier, AsyncValue<User?>>((ref) {
  final dio = ref.read(dioProvider);
  return UserNotifier(dio);
});

class UserNotifier extends StateNotifier<AsyncValue<User?>> {
  final Dio dio;
  bool _isLoading = false;

  UserNotifier(this.dio) : super(const AsyncValue.loading()) {
    fetchUser();
  }

  Future<void> fetchUser() async {
    if (_isLoading) return;
    _isLoading = true;

    // --- CACHE OFFLINE-FIRST ---
    if (!state.hasValue) {
      try {
        final cachedData = await HiveCacheService.getCache('user_profile_cache');
        if (cachedData != null) {
          final data = jsonDecode(cachedData);
          final user = User.fromJson(data['user'] ?? data);
          state = AsyncValue.data(user);
          debugPrint('✅ [CACHE] Profil utilisateur chargé instantanément');
        }
      } catch (e) {
        debugPrint('⚠️ Erreur lecture cache profil: $e');
      }
    }

    try {
      final response = await dio.get(ApiConfig.authMe);

      if (response.statusCode == 200) {
        final data = response.data;
        final user = User.fromJson(data['user'] ?? data);
        state = AsyncValue.data(user);
        
        // Mise à jour du cache
        await HiveCacheService.setCache('user_profile_cache', jsonEncode(data));
      } else if (!state.hasValue) {
        state = AsyncValue.error('Erreur serveur: ${response.statusCode}', StackTrace.current);
      }
    } catch (e, st) {
      debugPrint('❌ Erreur chargement utilisateur: $e');
      if (!state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    } finally {
      _isLoading = false;
    }
  }

  // Permet de forcer le rafraîchissement
  Future<void> refresh() async {
    await fetchUser();
  }
}
