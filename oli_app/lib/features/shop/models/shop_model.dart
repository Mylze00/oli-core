class Shop {
  final int id;
  final int ownerId;
  final String name;
  final String description;
  final String category;
  final String? location;
  final String? logoUrl;
  final String? bannerUrl;
  final bool isVerified;
  final double rating;
  final int totalProducts;
  final int totalSales;
  final String? ownerName;
  final String? ownerAvatar;
  final DateTime createdAt;

  Shop({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description = '',
    required this.category,
    this.location,
    this.logoUrl,
    this.bannerUrl,
    this.isVerified = false,
    this.rating = 0.0,
    this.totalProducts = 0,
    this.totalSales = 0,
    this.ownerName,
    this.ownerAvatar,
    required this.createdAt,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'],
      ownerId: json['owner_id'],
      name: json['name'],
      description: json['description'] ?? '',
      category: json['category'] ?? 'Général',
      location: json['location'],
      logoUrl: json['logo_url'],
      bannerUrl: json['banner_url'],
      isVerified: json['is_verified'] ?? false,
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      totalProducts: int.tryParse(json['total_products']?.toString() ?? '0') ?? 0,
      totalSales: int.tryParse(json['total_sales']?.toString() ?? '0') ?? 0,
      ownerName: json['owner_name'],
      ownerAvatar: json['owner_avatar'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
