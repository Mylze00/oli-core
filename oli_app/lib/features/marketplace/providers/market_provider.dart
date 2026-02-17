import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
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
  int _offset = 0;
  bool _hasMore = true;
  static const int _pageSize = 200;

  MarketProductsNotifier() : super(const AsyncValue.loading()) {
    fetchProducts();
  }

  bool get hasMore => _hasMore;

  /// Charge TOUS les produits (toutes les pages) pour que chaque utilisateur soit visible
  Future<void> fetchProducts({String? search, String? category, String? sellerId}) async {
    _offset = 0;
    _hasMore = true;
    state = const AsyncValue.loading();
    
    // Charger la première page
    await _loadProducts(search: search, category: category, sellerId: sellerId, append: false);
    
    // Charger automatiquement les pages suivantes
    while (_hasMore) {
      await _loadProducts(search: search, category: category, sellerId: sellerId, append: true);
    }
  }

  Future<void> loadMore({String? search, String? category, String? sellerId}) async {
    if (!_hasMore) return;
    await _loadProducts(search: search, category: category, sellerId: sellerId, append: true);
  }

  Future<void> _loadProducts({String? search, String? category, String? sellerId, bool append = false}) async {
    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (sellerId != null && sellerId.isNotEmpty) queryParams['seller_id'] = sellerId;
      queryParams['limit'] = '$_pageSize';
      queryParams['offset'] = '$_offset';

      final uri = Uri.parse('${ApiConfig.baseUrl}/products').replace(queryParameters: queryParams);
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['products'] != null) {
          data = decoded['products'] as List<dynamic>;
          _hasMore = decoded['hasMore'] ?? false;
        } else {
          data = [];
        }
        
        final newProducts = <Product>[];
        for (final json in data) {
          try {
            newProducts.add(Product.fromJson(json));
          } catch (e) {
            print('⚠️ Skipping malformed product: $e');
          }
        }

        _offset += newProducts.length;
        
        if (append && state.hasValue) {
          state = AsyncValue.data([...state.value!, ...newProducts]);
        } else {
          state = AsyncValue.data(newProducts);
        }

        // Si on a reçu moins que demandé, il n'y a plus de produits
        if (newProducts.length < _pageSize) {
          _hasMore = false;
        }
      } else {
        if (!append) {
          state = AsyncValue.error('Erreur serveur ${response.statusCode}', StackTrace.current);
        }
      }
    } catch (e, st) {
      if (!append) {
        state = AsyncValue.error(e, st);
      }
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
      final featuredUrl = '${ApiConfig.productsFeatured}?limit=100';
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
      final topSellersUrl = ApiConfig.productsTopSellers;
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
  bool _isLoading = false;
  String? _error;

  VerifiedShopsProductsNotifier() : super([]) {
    fetchVerifiedShopsProducts(); // Load once on init, refresh only on manual pull-to-refresh
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchVerifiedShopsProducts({bool shuffle = true}) async {
    _isLoading = true;
    _error = null;

    try {
      final verifiedUrl = ApiConfig.productsVerifiedShops;
      final uri = Uri.parse(verifiedUrl);
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final allProducts = data.map((item) => Product.fromJson(item)).toList();
        
        if (shuffle && allProducts.isNotEmpty) {
          // Round-robin : diversifier les produits de différentes boutiques
          final Map<String, List<Product>> byShop = {};
          for (final p in allProducts) {
            final key = p.sellerId.isNotEmpty ? p.sellerId : p.seller;
            byShop.putIfAbsent(key, () => []).add(p);
          }
          
          // Mélanger les boutiques et les produits au sein de chaque boutique
          final shopKeys = byShop.keys.toList()..shuffle();
          for (final key in shopKeys) {
            byShop[key]!.shuffle();
          }
          
          // Sélection round-robin : 1 produit par boutique en alternance
          final List<Product> diversified = [];
          bool hasMore = true;
          int round = 0;
          while (hasMore) {
            hasMore = false;
            for (final key in shopKeys) {
              final shopProducts = byShop[key]!;
              if (round < shopProducts.length) {
                diversified.add(shopProducts[round]);
                hasMore = true;
              }
            }
            round++;
          }
          
          state = diversified;
        } else {
          state = allProducts;
        }
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


/// ✨ Notifier pour les publicités (Ads Carousel)
class AdsNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  AdsNotifier() : super([]) {
    fetchAds();
  }

  Future<void> fetchAds() async {
    try {
      final uri = Uri.parse(ApiConfig.ads);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        state = data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint("Erreur fetch ads: $e");
    }
  }
}

final adsProvider = StateNotifierProvider<AdsNotifier, List<Map<String, dynamic>>>((ref) => AdsNotifier());


/// 🔥 Notifier pour les Bons Deals (Good Deals)
class GoodDealsNotifier extends StateNotifier<List<Product>> {
  GoodDealsNotifier() : super([]) {
    fetchGoodDeals();
  }

  Future<void> fetchGoodDeals() async {
    try {
      final uri = Uri.parse(ApiConfig.productsGoodDeals);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        state = data.map((item) => Product.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint("Erreur fetch good deals: $e");
    }
  }
}

final goodDealsProvider = StateNotifierProvider<GoodDealsNotifier, List<Product>>((ref) => GoodDealsNotifier());
