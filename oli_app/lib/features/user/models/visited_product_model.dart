class VisitedProduct {
  final int id;
  final String name;
  final double price;
  final String? imageUrl;
  final String? description;
  final DateTime viewedAt;
  final String? sellerName;

  VisitedProduct({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.description,
    required this.viewedAt,
    this.sellerName,
  });

  factory VisitedProduct.fromJson(Map<String, dynamic> json) {
    return VisitedProduct(
      id: json['id'],
      name: json['name'],
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      imageUrl: _parseImage(json),
      description: json['description'],
      viewedAt: DateTime.parse(json['viewed_at']),
      sellerName: json['seller_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'image_url': imageUrl,
      'description': description,
      'viewed_at': viewedAt.toIso8601String(),
      'seller_name': sellerName,
    };
  }
  static String? _parseImage(Map<String, dynamic> json) {
    // 1. Essayer image_url direct
    if (json['image_url'] != null && json['image_url'] is String) {
       return json['image_url'];
    }

    // 2. Essayer 'images' (array ou string JSON)
    var images = json['images'];
    if (images != null) {
      if (images is List && images.isNotEmpty) {
        return images.first;
      } else if (images is String) {
        // Nettoyer format {url1,url2} ou ["url1"]
        final clean = images.replaceAll(RegExp(r'[{}"\[\]]'), '');
        final parts = clean.split(',');
        if (parts.isNotEmpty && parts.first.isNotEmpty) {
          return parts.first;
        }
      }
    }

    return null;
  }
}

