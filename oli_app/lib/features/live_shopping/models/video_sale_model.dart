/// Modèle pour une vidéo de vente (Live Shopping)
import '../../../config/api_config.dart';

/// Rend absolue une URL de média renvoyée par l'API.
String? resolveVideoMediaUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  return url.startsWith('http') ? url : '${ApiConfig.baseUrl}/$url';
}

class VideoSale {
  final String id;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? title;
  final String? description;
  final int? durationSeconds;
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final String? productId;
  final String? productName;
  final double? productPrice;
  final String? productCurrency;
  final List<String>? productImages;
  final String? productSellerName;
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
    this.commentsCount = 0,
    this.isLiked = false,
    this.productId,
    this.productName,
    this.productPrice,
    this.productCurrency,
    this.productImages,
    this.productSellerName,
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
      id: json['id']?.toString() ?? '',
      videoUrl: resolveVideoMediaUrl(json['video_url']) ?? '',
      thumbnailUrl: resolveVideoMediaUrl(json['thumbnail_url']),
      title: json['title'],
      description: json['description'],
      durationSeconds: json['duration_seconds'],
      viewsCount: json['views_count'] ?? 0,
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      isLiked: json['is_liked'] == true,
      // L'API renvoie des identifiants numériques : conversion explicite en texte
      productId: json['product_id']?.toString(),
      productName: json['product_name'],
      productPrice: json['product_price'] != null
          ? double.tryParse(json['product_price'].toString())
          : null,
      productCurrency: json['product_currency'],
      productImages: images,
      productSellerName: json['product_seller_name'],
      sellerId: json['seller_id']?.toString() ?? '',
      sellerName: json['seller_name'] ?? 'Vendeur',
      sellerAvatar: resolveVideoMediaUrl(json['seller_avatar']),
      sellerCertified: json['seller_certified'] == true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// Copie avec modifications (pour optimistic UI)
  VideoSale copyWith({
    int? likesCount,
    bool? isLiked,
    int? viewsCount,
    int? commentsCount,
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
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      productId: productId,
      productName: productName,
      productPrice: productPrice,
      productCurrency: productCurrency,
      productImages: productImages,
      productSellerName: productSellerName,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerAvatar: sellerAvatar,
      sellerCertified: sellerCertified,
      createdAt: createdAt,
    );
  }
}

/// Commentaire d'une vidéo de vente
class VideoComment {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final DateTime createdAt;

  const VideoComment({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    required this.createdAt,
  });

  factory VideoComment.fromJson(Map<String, dynamic> json) {
    return VideoComment(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name'] ?? 'Utilisateur',
      userAvatar: resolveVideoMediaUrl(json['user_avatar']),
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
