import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';
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
      error: error ?? this.error,
    );
  }
}

// --- PROVIDER ---
final userActivityProvider = StateNotifierProvider<UserActivityNotifier, UserActivityState>((ref) {
  return UserActivityNotifier(ref);
});

// --- NOTIFIER ---
class UserActivityNotifier extends StateNotifier<UserActivityState> {
  final Ref _ref;

  UserActivityNotifier(this._ref) : super(UserActivityState());

  Dio get _dio => _ref.read(dioProvider);

  /// Charge les produits visités depuis l'API
  Future<void> fetchVisitedProducts({int limit = 20}) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/user/visited-products',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200) {
        final List data = response.data is List ? response.data : [];
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

  /// Alias pour trackProductView compatible avec l'appel UI
  Future<void> addToVisited(dynamic product) async {
      if (product == null) return;
      try {
        final idStr = product is int ? product.toString() : product.id.toString();
        final id = int.tryParse(idStr);
        
        if (id != null) {
          await trackProductView(id);
        } else {
          debugPrint("⚠️ Impossible de tracker le produit: ID invalide ($idStr)");
        }
      } catch (e) {
        debugPrint("⚠️ Erreur addToVisited: $e");
      }
  }

  /// Enregistre une vue de produit
  Future<void> trackProductView(int productId) async {
    try {
      await _dio.post('${ApiConfig.baseUrl}/user/track-view/$productId');
    } catch (e) {
      // Silently fail - tracking is not critical
      debugPrint('Erreur tracking view: $e');
    }
  }
}
