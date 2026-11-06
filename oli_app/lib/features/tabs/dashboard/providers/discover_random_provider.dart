import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/api_config.dart';
import '../../../../core/router/network/dio_provider.dart';
import '../../../../models/product_model.dart';

/// Top Classement personnalisé.
///
/// Le backend tire au hasard parmi les produits de l'accueil, en excluant
/// les produits vus récemment et les catégories favorites de l'utilisateur.
/// Le token est injecté par [dioProvider] ; un visiteur anonyme reçoit un tirage libre.
///
/// Pour rafraîchir la sélection (pull-to-refresh) : `ref.invalidate(discoverRandomProvider)`.
final discoverRandomProvider = FutureProvider<List<Product>>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get(
      ApiConfig.productsDiscoverRandom,
      // 96 : marge pour compenser les doublons retirés par la page (Super Offres, Sélection…)
      queryParameters: {'limit': 96},
    );
    final List<dynamic> data = response.data as List<dynamic>;
    final products = <Product>[];
    for (final item in data) {
      try {
        products.add(Product.fromJson(item as Map<String, dynamic>));
      } catch (e) {
        debugPrint('⚠️ discover-random: produit ignoré (parse): $e');
      }
    }
    return products;
  } catch (e) {
    debugPrint('⚠️ discover-random indisponible: $e');
    return <Product>[];
  }
});
