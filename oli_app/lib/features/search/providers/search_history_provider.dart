import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider pour gérer l'historique de recherche (max 15 éléments)
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  static const String _storageKey = 'search_history';
  static const int _maxHistoryItems = 15;

  SearchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  /// Charge l'historique depuis SharedPreferences
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_storageKey) ?? [];
      state = history;
    } catch (e) {
      print('❌ Erreur chargement historique: $e');
      state = [];
    }
  }

  /// Sauvegarde l'historique dans SharedPreferences
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, state);
    } catch (e) {
      print('❌ Erreur sauvegarde historique: $e');
    }
  }

  /// Ajoute une recherche à l'historique
  Future<void> add(String query) async {
    if (query.trim().isEmpty) return;

    final trimmedQuery = query.trim();
    
    // Retirer si déjà présent
    final newHistory = state.where((item) => item != trimmedQuery).toList();
    
    // Ajouter en première position
    newHistory.insert(0, trimmedQuery);
    
    // Limiter à 15 éléments
    if (newHistory.length > _maxHistoryItems) {
      newHistory.removeRange(_maxHistoryItems, newHistory.length);
    }
    
    state = newHistory;
    await _saveHistory();
  }

  /// Supprime une recherche de l'historique
  Future<void> remove(String query) async {
    state = state.where((item) => item != query).toList();
    await _saveHistory();
  }

  /// Vide tout l'historique
  Future<void> clear() async {
    state = [];
    await _saveHistory();
  }
}

/// Provider Riverpod
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});
