import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_filters_provider.dart';

/// Bottom Sheet pour les filtres de recherche
class SearchFiltersSheet extends ConsumerStatefulWidget {
  final List<String> availableCategories;

  const SearchFiltersSheet({
    super.key,
    required this.availableCategories,
  });

  @override
  ConsumerState<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends ConsumerState<SearchFiltersSheet> {
  final TextEditingController _minPriceCtrl = TextEditingController();
  final TextEditingController _maxPriceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final filters = ref.read(searchFiltersProvider);
    _minPriceCtrl.text = filters.minPrice?.toString() ?? '';
    _maxPriceCtrl.text = filters.maxPrice?.toString() ?? '';
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtres',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Catégories (dynamiques basées sur les résultats)
          if (widget.availableCategories.isNotEmpty) ...[
            const Text(
              'CATÉGORIES',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.availableCategories.map((category) {
                final isSelected = filters.category == category;
                return FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    ref.read(searchFiltersProvider.notifier).setCategory(
                          selected ? category : null,
                        );
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Prix
          const Text(
            'PRIX (CDF)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Min',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('-'),
              ),
              Expanded(
                child: TextField(
                  controller: _maxPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Boutiques
          const Text(
            'BOUTIQUES',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool?>(
                  title: const Text('Toutes', style: TextStyle(fontSize: 14)),
                  value: null,
                  groupValue: filters.verifiedShopsOnly,
                  dense: true,
                  onChanged: (val) {
                    ref.read(searchFiltersProvider.notifier).setVerifiedShopsOnly(val);
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<bool?>(
                  title: const Text('Vérifiées', style: TextStyle(fontSize: 14)),
                  value: true,
                  groupValue: filters.verifiedShopsOnly,
                  dense: true,
                  onChanged: (val) {
                    ref.read(searchFiltersProvider.notifier).setVerifiedShopsOnly(val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stock
          CheckboxListTile(
            title: const Text('Produits en stock uniquement', style: TextStyle(fontSize: 14)),
            value: filters.inStockOnly ?? false,
            dense: true,
            onChanged: (val) {
              ref.read(searchFiltersProvider.notifier).setInStockOnly(val);
            },
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(searchFiltersProvider.notifier).reset();
                    _minPriceCtrl.clear();
                    _maxPriceCtrl.clear();
                  },
                  child: const Text('Réinitialiser'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Appliquer les filtres de prix
                    final minPrice = double.tryParse(_minPriceCtrl.text);
                    final maxPrice = double.tryParse(_maxPriceCtrl.text);
                    ref.read(searchFiltersProvider.notifier).setPriceRange(minPrice, maxPrice);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E7DBA),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Appliquer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
