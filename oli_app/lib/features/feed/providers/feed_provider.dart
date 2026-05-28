import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/feed_model.dart';
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';

final feedProvider = StateNotifierProvider<FeedNotifier, AsyncValue<List<FeedPost>>>((ref) {
  return FeedNotifier();
});

class FeedNotifier extends StateNotifier<AsyncValue<List<FeedPost>>> {
  FeedNotifier() : super(const AsyncValue.loading()) {
    fetchFeed();
  }

  Future<void> fetchFeed() async {
    try {
      final storage = SecureStorageService();
      final token = await storage.getToken();
      
      final dio = Dio();
      final response = await dio.get(
        '${ApiConfig.baseUrl}/api/feed',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['posts'];
        final posts = data.map((json) => FeedPost.fromJson(json)).toList();
        state = AsyncValue.data(posts);
      }
    } catch (e, st) {
      debugPrint('❌ Erreur fetchFeed: $e');
      state = AsyncValue.error("Erreur de chargement du fil d'actualité", st);
    }
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

  Future<bool> createPost(String content) async {
    try {
      final storage = SecureStorageService();
      final token = await storage.getToken();
      
      final dio = Dio();
      final response = await dio.post(
        '${ApiConfig.baseUrl}/api/feed',
        data: {'content': content, 'media_type': 'text'},
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
}
