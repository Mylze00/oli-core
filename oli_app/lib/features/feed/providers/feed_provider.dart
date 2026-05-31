import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/feed_model.dart';
import 'dart:io';
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/services/hive_cache_service.dart';
import 'dart:convert';

final feedProvider = StateNotifierProvider<FeedNotifier, AsyncValue<List<FeedPost>>>((ref) {
  return FeedNotifier();
});

class FeedNotifier extends StateNotifier<AsyncValue<List<FeedPost>>> {
  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  FeedNotifier() : super(const AsyncValue.loading()) {
    fetchFeed();
  }

  Future<void> fetchFeed({bool isRefresh = false}) async {
    if (isRefresh) {
      _nextCursor = null;
      _hasMore = true;
    }

    if (!_hasMore || _isLoadingMore) return;

    // --- OFFLINE-FIRST CACHE ---
    // Si c'est le chargement initial de la première page, on vérifie le cache
    final bool isFirstLoad = !isRefresh && !state.hasValue && _nextCursor == null;
    if (isFirstLoad) {
      try {
        final cachedData = await HiveCacheService.getCache('feed_cache');
        if (cachedData != null) {
          final List<dynamic> data = jsonDecode(cachedData);
          final cachedPosts = data.map((json) => FeedPost.fromJson(json)).toList();
          if (cachedPosts.isNotEmpty) {
            state = AsyncValue.data(cachedPosts);
            debugPrint('✅ [CACHE] Feed chargé instantanément (${cachedPosts.length} posts)');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Erreur lecture cache feed: $e');
      }
    }

    if (!isRefresh && state.hasValue && state.value!.isNotEmpty) {
      _isLoadingMore = true;
    } else if (!state.hasValue) {
      // Afficher le loader uniquement si on n'a pas de cache
      state = const AsyncValue.loading();
    }

    try {
      final storage = SecureStorageService();
      final token = await storage.getToken();
      
      final dio = Dio();
      final url = '${ApiConfig.baseUrl}/api/feed';
      final queryParams = _nextCursor != null ? {'cursor': _nextCursor} : null;

      final response = await dio.get(
        url,
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['posts'];
        final posts = data.map((json) => FeedPost.fromJson(json)).toList();
        
        _nextCursor = response.data['nextCursor'];
        _hasMore = _nextCursor != null;

        if (isRefresh || (!isFirstLoad && !state.hasValue) || isFirstLoad) {
          state = AsyncValue.data(posts);
          // Si c'est la première page, on met à jour le cache
          if (_nextCursor == null || _nextCursor == response.data['nextCursor']) {
            await HiveCacheService.setCache('feed_cache', jsonEncode(data));
          }
        } else {
          state = AsyncValue.data([...state.value!, ...posts]);
        }
      }
    } catch (e, st) {
      debugPrint('❌ Erreur fetchFeed: $e');
      if (!state.hasValue) {
        state = AsyncValue.error("Erreur de chargement du fil d'actualité", st);
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> loadMore() async {
    await fetchFeed();
  }

  Future<void> toggleLike(int postId) async {
    if (!state.hasValue) return;
    
    // Mise à jour optimiste
    final currentPosts = state.value!;
    final postIndex = currentPosts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = currentPosts[postIndex];
    final isLikedNow = !post.isLikedByMe;
    final newLikesCount = isLikedNow ? post.likesCount + 1 : post.likesCount - 1;

    final updatedPost = post.copyWith(
      isLikedByMe: isLikedNow,
      likesCount: newLikesCount,
    );

    final updatedPosts = List<FeedPost>.from(currentPosts);
    updatedPosts[postIndex] = updatedPost;
    state = AsyncValue.data(updatedPosts);

    // Requête serveur
    try {
      final storage = SecureStorageService();
      final token = await storage.getToken();
      
      final dio = Dio();
      await dio.post(
        '${ApiConfig.baseUrl}/api/feed/$postId/like',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      debugPrint('❌ Erreur toggleLike: $e');
      // Rollback en cas d'erreur
      updatedPosts[postIndex] = post;
      state = AsyncValue.data(updatedPosts);
    }
  }

  Future<bool> createPost(String content, {File? mediaFile, String? mediaType}) async {
    try {
      final storage = SecureStorageService();
      final token = await storage.getToken();
      
      final dio = Dio();
      dynamic data;

      if (mediaFile != null) {
        data = FormData.fromMap({
          'content': content,
          'media_type': mediaType ?? 'image',
          'media': await MultipartFile.fromFile(mediaFile.path),
        });
      } else {
        data = {'content': content, 'media_type': 'text'};
      }

      final response = await dio.post(
        '${ApiConfig.baseUrl}/api/feed',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 201) {
        // Ajouter le nouveau post au début de la liste
        final newPost = FeedPost.fromJson(response.data['post']);
        if (state.hasValue) {
          state = AsyncValue.data([newPost, ...state.value!]);
        } else {
          state = AsyncValue.data([newPost]);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erreur createPost: $e');
      return false;
    }
  }

  // --- COMMENTS ---
  
  Future<List<Map<String, dynamic>>> fetchComments(int postId) async {
    try {
      final storage = SecureStorageService();
      final token = await storage.getToken();
      
      final dio = Dio();
      final response = await dio.get(
        '${ApiConfig.baseUrl}/api/feed/$postId/comments',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['comments'];
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Erreur fetchComments: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> addComment(int postId, String content) async {
    try {
      final storage = SecureStorageService();
      final token = await storage.getToken();
      
      final dio = Dio();
      final response = await dio.post(
        '${ApiConfig.baseUrl}/api/feed/$postId/comments',
        data: {'content': content},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 201) {
        // Mettre à jour le compteur de commentaires localement
        if (state.hasValue) {
          final currentPosts = state.value!;
          final postIndex = currentPosts.indexWhere((p) => p.id == postId);
          if (postIndex != -1) {
            final post = currentPosts[postIndex];
            final updatedPost = post.copyWith(commentsCount: post.commentsCount + 1);
            final updatedPosts = List<FeedPost>.from(currentPosts);
            updatedPosts[postIndex] = updatedPost;
            state = AsyncValue.data(updatedPosts);
          }
        }
        return response.data['comment'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur addComment: $e');
      return null;
    }
  }
}
