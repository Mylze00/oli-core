import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../models/product_model.dart';

final shopPromotionsProvider = FutureProvider.family<List<Product>, String>((ref, shopId) async {
  try {
    final uri = Uri.parse('${ApiConfig.shops}/$shopId/promotions?limit=12');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Product.fromJson(item)).toList();
    } else {
      throw Exception("Erreur serveur: ${response.statusCode}");
    }
  } catch (e) {
    debugPrint("❌ Erreur shopPromotionsProvider: $e");
    // Return empty list instead of throwing to avoid breaking the whole page
    return [];
  }
});
