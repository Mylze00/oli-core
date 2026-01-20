import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../config/api_config.dart';
import '../../../../models/shop_model.dart';

// Provider global
final verifiedShopsProvider = StateNotifierProvider<VerifiedShopsNotifier, List<Shop>>((ref) {
  return VerifiedShopsNotifier();
});

class VerifiedShopsNotifier extends StateNotifier<List<Shop>> {
  bool _isLoading = false;
  String? _error;

  VerifiedShopsNotifier() : super([]) {
    fetchVerifiedShops();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchVerifiedShops() async {
    _isLoading = true;
    _error = null;

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/shops/verified?limit=10');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final shops = data.map((item) => Shop.fromJson(item)).toList();
        
        if (shops.isNotEmpty) {
           debugPrint("✅ ${shops.length} boutiques vérifiées chargées");
        }
        
        state = shops;
      } else {
        _error = "Erreur serveur: ${response.statusCode}";
        debugPrint("❌ Erreur fetchVerifiedShops: ${response.statusCode}");
      }
    } catch (e) {
      _error = "Erreur: $e";
      debugPrint("❌ Exception fetchVerifiedShops: $e");
    } finally {
      _isLoading = false;
    }
  }
}
