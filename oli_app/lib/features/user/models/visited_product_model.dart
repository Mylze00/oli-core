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
      imageUrl: json['image_url'],
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
}
