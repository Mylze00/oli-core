import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../models/product_model.dart';

/// État de pagination des produits d'une boutique
class ShopProductsState {
  final List<Product> products;
  final bool isLoading;
  final bool hasMore;
  final int currentOffset;
  final String? error;
  final String? currentFilter; // new, popular, promotions, ou null pour "all"
  final String? searchQuery; // Terme de recherche

  const ShopProductsState({
    this.products = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentOffset = 0,
    this.error,
    this.currentFilter,
    this.searchQuery,
  });

  ShopProductsState copyWith({
    List<Product>? products,
    bool? isLoading,
    bool? hasMore,
    int? currentOffset,
    String? error,
    String? currentFilter,
    String? searchQuery,
  }) {
    return ShopProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentOffset: currentOffset ?? this.currentOffset,
      error: error,
      currentFilter: currentFilter ?? this.currentFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Notifier pour gérer la pagination des produits d'une boutique
class ShopProductsNotifier extends StateNotifier<ShopProductsState> {
  final String shopId;
  static const int _pageSize = 100; // Limite de 100 produits par page

  ShopProductsNotifier(this.shopId) : super(const ShopProductsState()) {
    loadInitial();
  }

  /// Charge les 100 premiers produits
  Future<void> loadInitial({String? filterType, String? searchQuery}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentFilter: filterType,
      searchQuery: searchQuery,
    );

    try {
      final products = await _fetchProducts(
        offset: 0, 
        filterType: filterType ?? state.currentFilter,
        searchQuery: searchQuery ?? state.searchQuery,
      );
      
      state = ShopProductsState(
        products: products,
        isLoading: false,
        hasMore: products.length >= _pageSize,
        currentOffset: products.length,
        currentFilter: filterType,
        searchQuery: searchQuery,
      );
    } catch (e) {
      debugPrint("❌ Erreur loadInitial: $e");
      state = state.copyWith(
        isLoading: false,
        error: "Erreur de chargement: $e",
      );
    }
  }

  /// Charge la page suivante (100 produits supplémentaires)
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final newProducts = await _fetchProducts(
        offset: state.currentOffset,
        filterType: state.currentFilter,
        searchQuery: state.searchQuery,
      );

      state = state.copyWith(
        products: [...state.products, ...newProducts],
        isLoading: false,
        hasMore: newProducts.length >= _pageSize,
        currentOffset: state.currentOffset + newProducts.length,
      );
    } catch (e) {
      debugPrint("❌ Erreur loadMore: $e");
      state = state.copyWith(
        isLoading: false,
        error: "Erreur de chargement: $e",
      );
    }
  }

  /// Change de filtre et recharge depuis le début
  Future<void> changeFilter(String? filterType) async {
    if (state.currentFilter == filterType) return;
    await loadInitial(filterType: filterType, searchQuery: state.searchQuery);
  }

  /// Change de recherche et recharge
  Future<void> changeSearch(String query) async {
    if (state.searchQuery == query) return;
    await loadInitial(filterType: state.currentFilter, searchQuery: query);
  }

  /// Réinitialise l'état
  void reset() {
    state = const ShopProductsState();
  }

  /// Récupère les produits depuis l'API
  Future<List<Product>> _fetchProducts({
    required int offset,
    String? filterType,
    String? searchQuery,
  }) async {
    try {
      // Construction de l'URL avec paramètres
      var uri = '${ApiConfig.products}?shopId=$shopId&limit=$_pageSize&offset=$offset';
      
      // Ajout du filtre si présent
      if (filterType != null && filterType.isNotEmpty) {
        uri += '&filterType=$filterType';
      }

      // Ajout de la recherche si présente
      if (searchQuery != null && searchQuery.isNotEmpty) {
        uri += '&search=$searchQuery';
      }

      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        
        // Support des deux formats de réponse
        final List<dynamic> productsData;
        if (data is List) {
          // Ancien format: retourne directement un array
          productsData = data;
        } else if (data is Map && data['products'] is List) {
          // Nouveau format: retourne {products: [...], hasMore: bool}
          productsData = data['products'];
        } else {
          throw Exception("Format de réponse inattendu");
        }

        return productsData.map((item) => Product.fromJson(item)).toList();
      } else {
        throw Exception("Erreur serveur: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Erreur _fetchProducts: $e");
      throw Exception("Erreur chargement produits: $e");
    }
  }
}

/// Provider pour les produits d'une boutique avec pagination
final shopProductsNotifierProvider = StateNotifierProvider.family<
    ShopProductsNotifier, ShopProductsState, String>((ref, shopId) {
  return ShopProductsNotifier(shopId);
});

/// Provider legacy pour compatibilité (retourne juste les produits)
final shopProductsProvider = FutureProvider.family<List<Product>, String>((ref, shopId) async {
  // Attendre que le notifier charge les produits initiaux
  await Future.delayed(const Duration(milliseconds: 100));
  final state = ref.watch(shopProductsNotifierProvider(shopId));
  return state.products;
});
