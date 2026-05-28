import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../config/api_config.dart';
import '../../../../models/shop_model.dart';
import '../../../../core/services/hive_cache_service.dart'; // [CACHE]

// Provider global
final verifiedShopsProvider = StateNotifierProvider<VerifiedShopsNotifier, AsyncValue<List<Shop>>>((ref) {
  return VerifiedShopsNotifier();
});

class VerifiedShopsNotifier extends StateNotifier<AsyncValue<List<Shop>>> {
  VerifiedShopsNotifier() : super(const AsyncValue.loading()) {
    fetchVerifiedShops();
  }

  Future<void> fetchVerifiedShops() async {
    const cacheKey = 'verified_shops_cache';
    
    // [CACHE] 1. Lecture rapide du cache
    final cachedData = HiveCacheService.getCache(cacheKey);
    if (cachedData != null) {
      try {
        final List<dynamic> data = cachedData;
        final shops = data.map((item) => Shop.fromJson(item)).toList();
        state = AsyncValue.data(shops); // Affichage instantané
      } catch (e) {
        debugPrint("❌ Erreur parsing cache shops: $e");
      }
    } else {
      state = const AsyncValue.loading();
    }

    // 2. Rafraîchissement en arrière-plan
    try {
      final uri = Uri.parse('${ApiConfig.shops}/verified?limit=10');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final shops = data.map((item) => Shop.fromJson(item)).toList();
        
        if (shops.isNotEmpty) {
           debugPrint("✅ ${shops.length} boutiques vérifiées chargées depuis réseau");
        }
        
        state = AsyncValue.data(shops);
        
        // [CACHE] 3. Mise à jour silencieuse
        await HiveCacheService.setCache(cacheKey, data);
      } else {
        if (!state.hasValue) {
          state = AsyncValue.error("Erreur serveur: ${response.statusCode}", StackTrace.current);
        }
      }
    } catch (e, st) {
      debugPrint("❌ Exception fetchVerifiedShops: $e");
      if (!state.hasValue) {
        state = AsyncValue.error("Erreur: $e", st);
      }
    }
  }
}
