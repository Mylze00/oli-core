import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../config/api_config.dart';
import '../../../../models/shop_model.dart';

// Provider global
final verifiedShopsProvider = StateNotifierProvider<VerifiedShopsNotifier, AsyncValue<List<Shop>>>((ref) {
  return VerifiedShopsNotifier();
});

class VerifiedShopsNotifier extends StateNotifier<AsyncValue<List<Shop>>> {
  VerifiedShopsNotifier() : super(const AsyncValue.loading()) {
    fetchVerifiedShops();
  }

  Future<void> fetchVerifiedShops() async {
    state = const AsyncValue.loading();

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/shops/verified?limit=10');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final shops = data.map((item) => Shop.fromJson(item)).toList();
        
        if (shops.isNotEmpty) {
           debugPrint("✅ ${shops.length} boutiques vérifiées chargées");
        }
        
        state = AsyncValue.data(shops);
      } else {
        debugPrint("❌ Erreur fetchVerifiedShops: ${response.statusCode}");
        state = AsyncValue.error("Erreur serveur: ${response.statusCode}", StackTrace.current);
      }
    } catch (e, st) {
      debugPrint("❌ Exception fetchVerifiedShops: $e");
      state = AsyncValue.error("Erreur: $e", st);
    }
  }
}
