import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';

/// Modèle simple pour le profil public vendeur
class SellerProfile {
  final String id;
  final String name;
  final String? avatarUrl;
  final DateTime? joinedAt;
  final bool isVerified;
  final String accountType;
  final bool hasCertifiedShop;
  final int totalSales;
  final double rating;
  final String? shopName;
  final bool shopVerified;
  final String? description;

  SellerProfile({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.joinedAt,
    this.isVerified = false,
    this.accountType = 'ordinaire',
    this.hasCertifiedShop = false,
    this.totalSales = 0,
    this.rating = 0.0,
    this.shopName,
    this.shopVerified = false,
    this.description,
  });

  factory SellerProfile.fromJson(Map<String, dynamic> json) {
    return SellerProfile(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Utilisateur',
      avatarUrl: json['avatar_url'],
      joinedAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      isVerified: json['is_verified'] ?? false,
      accountType: json['account_type'] ?? 'ordinaire',
      hasCertifiedShop: json['has_certified_shop'] ?? false,
      totalSales: int.tryParse(json['total_sales']?.toString() ?? '0') ?? 0,
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      shopName: json['shop_name'],
      shopVerified: json['shop_verified'] ?? false,
      description: json['description'],
    );
  }
}

/// State du vendeur selectionné
class SellerNotifier extends StateNotifier<AsyncValue<SellerProfile>> {
  SellerNotifier() : super(const AsyncValue.loading());

  Future<void> fetchSellerProfile(String sellerId) async {
    state = const AsyncValue.loading();
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/user/public-profile/$sellerId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        state = AsyncValue.data(SellerProfile.fromJson(data));
      } else {
        state = AsyncValue.error('Vendeur introuvable', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final sellerProvider = StateNotifierProvider<SellerNotifier, AsyncValue<SellerProfile>>((ref) {
  return SellerNotifier();
});
