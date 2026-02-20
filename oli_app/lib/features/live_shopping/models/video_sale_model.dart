/// Modèle pour une vidéo de vente (Live Shopping)
class VideoSale {
  final String id;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? title;
  final String? description;
  final int? durationSeconds;
  final int viewsCount;
  final int likesCount;
  final bool isLiked;
  final String? productId;
  final String? productName;
  final double? productPrice;
  final String? productCurrency;
  final List<String>? productImages;
  final String sellerId;
  final String sellerName;
  final String? sellerAvatar;
  final bool sellerCertified;
  final DateTime createdAt;

  VideoSale({
    required this.id,
    required this.videoUrl,
    this.thumbnailUrl,
    this.title,
    this.description,
    this.durationSeconds,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.isLiked = false,
    this.productId,
    this.productName,
    this.productPrice,
    this.productCurrency,
    this.productImages,
    required this.sellerId,
    required this.sellerName,
    this.sellerAvatar,
    this.sellerCertified = false,
    required this.createdAt,
  });

  factory VideoSale.fromJson(Map<String, dynamic> json) {
    // Parse product images
    List<String>? images;
    if (json['product_images'] != null) {
      if (json['product_images'] is List) {
        images = (json['product_images'] as List).cast<String>();
      } else if (json['product_images'] is String) {
        images = [json['product_images'] as String];
      }
    }

    return VideoSale(
      id: json['id'] ?? '',
      videoUrl: json['video_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      title: json['title'],
      description: json['description'],
      durationSeconds: json['duration_seconds'],
      viewsCount: json['views_count'] ?? 0,
      likesCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] == true,
      productId: json['product_id'],
      productName: json['product_name'],
      productPrice: json['product_price'] != null
          ? double.tryParse(json['product_price'].toString())
          : null,
      productCurrency: json['product_currency'],
      productImages: images,
      sellerId: json['seller_id'] ?? '',
      sellerName: json['seller_name'] ?? 'Vendeur',
      sellerAvatar: json['seller_avatar'],
      sellerCertified: json['seller_certified'] == true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// Copie avec modifications (pour optimistic UI)
  VideoSale copyWith({
    int? likesCount,
    bool? isLiked,
    int? viewsCount,
  }) {
    return VideoSale(
      id: id,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      title: title,
      description: description,
      durationSeconds: durationSeconds,
      viewsCount: viewsCount ?? this.viewsCount,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      productId: productId,
      productName: productName,
      productPrice: productPrice,
      productCurrency: productCurrency,
      productImages: productImages,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerAvatar: sellerAvatar,
      sellerCertified: sellerCertified,
      createdAt: createdAt,
    );
  }
}
