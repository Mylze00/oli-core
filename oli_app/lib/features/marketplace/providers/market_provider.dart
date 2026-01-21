import 'dart:convert';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../models/product_model.dart'; // Assuming this exists based on usage

class MarketState {
  final List<Product> products;
  final bool isLoading;
  final String? error;

  MarketState({
    this.products = const [],
    this.isLoading = false,
    this.error,
  });
}

class MarketProductsNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  MarketProductsNotifier() : super(const AsyncValue.loading()) {
    fetchProducts();
  }

  Future<void> fetchProducts({String? search, String? category}) async {
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (category != null && category.isNotEmpty) queryParams['category'] = category;

      final uri = Uri.parse('${ApiConfig.baseUrl}/products').replace(queryParameters: queryParams);
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final products = data.map((json) {
           // Handle dynamic to Product conversion safely
           // Assuming Product.fromJson exists
           return Product.fromJson(json);
        }).toList();
        state = AsyncValue.data(products);
      } else {
        state = AsyncValue.error('Erreur serveur ${response.statusCode}', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final marketProductsProvider = StateNotifierProvider<MarketProductsNotifier, AsyncValue<List<Product>>>((ref) {
  return MarketProductsNotifier();
});

/// Notifier pour les produits mis en avant (Featured) - Page Accueil
class FeaturedProductsNotifier extends StateNotifier<List<Product>> {
  Timer? _refreshTimer;
  bool _isLoading = false;
  String? _error;

  FeaturedProductsNotifier() : super([]) {
    fetchFeaturedProducts();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => fetchFeaturedProducts());
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchFeaturedProducts({bool shuffle = true}) async {
    _isLoading = true;
    _error = null;

    try {
      final featuredUrl = ApiConfig.products.replaceAll('/products', '/products/featured');
      final uri = Uri.parse(featuredUrl);
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final newProducts = data.map((item) => Product.fromJson(item)).toList();
        
        if (shuffle) {
          newProducts.shuffle();
        }

        state = newProducts;
        _error = null;
      } else {
        _error = "Erreur serveur: ${response.statusCode}";
      }
    } catch (e) {
      _error = "Erreur réseau: $e";
    } finally {
      _isLoading = false;
    }
  }
}

/// Notifier pour les meilleurs vendeurs du marketplace
class TopSellersNotifier extends StateNotifier<List<Product>> {
  Timer? _refreshTimer;
  bool _isLoading = false;
  String? _error;

  TopSellersNotifier() : super([]) {
    fetchTopSellers();
    _refreshTimer = Timer.periodic(const Duration(seconds: 120), (_) => fetchTopSellers());
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchTopSellers({bool shuffle = false}) async {
    _isLoading = true;
    _error = null;

    try {
      final topSellersUrl = ApiConfig.products.replaceAll('/products', '/products/top-sellers');
      final uri = Uri.parse(topSellersUrl);
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final newProducts = data.map((item) => Product.fromJson(item)).toList();
        
        if (shuffle) {
          newProducts.shuffle();
        }

        state = newProducts;
        _error = null;
      } else {
        _error = "Erreur serveur: ${response.statusCode}";
      }
    } catch (e) {
      _error = "Erreur réseau: $e";
    } finally {
      _isLoading = false;
    }
  }
}

/// Notifier pour les produits des grands magasins vérifiés
class VerifiedShopsProductsNotifier extends StateNotifier<List<Product>> {
  Timer? _refreshTimer;
  bool _isLoading = false;
  String? _error;

  VerifiedShopsProductsNotifier() : super([]) {
    fetchVerifiedShopsProducts();
    _refreshTimer = Timer.periodic(const Duration(seconds: 120), (_) => fetchVerifiedShopsProducts());
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchVerifiedShopsProducts({bool shuffle = true}) async {
    _isLoading = true;
    _error = null;

    try {
      final verifiedUrl = ApiConfig.products.replaceAll('/products', '/products/verified-shops');
      final uri = Uri.parse(verifiedUrl);
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final newProducts = data.map((item) => Product.fromJson(item)).toList();
        
        if (shuffle) {
          newProducts.shuffle();
        }

        state = newProducts;
        _error = null;
      } else {
        _error = "Erreur serveur: ${response.statusCode}";
      }
    } catch (e) {
      _error = "Erreur réseau: $e";
    } finally {
      _isLoading = false;
    }
  }
}

/// Provider pour les produits featured (page Accueil uniquement)
final featuredProductsProvider = StateNotifierProvider<FeaturedProductsNotifier, List<Product>>((ref) => FeaturedProductsNotifier());

/// Provider pour les meilleurs vendeurs
final topSellersProvider = StateNotifierProvider<TopSellersNotifier, List<Product>>((ref) => TopSellersNotifier());

/// Provider pour les produits des grands magasins vérifiés
final verifiedShopsProductsProvider = StateNotifierProvider<VerifiedShopsProductsNotifier, List<Product>>((ref) => VerifiedShopsProductsNotifier());
