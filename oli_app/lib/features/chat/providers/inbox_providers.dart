import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/services/database_helper.dart';
import '../../../core/services/hive_cache_service.dart'; // keeping for fallback if needed
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

    // --- CACHE OFFLINE-FIRST (SQLite) ---
    if (!state.hasValue || state.value!.isEmpty) {
      try {
        final db = await DatabaseHelper.instance.database;
        final List<Map<String, dynamic>> maps = await db.query(
          'conversations',
          where: 'user_id = ?',
          whereArgs: [userId],
          orderBy: 'is_pinned DESC, last_message_time DESC',
        );

        if (maps.isNotEmpty) {
          final cachedConversations = maps.map((m) {
            final raw = jsonDecode(m['raw_data'] as String);
            return Map<String, dynamic>.from(raw);
          }).toList();
          
          state = AsyncValue.data(cachedConversations);
          debugPrint('✅ [CACHE] Inbox chargé depuis SQLite');
        }
      } catch (e) {
        debugPrint('⚠️ Erreur lecture cache SQLite inbox: $e');
      }
    }

    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }

    try {
      final storage = SecureStorageService();
      final token = await storage.getToken();
      if (token == null || token.isEmpty) {
        if (!state.hasValue) state = const AsyncValue.data([]);
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
        
        // Mise à jour de SQLite
        try {
          final db = await DatabaseHelper.instance.database;
          final batch = db.batch();
          for (var conv in conversations) {
            batch.insert('conversations', {
              'conversation_id': conv['id'],
              'user_id': userId,
              'other_user_id': conv['other_user']?['id']?.toString() ?? '',
              'last_message_content': conv['last_message']?['content'] ?? '',
              'last_message_time': conv['last_message']?['created_at'] ?? '',
              'raw_data': jsonEncode(conv),
            }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace); // need sqflite import!
          }
          await batch.commit(noResult: true);
        } catch(e) {
           debugPrint('Erreur insertion SQLite inbox: $e');
        }
      } else {
        if (!state.hasValue) state = const AsyncValue.data([]);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint('⚠️ conversations 401 : token expiré ou invalide');
        if (!state.hasValue) state = const AsyncValue.data([]);
      } else {
        debugPrint('❌ Erreur chargement conversations: $e');
        if (!state.hasValue) state = const AsyncValue.data([]); // Fallback to empty list instead of error to avoid breaking UI completely
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement conversations: $e');
      if (!state.hasValue) state = const AsyncValue.data([]);
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
