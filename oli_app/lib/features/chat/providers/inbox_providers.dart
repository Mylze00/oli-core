import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Providers Riverpod ──────────────────────────────────────────

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
