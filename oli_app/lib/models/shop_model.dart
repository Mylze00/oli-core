import '../config/api_config.dart';

class Shop {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String ownerId;
  final String? ownerName;
  final String? ownerAvatar;
  final bool isVerified;
  final String? category;
  final String? location;
  final double rating;
  
  // Champs de certification
  final String accountType;
  final bool hasCertifiedShop;
  final int? totalSales;
  final double? trustScore;

  Shop({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    required this.ownerId,
    this.ownerName,
    this.ownerAvatar,
    this.isVerified = false,
    this.category,
    this.location,
    this.rating = 0.0,
    this.accountType = 'ordinaire',
    this.hasCertifiedShop = false,
    this.totalSales,
    this.trustScore,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Boutique',
      description: json['description'],
      logoUrl: _formatUrl(json['logo_url']),
      bannerUrl: _formatUrl(json['banner_url']),
      ownerId: json['owner_id']?.toString() ?? '',
      ownerName: json['owner_name'],
      ownerAvatar: _formatUrl(json['owner_avatar']),
      isVerified: json['is_verified'] ?? false,
      category: json['category'],
      location: json['location'],
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      accountType: json['account_type'] ?? json['owner_account_type'] ?? 'ordinaire',
      hasCertifiedShop: json['has_certified_shop'] ?? json['owner_has_certified_shop'] ?? false,
      totalSales: json['total_sales'],
      trustScore: json['trust_score']?.toDouble(),
    );
  }
  
  // Helper pour obtenir le label de certification
  String get certificationLabel {
    switch (accountType) {
      case 'premium':
        return 'PREMIUM';
      case 'entreprise':
        return 'ENTREPRISE';
      case 'certifie':
        return 'CERTIFIÉ';
      default:
        return '';
    }
  }
  
  // Helper pour s'assurer que l'URL est absolue
  static String? _formatUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    // Nettoyage des slashs multiples potentiels
    final cleanPath = url.replaceAll(RegExp(r'^/+'), '');
    return '${ApiConfig.baseUrl}/uploads/$cleanPath';
  }
}
