import 'video_sale_model.dart';

/// Score et statistiques réelles d'un créateur de vidéos
class CreatorProfile {
  final int score;
  final String level;
  final String? nextLevel;
  final int pointsToNext;
  final double levelProgress;
  final int videosCount;
  final int productsCount;
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final int videoSalesCount;
  final List<VideoSale> videos;

  const CreatorProfile({
    required this.score,
    required this.level,
    this.nextLevel,
    required this.pointsToNext,
    required this.levelProgress,
    required this.videosCount,
    required this.productsCount,
    required this.viewsCount,
    required this.likesCount,
    required this.commentsCount,
    required this.videoSalesCount,
    required this.videos,
  });

  factory CreatorProfile.fromJson(Map<String, dynamic> json) {
    final videos = (json['videos'] as List? ?? []).cast<Map<String, dynamic>>();
    return CreatorProfile(
      score: json['score'] ?? 0,
      level: json['level'] ?? 'Débutant',
      nextLevel: json['next_level'],
      pointsToNext: json['points_to_next'] ?? 0,
      levelProgress: (json['level_progress'] as num?)?.toDouble() ?? 0,
      videosCount: json['videos_count'] ?? 0,
      productsCount: json['products_count'] ?? 0,
      viewsCount: json['views_count'] ?? 0,
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      videoSalesCount: json['video_sales_count'] ?? 0,
      videos: videos.map(VideoSale.fromJson).toList(),
    );
  }
}
