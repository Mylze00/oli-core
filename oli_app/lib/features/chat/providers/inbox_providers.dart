import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/services/hive_cache_service.dart';
import '../../../core/user/user_provider.dart';

// ─── Providers Riverpod ──────────────────────────────────────────

/// Inbox Conversations Provider (Offline-First)
final inboxConversationsProvider = StateNotifierProvider<ConversationsNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final user = ref.watch(userProvider).value;
  return ConversationsNotifier(user?.id.toString());
});

class ConversationsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final String? userId;
  bool _isLoading = false;

  ConversationsNotifier(this.userId) : super(const AsyncValue.loading()) {
    if (userId != null) {
      fetchConversations();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> fetchConversations() async {
    if (_isLoading) return;
    _isLoading = true;

    // --- CACHE OFFLINE-FIRST ---
    if (!state.hasValue || state.value!.isEmpty) {
      try {
        final cachedData = await HiveCacheService.getCache('inbox_cache_$userId');
        if (cachedData != null) {
          final List<dynamic> data = jsonDecode(cachedData);
          final cachedConversations = List<Map<String, dynamic>>.from(data);
          if (cachedConversations.isNotEmpty) {
            state = AsyncValue.data(cachedConversations);
            debugPrint('✅ [CACHE] Inbox chargé instantanément');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Erreur lecture cache inbox: $e');
      }
    }

    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }

    try {
      final storage = SecureStorageService();
      final token = await storage.getToken();
      if (token == null || token.isEmpty) {
        _isLoading = false;
        return;
      }

      final dio = Dio();
      final response = await dio.get(
        '${ApiConfig.baseUrl}/chat/conversations',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final conversations = List<Map<String, dynamic>>.from(response.data);
        state = AsyncValue.data(conversations);
        // Mise à jour du cache
        await HiveCacheService.setCache('inbox_cache_$userId', jsonEncode(response.data));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint('⚠️ conversations 401 : token expiré ou invalide');
      } else {
        debugPrint('❌ Erreur chargement conversations: $e');
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement conversations: $e');
    } finally {
      _isLoading = false;
    }
  }
}

/// Conversations épinglées (Set de otherId)
final pinnedConversationsProvider =
    StateNotifierProvider<PinnedNotifier, Set<String>>((ref) => PinnedNotifier());

class PinnedNotifier extends StateNotifier<Set<String>> {
  static const _key = 'pinned_conversations';

  PinnedNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    state = Set.from(list);
  }

  Future<void> toggle(String id) async {
    final newSet = Set<String>.from(state);
    if (newSet.contains(id)) {
      newSet.remove(id);
    } else {
      if (newSet.length >= 3) {
        // Max 3 épingles
        return;
      }
      newSet.add(id);
    }
    state = newSet;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, newSet.toList());
  }

  bool isPinned(String id) => state.contains(id);
}

/// Conversations archivées (Set de otherId)
final archivedConversationsProvider =
    StateNotifierProvider<ArchivedNotifier, Set<String>>((ref) => ArchivedNotifier());

class ArchivedNotifier extends StateNotifier<Set<String>> {
  static const _key = 'archived_conversations';

  ArchivedNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    state = Set.from(list);
  }

  Future<void> archive(String id) async {
    final newSet = Set<String>.from(state)..add(id);
    state = newSet;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, newSet.toList());
  }

  Future<void> unarchive(String id) async {
    final newSet = Set<String>.from(state)..remove(id);
    state = newSet;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, newSet.toList());
  }

  bool isArchived(String id) => state.contains(id);
}

/// Messages éphémères par conversationId : null = off, sinon durée en jours
final ephemeralProvider =
    StateNotifierProvider.family<EphemeralNotifier, int?, String>(
        (ref, convId) => EphemeralNotifier(convId));

class EphemeralNotifier extends StateNotifier<int?> {
  final String convId;
  static const _prefix = 'ephemeral_';

  EphemeralNotifier(this.convId) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getInt('$_prefix$convId');
    state = val;
  }

  Future<void> set(int? days) async {
    state = days;
    final prefs = await SharedPreferences.getInstance();
    if (days == null) {
      await prefs.remove('$_prefix$convId');
    } else {
      await prefs.setInt('$_prefix$convId', days);
    }
  }
}

// ─── Filtre actif de l'inbox ─────────────────────────────────────

enum InboxFilter { all, unread, favorites, archives }
