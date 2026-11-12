import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../core/services/hive_cache_service.dart';
import '../../../models/product_model.dart';

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
  /// Premier chargement : 20 produits (deux lots), puis des lots de 10 pendant le défilement.
  static const int _firstPageSize = 20;
  static const int _pageSize = 10;

  /// [sellerId] : liste limitée à un vendeur (profil vendeur, fournisseur séparé).
  MarketProductsNotifier({String? sellerId}) : super(const AsyncValue.loading()) {
    fetchProducts(sellerId: sellerId);
  }

  // Filtres de la liste en cours : réutilisés pour charger les pages suivantes
  String? _search;
  String? _category;
  String? _sellerId;
  bool _loadingMore = false;

  bool get hasMore => _hasMore;
  String? get category => _category;

  /// Charge la première page de produits uniquement (lazy-load via loadMore).
  /// La catégorie est filtrée par le serveur sur tout le catalogue, pas seulement
  /// sur les produits déjà chargés.
  Future<void> fetchProducts({String? search, String? category, String? sellerId}) async {
    _offset = 0;
    _hasMore = true;
    _search = search;
    _category = category;
    _sellerId = sellerId;
    state = const AsyncValue.loading();
    await _loadProducts(search: search, category: category, sellerId: sellerId, append: false);
  }

  /// Page suivante, avec les mêmes filtres que la liste affichée.
  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      await _loadProducts(search: _search, category: _category, sellerId: _sellerId, append: true);
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _loadProducts({String? search, String? category, String? sellerId, bool append = false}) async {
    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (sellerId != null && sellerId.isNotEmpty) queryParams['seller_id'] = sellerId;
      final limit = append ? _pageSize : _firstPageSize;
      queryParams['limit'] = '$limit';
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
          // Sans doublon : un produit déjà affiché n'est jamais ajouté une seconde fois
          final seen = state.value!.map((p) => p.id).toSet();
          final fresh = newProducts.where((p) => seen.add(p.id)).toList();
          state = AsyncValue.data([...state.value!, ...fresh]);
        } else {
          final seen = <String>{};
          state = AsyncValue.data(newProducts.where((p) => seen.add(p.id)).toList());
        }

        // Si on a reçu moins que demandé, il n'y a plus de produits
        if (newProducts.length < limit) {
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

/// Produits d'un vendeur (page profil) : fournisseur séparé du Marché, pour ne plus
/// remplacer la liste du Marché par celle d'un seul vendeur.
final sellerProductsProvider = StateNotifierProvider.autoDispose
    .family<MarketProductsNotifier, AsyncValue<List<Product>>, String>((ref, sellerId) {
  return MarketProductsNotifier(sellerId: sellerId);
});

/// Notifier pour les produits mis en avant (Featured) - Page Accueil
/// Délai pendant lequel une réouverture de l'application réutilise le cache
/// des sections de l'accueil, sans appel réseau.
const Duration _homeCacheValidity = Duration(hours: 12);

/// Date d'écriture du cache [cacheKey] s'il a moins de 12 heures, sinon null.
DateTime? _freshHomeCacheTime(String cacheKey) {
  final ms = HiveCacheService.getCache('${cacheKey}_at');
  if (ms is! int) return null;
  final at = DateTime.fromMillisecondsSinceEpoch(ms);
  final age = DateTime.now().difference(at);
  return (age.isNegative || age >= _homeCacheValidity) ? null : at;
}

Future<void> _stampHomeCache(String cacheKey) {
  return HiveCacheService.setCache('${cacheKey}_at', DateTime.now().millisecondsSinceEpoch);
}

class FeaturedProductsNotifier extends StateNotifier<List<Product>> {
  Timer? _refreshTimer;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _error;
  DateTime? _lastFetchTime; // ← Cache : heure du dernier chargement

  static const int _initialPageSize = 200;
  static const int _morePageSize = 100;
  static const Duration _cacheDuration = Duration(hours: 24); // ← Durée du cache

  FeaturedProductsNotifier() : super([]) {
    fetchFeaturedProducts(force: false);
    // Vérification toutes les heures, mais ne recharge que si le cache est expiré
    _refreshTimer = Timer.periodic(const Duration(hours: 1), (_) => _refreshIfStale());
  }

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  /// Vérifie si le cache est expiré avant de relancer le fetch automatique
  void _refreshIfStale() {
    if (_lastFetchTime == null) {
      fetchFeaturedProducts();
      return;
    }
    final age = DateTime.now().difference(_lastFetchTime!);
    if (age >= _cacheDuration) {
      debugPrint('🔄 [Featured] Cache expiré (${age.inHours}h) → rechargement');
      fetchFeaturedProducts();
    } else {
      debugPrint('✅ [Featured] Cache valide encore ${(_cacheDuration - age).inMinutes} min');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Avec [force] à false, un cache de moins de 12 heures évite l'appel réseau.
  Future<void> fetchFeaturedProducts({bool force = true}) async {
    if (_isLoading) return;
    _isLoading = true;
    _isLoadingMore = false;
    _hasMore = true;
    _offset = 0;
    _error = null;

    // --- CACHE OFFLINE-FIRST ---
    if (state.isEmpty) {
      try {
        final cachedData = HiveCacheService.getCache('market_featured_cache');
        if (cachedData != null) {
          final List<dynamic> data = cachedData as List<dynamic>;
          final cachedProducts = data.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
          if (cachedProducts.isNotEmpty) {
            state = cachedProducts;
            debugPrint('✅ [CACHE] Featured chargé instantanément (${cachedProducts.length} produits)');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Erreur lecture cache featured: $e');
      }
    }

    if (!force && state.isNotEmpty) {
      final cachedAt = _freshHomeCacheTime('market_featured_cache');
      if (cachedAt != null) {
        _lastFetchTime = cachedAt;
        _offset = state.length;
        _hasMore = state.length >= _initialPageSize;
        _isLoading = false;
        return;
      }
    }

    try {
      final uri = Uri.parse('${ApiConfig.productsFeatured}?limit=$_initialPageSize');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        data.shuffle(); // Mélange avant la mise en cache : l'ordre reste le même à la réouverture
        final newProducts = <Product>[];
        for (final item in data) {
          try {
            newProducts.add(Product.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            debugPrint('⚠️ Featured product skipped (parse error): $e');
          }
        }
        _offset = newProducts.length;
        _hasMore = newProducts.length >= _initialPageSize;
        _lastFetchTime = DateTime.now(); // ← Mémoriser l'heure du chargement
        state = newProducts;
        _error = null;
        debugPrint('✅ [Featured] ${newProducts.length} produits chargés et mis en cache (24h)');
        // Mise à jour du cache local
        try {
          await HiveCacheService.setCache('market_featured_cache', data);
          await _stampHomeCache('market_featured_cache');
        } catch (e) {
          debugPrint('Erreur écriture cache featured: $e');
        }
      } else {
        _error = 'Erreur serveur: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Erreur réseau: $e';
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;

    try {
      final uri = Uri.parse('${ApiConfig.productsFeatured}?limit=$_morePageSize&offset=$_offset');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final moreProducts = <Product>[];
        for (final item in data) {
          try {
            moreProducts.add(Product.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            debugPrint('⚠️ Featured loadMore skipped: $e');
          }
        }
        if (moreProducts.isNotEmpty) {
          moreProducts.shuffle(); // Aléatoire aussi pour la suite
          // Déduplication : ne pas ajouter des produits déjà en cache
          final existingIds = state.map((p) => p.id).toSet();
          final uniqueMore = moreProducts.where((p) => !existingIds.contains(p.id)).toList();
          _offset += moreProducts.length;
          if (uniqueMore.isNotEmpty) {
            state = [...state, ...uniqueMore];
          }
        }
        _hasMore = moreProducts.length >= _morePageSize;
      }
    } catch (e) {
      debugPrint('Erreur loadMore featured: $e');
    } finally {
      _isLoadingMore = false;
    }
  }
}

/// Notifier pour les meilleurs vendeurs du marketplace
class TopSellersNotifier extends StateNotifier<List<Product>> {
  Timer? _refreshTimer;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetchTime; // ← Cache : heure du dernier chargement

  static const Duration _cacheDuration = Duration(hours: 24); // ← Durée du cache

  TopSellersNotifier() : super([]) {
    fetchTopSellers(shuffle: true, force: false);
    // Vérification toutes les heures, ne recharge que si cache expiré
    _refreshTimer = Timer.periodic(const Duration(hours: 1), (_) => _refreshIfStale());
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Vérifie si le cache est expiré avant de relancer le fetch automatique
  void _refreshIfStale() {
    if (_lastFetchTime == null) {
      fetchTopSellers(shuffle: true);
      return;
    }
    final age = DateTime.now().difference(_lastFetchTime!);
    if (age >= _cacheDuration) {
      debugPrint('🔄 [TopSellers] Cache expiré (${age.inHours}h) → rechargement');
      fetchTopSellers(shuffle: true);
    } else {
      debugPrint('✅ [TopSellers] Cache valide encore ${(_cacheDuration - age).inMinutes} min');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Avec [force] à false, un cache de moins de 12 heures évite l'appel réseau.
  Future<void> fetchTopSellers({bool shuffle = false, bool force = true}) async {
    _isLoading = true;
    _error = null;

    // --- CACHE OFFLINE-FIRST ---
    if (state.isEmpty) {
      try {
        final cachedData = HiveCacheService.getCache('market_topsellers_cache');
        if (cachedData != null) {
          final List<dynamic> data = cachedData as List<dynamic>;
          final cachedProducts = data.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
          if (cachedProducts.isNotEmpty) {
            state = cachedProducts;
            debugPrint('✅ [CACHE] Top Sellers chargé instantanément (${cachedProducts.length} produits)');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Erreur lecture cache topsellers: $e');
      }
    }

    if (!force && state.isNotEmpty) {
      final cachedAt = _freshHomeCacheTime('market_topsellers_cache');
      if (cachedAt != null) {
        _lastFetchTime = cachedAt;
        _isLoading = false;
        return;
      }
    }

    try {
      final topSellersUrl = '${ApiConfig.productsTopSellers}?limit=30';
      final uri = Uri.parse(topSellersUrl);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (shuffle) {
          data.shuffle(); // Mélange avant la mise en cache : l'ordre reste le même à la réouverture
        }
        final newProducts = data.map((item) => Product.fromJson(item)).toList();

        _lastFetchTime = DateTime.now(); // ← Mémoriser l'heure du chargement
        state = newProducts;
        _error = null;
        debugPrint('✅ [TopSellers] ${newProducts.length} produits chargés et mis en cache (24h)');
        // Mise à jour du cache local
        try {
          await HiveCacheService.setCache('market_topsellers_cache', data);
          await _stampHomeCache('market_topsellers_cache');
        } catch (e) {
          debugPrint('Erreur écriture cache topsellers: $e');
        }
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
    fetchVerifiedShopsProducts(force: false);
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Avec [force] à false, un cache de moins de 12 heures évite l'appel réseau.
  Future<void> fetchVerifiedShopsProducts({bool shuffle = true, bool force = true}) async {
    _isLoading = true;
    _error = null;

    if (state.isEmpty) {
      try {
        final cachedData = HiveCacheService.getCache('market_verified_shops_cache');
        if (cachedData != null) {
          final List<dynamic> data = cachedData as List<dynamic>;
          state = data.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
        }
      } catch (e) {}
    }

    if (!force && state.isNotEmpty && _freshHomeCacheTime('market_verified_shops_cache') != null) {
      _isLoading = false;
      return;
    }

    try {
      final verifiedUrl = '${ApiConfig.productsVerifiedShops}?limit=50';
      final uri = Uri.parse(verifiedUrl);
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final allProducts = data.map((item) => Product.fromJson(item)).toList();
        // L'ordre mis en cache doit être l'ordre affiché, pour rester le même à la réouverture.
        List<dynamic> dataToCache = data;

        if (shuffle && allProducts.isNotEmpty) {
          final Map<String, List<Product>> byShop = {};
          for (final p in allProducts) {
            final key = p.sellerId.isNotEmpty ? p.sellerId : p.seller;
            byShop.putIfAbsent(key, () => []).add(p);
          }
          final shopKeys = byShop.keys.toList()..shuffle();
          for (final key in shopKeys) {
            byShop[key]!.shuffle();
          }
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
          final rawById = {
            for (var i = 0; i < allProducts.length; i++) allProducts[i].id: data[i],
          };
          dataToCache = diversified.map((p) => rawById[p.id]).toList();
          state = diversified;
        } else {
          state = allProducts;
        }
        _error = null;
        await HiveCacheService.setCache('market_verified_shops_cache', dataToCache);
        await _stampHomeCache('market_verified_shops_cache');
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

/// Provider pour les produits meilleurs vendeurs
final topSellersProvider = StateNotifierProvider<TopSellersNotifier, List<Product>>((ref) => TopSellersNotifier());

/// Provider pour les produits des grands magasins vérifiés
final verifiedShopsProductsProvider = StateNotifierProvider<VerifiedShopsProductsNotifier, List<Product>>((ref) => VerifiedShopsProductsNotifier());

/// Notifier pour les produits brandCertified (badge "Original")
class BrandedProductsNotifier extends StateNotifier<List<Product>> {
  BrandedProductsNotifier() : super([]) {
    fetchBrandedProducts(force: false);
  }

  /// Avec [force] à false, un cache de moins de 12 heures évite l'appel réseau.
  Future<void> fetchBrandedProducts({bool force = true}) async {
    if (state.isEmpty) {
      try {
        final cachedData = HiveCacheService.getCache('market_branded_cache');
        if (cachedData != null) {
          final List<dynamic> data = cachedData as List<dynamic>;
          state = data.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
        }
      } catch (e) {}
    }

    if (!force && state.isNotEmpty && _freshHomeCacheTime('market_branded_cache') != null) {
      return;
    }

    try {
      final uri = Uri.parse('${ApiConfig.productsBranded}?limit=50');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final products = <Product>[];
        for (final item in data) {
          try {
            products.add(Product.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            debugPrint('⚠️ Branded product skipped: $e');
          }
        }
        state = products;
        await HiveCacheService.setCache('market_branded_cache', data);
        await _stampHomeCache('market_branded_cache');
        debugPrint('✅ brandedProductsProvider: ${state.length} produits Original chargés');
      }
    } catch (e) {
      debugPrint('Erreur brandedProductsProvider: $e');
    }
  }
}

final brandedProductsProvider = StateNotifierProvider<BrandedProductsNotifier, List<Product>>((ref) => BrandedProductsNotifier());


/// ✨ Notifier pour les publicités (Ads Carousel)
class AdsNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  AdsNotifier() : super([]) {
    fetchAds();
  }

  Future<void> fetchAds() async {
    if (state.isEmpty) {
      try {
        final cachedData = HiveCacheService.getCache('ads_cache');
        if (cachedData != null) {
          state = (cachedData as List<dynamic>).cast<Map<String, dynamic>>();
        }
      } catch (e) {}
    }

    try {
      final uri = Uri.parse(ApiConfig.ads);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        state = data.cast<Map<String, dynamic>>();
        HiveCacheService.setCache('ads_cache', data);
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
