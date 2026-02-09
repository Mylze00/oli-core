import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product_model.dart';

/// Résultat de l'autocomplétion
class AutocompleteResult {
  final List<String> suggestions;
  final String query;

  AutocompleteResult({
    required this.suggestions,
    required this.query,
  });
}

/// Provider pour l'autocomplétion
class AutocompleteNotifier extends StateNotifier<AutocompleteResult> {
  AutocompleteNotifier()
      : super(AutocompleteResult(suggestions: [], query: ''));

  /// G énère des suggestions basées sur la recherche
  void getSuggestions(
    String query,
    List<Product> products,
    List<String> searchHistory,
  ) {
    if (query.trim().isEmpty) {
      state = AutocompleteResult(suggestions: [], query: '');
      return;
    }

    final lowerQuery = query.toLowerCase().trim();
    final suggestions = <String>[];

    // 1. Suggestions depuis les produits (max 5)
    final productSuggestions = products
        .where((p) => p.name.toLowerCase().contains(lowerQuery))
        .map((p) => p.name)
        .toSet()
        .take(5)
        .toList();
    suggestions.addAll(productSuggestions);

    // 2. Suggestions depuis l'historique (max 5)
    final historySuggestions = searchHistory
        .where((h) => h.toLowerCase().contains(lowerQuery))
        .take(5)
        .toList();
    suggestions.addAll(historySuggestions);

    // 3. Retirer les doublons et limiter à 10 au total
    final uniqueSuggestions = suggestions.toSet().take(10).toList();

    state = AutocompleteResult(
      suggestions: uniqueSuggestions,
      query: query,
    );
  }

  /// Nettoie les suggestions
  void clear() {
    state = AutocompleteResult(suggestions: [], query: '');
  }
}

/// Provider Riverpod
final autocompleteProvider =
    StateNotifierProvider<AutocompleteNotifier, AutocompleteResult>((ref) {
  return AutocompleteNotifier();
});
