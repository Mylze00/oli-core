import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/visited_product_model.dart';

// --- STATE ---
class UserActivityState {
  final List<VisitedProduct> visitedProducts;
  final bool isLoading;
  final String? error;

  UserActivityState({
    this.visitedProducts = const [],
    this.isLoading = false,
    this.error,
  });

  UserActivityState copyWith({
    List<VisitedProduct>? visitedProducts,
    bool? isLoading,
    String? error,
  }) {
    return UserActivityState(
      visitedProducts: visitedProducts ?? this.visitedProducts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// --- PROVIDER ---
final userActivityProvider = StateNotifierProvider<UserActivityNotifier, UserActivityState>((ref) {
  return UserActivityNotifier();
});

// --- NOTIFIER ---
class UserActivityNotifier extends StateNotifier<UserActivityState> {
  final _storage = SecureStorageService();

  UserActivityNotifier() : super(UserActivityState());

  /// Charge les produits visités depuis l'API
  Future<void> fetchVisitedProducts({int limit = 20}) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final token = await _storage.getToken();
      if (token == null) throw Exception("Non authentifié");

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/user/visited-products?limit=$limit'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final products = data.map((json) => VisitedProduct.fromJson(json)).toList();
        
        state = state.copyWith(
          isLoading: false,
          visitedProducts: products,
        );
      } else {
        throw Exception('Erreur de chargement des produits visités');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Enregistre une vue de produit
  Future<void> trackProductView(int productId) async {
    try {
      final token = await _storage.getToken();
      if (token == null) return; // Silently fail if not authenticated

      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/user/track-view/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      // Optionally refresh the list
      // await fetchVisitedProducts();
    } catch (e) {
      // Silently fail - tracking is not critical
      print('Erreur tracking view: $e');
    }
  }
}
