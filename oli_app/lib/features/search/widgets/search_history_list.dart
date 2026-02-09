import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_history_provider.dart';

/// Widget affichant l'historique de recherche
class SearchHistoryList extends ConsumerWidget {
  final Function(String) onSearchTap;

  const SearchHistoryList({
    super.key,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);

    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recherches récentes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(searchHistoryProvider.notifier).clear();
                },
                child: const Text('Tout effacer', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final query = history[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.history, size: 20, color: Colors.grey),
              title: Text(
                query,
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  ref.read(searchHistoryProvider.notifier).remove(query);
                },
              ),
              onTap: () => onSearchTap(query),
            );
          },
        ),
      ],
    );
  }
}
