import 'package:flutter/material.dart';

/// Dropdown d'autocomplétion qui apparaît sous la barre de recherche
class AutocompleteDropdown extends StatelessWidget {
  final List<String> suggestions;
  final List<String> historyItems;
  final String query;
  final Function(String) onSuggestionTap;

  const AutocompleteDropdown({
    super.key,
    required this.suggestions,
    required this.historyItems,
    required this.query,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: suggestions.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            final isFromHistory = historyItems.contains(suggestion);

            return ListTile(
              dense: true,
              leading: Icon(
                isFromHistory ? Icons.history : Icons.search,
                size: 20,
                color: Colors.grey[600],
              ),
              title: _buildHighlightedText(suggestion, query),
              onTap: () => onSuggestionTap(suggestion),
            );
          },
        ),
      ),
    );
  }

  /// Met en surbrillance le texte correspondant à la recherche
  Widget _buildHighlightedText(String text, String query) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return Text(
        text,
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }
}
