import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/router/network/dio_provider.dart';
import '../models/video_sale_model.dart';

/// État du feed vidéo
class VideoFeedState {
  final List<VideoSale> videos;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const VideoFeedState({
    this.videos = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  VideoFeedState copyWith({
    List<VideoSale>? videos,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return VideoFeedState(
      videos: videos ?? this.videos,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

/// Provider pour le feed vidéo
class VideoFeedNotifier extends StateNotifier<VideoFeedState> {
  final Dio _dio;

  VideoFeedNotifier(this._dio) : super(const VideoFeedState());

  /// Charger la première page
  Future<void> loadFeed() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.get('/api/videos', queryParameters: {
        'page': 1,
        'limit': 10,
      });

      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['videos'] ?? [];
        final videos = data.map((json) => VideoSale.fromJson(json)).toList();

        state = state.copyWith(
          videos: videos,
          isLoading: false,
          currentPage: 1,
          hasMore: videos.length >= 10,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Impossible de charger les vidéos',
      );
    }
  }

  /// Charger la page suivante
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      final response = await _dio.get('/api/videos', queryParameters: {
        'page': nextPage,
        'limit': 10,
      });

      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['videos'] ?? [];
        final newVideos = data.map((json) => VideoSale.fromJson(json)).toList();

        state = state.copyWith(
          videos: [...state.videos, ...newVideos],
          isLoading: false,
          currentPage: nextPage,
          hasMore: newVideos.length >= 10,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Toggle like (optimistic UI)
  Future<void> toggleLike(String videoId) async {
    final index = state.videos.indexWhere((v) => v.id == videoId);
    if (index == -1) return;

    final video = state.videos[index];
    final newLiked = !video.isLiked;
    final newCount = newLiked ? video.likesCount + 1 : video.likesCount - 1;

    // Optimistic update
    final updatedVideos = [...state.videos];
    updatedVideos[index] = video.copyWith(
      isLiked: newLiked,
      likesCount: newCount < 0 ? 0 : newCount,
    );
    state = state.copyWith(videos: updatedVideos);

    // Server sync
    try {
      await _dio.post('/api/videos/$videoId/like');
    } catch (e) {
      // Rollback on error
      final rollbackVideos = [...state.videos];
      rollbackVideos[index] = video;
      state = state.copyWith(videos: rollbackVideos);
    }
  }

  /// Enregistrer une vue
  Future<void> registerView(String videoId) async {
    try {
      await _dio.post('/api/videos/$videoId/view');
    } catch (_) {
      // Silently fail — non-critical
    }
  }
}

/// Providers Riverpod
final videoFeedProvider =
    StateNotifierProvider<VideoFeedNotifier, VideoFeedState>((ref) {
  final dio = ref.read(dioProvider);
  return VideoFeedNotifier(dio);
});
