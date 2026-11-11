import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/api_config.dart';
import '../../../../core/router/network/dio_provider.dart';
import '../../../../core/services/hive_cache_service.dart';
import '../../../../models/product_model.dart';

/// Top Classement personnalisé, conservé sur l'appareil pendant 3 heures.
///
/// Le backend tire au hasard parmi les produits de l'accueil, en excluant
/// les produits vus récemment et les catégories favorites de l'utilisateur.
/// Tant que le tirage a moins de 3 heures, l'ouverture de l'application ET
/// le pull-to-refresh réaffichent les mêmes produits (donc les mêmes images,
/// déjà en cache) sans appel réseau. Passé ce délai, un nouveau tirage est
/// demandé ; en cas d'échec, l'ancien reste affiché.
///
/// - Pull-to-refresh / retour sur l'accueil : `refreshIfExpired()`.
/// - Forcer un nouveau tirage : `refresh()`.
class DiscoverRandomNotifier extends StateNotifier<List<Product>> {
  static const String _cacheKey = 'home_top_ranking_cache';
  static const Duration _validity = Duration(hours: 3);

  DateTime? _fetchedAt;

  final Dio _dio;
  bool _isFetching = false;

  DiscoverRandomNotifier(this._dio) : super(const []) {
    _fetchedAt = _restoreFromCache();
    refreshIfExpired();
  }

  /// Demande un nouveau tirage seulement si le classement actuel a 3 h ou
  /// plus (ou s'il n'y en a pas). Sinon ne fait rien : le classement reste.
  Future<void> refreshIfExpired() async {
    if (state.isNotEmpty && !_isExpired(_fetchedAt)) return;
    await refresh();
  }

  bool _isExpired(DateTime? fetchedAt) {
    if (fetchedAt == null) return true;
    final age = DateTime.now().difference(fetchedAt);
    return age.isNegative || age >= _validity;
  }

  /// Restaure le dernier tirage et renvoie sa date, ou null s'il n'y en a pas.
  DateTime? _restoreFromCache() {
    final cached = HiveCacheService.getCache(_cacheKey);
    if (cached is! Map || cached['items'] is! List) return null;
    final fetchedAtMs = cached['fetchedAt'];
    if (fetchedAtMs is! int) return null;
    state = _parse(cached['items'] as List);
    return DateTime.fromMillisecondsSinceEpoch(fetchedAtMs);
  }

  List<Product> _parse(List<dynamic> items) {
    final products = <Product>[];
    for (final item in items) {
      try {
        products.add(Product.fromJson(item as Map<String, dynamic>));
      } catch (e) {
        debugPrint('⚠️ discover-random: produit ignoré (parse): $e');
      }
    }
    return products;
  }

  /// Demande un nouveau tirage. L'ancien est conservé si l'appel échoue.
  Future<void> refresh() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final response = await _dio.get(
        ApiConfig.productsDiscoverRandom,
        // 96 : marge pour compenser les doublons retirés par la page
        queryParameters: {'limit': 96},
      );
      final items = response.data as List<dynamic>;
      final products = _parse(items);
      if (products.isEmpty) return;

      final now = DateTime.now();
      await HiveCacheService.setCache(_cacheKey, {
        'fetchedAt': now.millisecondsSinceEpoch,
        'items': items,
      });
      _fetchedAt = now;
      if (mounted) state = products;
    } catch (e) {
      debugPrint('⚠️ discover-random indisponible: $e');
    } finally {
      _isFetching = false;
    }
  }
}

final discoverRandomProvider =
    StateNotifierProvider<DiscoverRandomNotifier, List<Product>>((ref) {
  return DiscoverRandomNotifier(ref.read(dioProvider));
});
