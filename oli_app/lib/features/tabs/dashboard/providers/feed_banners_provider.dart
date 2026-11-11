import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/api_config.dart';
import '../../../../core/router/network/dio_provider.dart';
import '../../../../core/services/hive_cache_service.dart';

/// Bannière du fil d'accueil, gérée depuis l'admin (page Publicités).
/// Image avec lien facultatif, ou vidéo courte compressée.
@immutable
class FeedBanner {
  final int id;
  final bool isVideo;
  final String mediaUrl;
  final String? posterUrl;
  final String? linkUrl;
  final String title;

  const FeedBanner({
    required this.id,
    required this.isVideo,
    required this.mediaUrl,
    this.posterUrl,
    this.linkUrl,
    this.title = '',
  });

  factory FeedBanner.fromJson(Map<String, dynamic> json) {
    String? text(dynamic v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    return FeedBanner(
      id: (json['id'] as num).toInt(),
      isVideo: json['media_type'] == 'video',
      mediaUrl: json['media_url'].toString(),
      posterUrl: text(json['poster_url']),
      linkUrl: text(json['link_url']),
      title: text(json['title']) ?? '',
    );
  }
}

/// Liste des bannières actives, affichée tout de suite depuis le cache local
/// puis mise à jour en arrière-plan. En cas d'échec réseau, la dernière liste
/// connue reste affichée.
class FeedBannersNotifier extends StateNotifier<List<FeedBanner>> {
  static const String _cacheKey = 'home_feed_banners_cache';

  final Dio _dio;
  bool _isFetching = false;

  FeedBannersNotifier(this._dio) : super(const []) {
    final cached = HiveCacheService.getCache(_cacheKey);
    if (cached is List) state = _parse(cached);
    refresh();
  }

  List<FeedBanner> _parse(List<dynamic> items) {
    final banners = <FeedBanner>[];
    for (final item in items) {
      try {
        final banner = FeedBanner.fromJson(Map<String, dynamic>.from(item as Map));
        if (banner.mediaUrl.isNotEmpty) banners.add(banner);
      } catch (e) {
        debugPrint('⚠️ feed-banners: bannière ignorée (parse): $e');
      }
    }
    return banners;
  }

  Future<void> refresh() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final response = await _dio.get(ApiConfig.feedBanners);
      final items = response.data as List<dynamic>;
      await HiveCacheService.setCache(_cacheKey, items);
      if (mounted) state = _parse(items);
    } catch (e) {
      debugPrint('⚠️ feed-banners indisponibles: $e');
    } finally {
      _isFetching = false;
    }
  }
}

final feedBannersProvider =
    StateNotifierProvider<FeedBannersNotifier, List<FeedBanner>>((ref) {
  return FeedBannersNotifier(ref.read(dioProvider));
});
