import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/feed_model.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/services/hive_cache_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode du Fil : 'for_you' (classé par l'algorithme) ou 'following' (contacts, chronologique).
final feedModeProvider = StateProvider<String>((ref) => 'for_you');

final feedProvider = StateNotifierProvider<FeedNotifier, AsyncValue<List<FeedPost>>>((ref) {
  return FeedNotifier(ref);
});

/// Lecture automatique des vidéos du Fil (muettes, quand elles sont visibles). Mémorisée.
final feedAutoplayProvider = StateNotifierProvider<FeedAutoplayNotifier, bool>((ref) => FeedAutoplayNotifier());

class FeedAutoplayNotifier extends StateNotifier<bool> {
  static const _key = 'feed_autoplay_videos';

  FeedAutoplayNotifier() : super(true) {
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) state = prefs.getBool(_key) ?? true;
    }).catchError((_) {});
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      (await SharedPreferences.getInstance()).setBool(_key, value);
    } catch (_) {}
  }
}

class FeedNotifier extends StateNotifier<AsyncValue<List<FeedPost>>> {
  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  final Ref _ref;

  FeedNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchFeed();
  }

  String get _mode => _ref.read(feedModeProvider);
  String get _cacheKey => 'feed_cache_$_mode';

  /// Change de mode (« Pour vous » / « Abonnement ») et recharge depuis le début.
  Future<void> setMode(String mode) async {
    if (_ref.read(feedModeProvider) == mode) return;
    _ref.read(feedModeProvider.notifier).state = mode;
    state = const AsyncValue.loading();
    await fetchFeed(isRefresh: true);
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
        final cachedData = await HiveCacheService.getCache(_cacheKey);
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
      final queryParams = {'mode': _mode, if (_nextCursor != null) 'cursor': _nextCursor};

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
            await HiveCacheService.setCache(_cacheKey, jsonEncode(data));
          }
        } else {
          // Sans doublon : le classement peut bouger entre deux pages
          final known = state.value!.map((p) => p.id).toSet();
          state = AsyncValue.data([...state.value!, ...posts.where((p) => known.add(p.id))]);
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

  // ─── Actions façon X ──────────────────────────────────────────────

  Future<Options> _auth() async {
    final token = await SecureStorageService().getToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Remplace un post dans la liste (mise à jour immédiate de l'écran).
  void _replace(int postId, FeedPost Function(FeedPost) update) {
    if (!state.hasValue) return;
    state = AsyncValue.data([
      for (final p in state.value!) p.id == postId ? update(p) : p,
    ]);
  }

  void _remove(int postId) {
    if (!state.hasValue) return;
    state = AsyncValue.data(state.value!.where((p) => p.id != postId).toList());
  }

  FeedPost? postById(int postId) => state.value?.where((p) => p.id == postId).firstOrNull;

  /// Republier / annuler la republication.
  Future<void> toggleRepost(FeedPost post) async {
    final on = !post.isRepostedByMe;
    _replace(post.id, (p) => p.copyWith(isRepostedByMe: on, repostsCount: p.repostsCount + (on ? 1 : -1)));
    try {
      final r = await Dio().post('${ApiConfig.baseUrl}/api/feed/${post.id}/repost', options: await _auth());
      _replace(post.id, (p) => p.copyWith(isRepostedByMe: r.data['reposted'] == true, repostsCount: r.data['count']));
    } catch (e) {
      debugPrint('❌ Republication: $e');
      _replace(post.id, (p) => p.copyWith(isRepostedByMe: post.isRepostedByMe, repostsCount: post.repostsCount));
    }
  }

  /// Enregistrer / retirer des enregistrements.
  Future<void> toggleBookmark(FeedPost post) async {
    final on = !post.isBookmarkedByMe;
    _replace(post.id, (p) => p.copyWith(isBookmarkedByMe: on, bookmarksCount: p.bookmarksCount + (on ? 1 : -1)));
    try {
      final r = await Dio().post('${ApiConfig.baseUrl}/api/feed/${post.id}/bookmark', options: await _auth());
      _replace(post.id, (p) => p.copyWith(isBookmarkedByMe: r.data['bookmarked'] == true, bookmarksCount: r.data['count']));
    } catch (e) {
      debugPrint('❌ Enregistrement: $e');
      _replace(post.id, (p) => p.copyWith(isBookmarkedByMe: post.isBookmarkedByMe, bookmarksCount: post.bookmarksCount));
    }
  }

  /// Compte une vue (ouverture de la page « Post »).
  Future<void> recordView(int postId) async {
    try {
      final r = await Dio().post('${ApiConfig.baseUrl}/api/feed/$postId/view', options: await _auth());
      final views = int.tryParse('${r.data['views_count']}');
      if (views != null) _replace(postId, (p) => p.copyWith(viewsCount: views));
    } catch (_) {}
  }

  /// Détail à jour d'un post (page « Post »).
  Future<FeedPost?> fetchPost(int postId) async {
    try {
      final r = await Dio().get('${ApiConfig.baseUrl}/api/feed/$postId', options: await _auth());
      final post = FeedPost.fromJson(Map<String, dynamic>.from(r.data['post']));
      _replace(postId, (_) => post);
      return post;
    } catch (e) {
      debugPrint('❌ Détail du post: $e');
      return null;
    }
  }

  /// Masquer : le post disparaît du fil de l'utilisateur.
  Future<bool> hidePost(int postId) async {
    _remove(postId);
    try {
      await Dio().post('${ApiConfig.baseUrl}/api/feed/$postId/hide', options: await _auth());
      return true;
    } catch (e) {
      debugPrint('❌ Masquer: $e');
      return false;
    }
  }

  /// Signaler (reason = 'report') ou marquer comme spam (reason = 'spam').
  Future<bool> reportPost(int postId, {required String reason, String? details}) async {
    _remove(postId);
    try {
      await Dio().post(
        '${ApiConfig.baseUrl}/api/feed/$postId/report',
        data: {'reason': reason, if (details != null) 'details': details},
        options: await _auth(),
      );
      return true;
    } catch (e) {
      debugPrint('❌ Signalement: $e');
      return false;
    }
  }

  /// Supprimer son propre post.
  Future<bool> deletePost(int postId) async {
    try {
      await Dio().delete('${ApiConfig.baseUrl}/api/feed/$postId', options: await _auth());
      _remove(postId);
      return true;
    } catch (e) {
      debugPrint('❌ Suppression: $e');
      return false;
    }
  }

  /// Interactions (auteur seulement) : compteurs, personnes qui ont aimé ou republié.
  Future<Map<String, dynamic>?> fetchInteractions(int postId) async {
    try {
      final r = await Dio().get('${ApiConfig.baseUrl}/api/feed/$postId/interactions', options: await _auth());
      return Map<String, dynamic>.from(r.data);
    } catch (e) {
      debugPrint('❌ Interactions: $e');
      return null;
    }
  }

  /// J'aime sur une réponse : renvoie { liked, count } ou null en cas d'échec.
  Future<Map<String, dynamic>?> toggleCommentLike(int commentId) async {
    try {
      final r = await Dio().post('${ApiConfig.baseUrl}/api/feed/comments/$commentId/like', options: await _auth());
      return Map<String, dynamic>.from(r.data);
    } catch (e) {
      debugPrint('❌ J\'aime réponse: $e');
      return null;
    }
  }

  /// Après un commentaire publié : compteur à jour.
  void incrementComments(int postId) => _replace(postId, (p) => p.copyWith(commentsCount: p.commentsCount + 1));

  Future<bool> createPost(String content, {XFile? mediaFile, String? mediaType, int? quotePostId}) async {
    try {
      final storage = SecureStorageService();
      final token = await storage.getToken();
      
      final dio = Dio();
      dynamic data;

      if (mediaFile != null) {
        final bytes = await mediaFile.readAsBytes();
        data = FormData.fromMap({
          'content': content,
          if (quotePostId != null) 'quote_post_id': quotePostId,
          'media_type': mediaType ?? 'image',
          'media': MultipartFile.fromBytes(bytes, filename: mediaFile.name),
        });
      } else {
        data = {'content': content, 'media_type': 'text', if (quotePostId != null) 'quote_post_id': quotePostId};
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

  Future<Map<String, dynamic>?> addComment(int postId, String content, {XFile? mediaFile, String? mediaType}) async {
    try {
      final storage = SecureStorageService();
      final token = await storage.getToken();
      
      final dio = Dio();
      dynamic data;

      if (mediaFile != null) {
        final bytes = await mediaFile.readAsBytes();
        data = FormData.fromMap({
          'content': content,
          'media_type': mediaType ?? 'image',
          'media': MultipartFile.fromBytes(bytes, filename: mediaFile.name),
        });
      } else {
        data = {'content': content};
      }

      final response = await dio.post(
        '${ApiConfig.baseUrl}/api/feed/$postId/comments',
        data: data,
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
