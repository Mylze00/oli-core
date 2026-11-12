import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../features/marketplace/presentation/pages/product_details_page.dart';
import '../../models/product_model.dart';

/// Liens de produit : partage et ouverture.
///
/// - Lien partagé : https://oli-core.onrender.com/p/<id> (aperçu enrichi, puis redirection).
/// - L'app web s'ouvre alors sur https://oli-core.web.app/product/<id> : l'identifiant est
///   gardé au démarrage, puis la fiche du produit s'ouvre dès que l'écran principal est affiché.
class ProductLink {
  ProductLink._();

  static const String shareBase = '${ApiConfig.baseUrl}/p';

  static int? _pendingProductId;
  static bool _opening = false;

  /// Lien unique d'un produit.
  static String shareUrl(String productId) => '$shareBase/$productId';

  /// À appeler au démarrage : lit /product/<id> (ou ?product=<id>) dans l'adresse web.
  static void captureFromUrl() {
    if (!kIsWeb) return;
    final uri = Uri.base;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    String? raw;
    if (segments.length >= 2 && segments[0] == 'product') raw = segments[1];
    raw ??= uri.queryParameters['product'];
    final id = int.tryParse(RegExp(r'^\d+').stringMatch(raw ?? '') ?? '');
    if (id != null) _pendingProductId = id;
  }

  /// À appeler une fois l'écran principal affiché : ouvre le produit du lien, une seule fois.
  static Future<void> openPending(BuildContext context) async {
    final id = _pendingProductId;
    if (id == null || _opening) return;
    _opening = true;
    _pendingProductId = null;
    try {
      final response = await Dio().get('${ApiConfig.products}/$id');
      final data = response.data;
      if (data is! Map) return;
      final product = Product.fromJson(Map<String, dynamic>.from(data));
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
      );
    } catch (e) {
      debugPrint('⚠️ Produit du lien introuvable ($id) : $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce produit n\'est plus disponible')),
        );
      }
    } finally {
      _opening = false;
    }
  }
}
