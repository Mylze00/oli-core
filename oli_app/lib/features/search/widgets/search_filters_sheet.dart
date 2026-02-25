import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_filters_provider.dart';

/// Bottom Sheet pour les filtres de recherche
class SearchFiltersSheet extends ConsumerStatefulWidget {
  final List<String> availableCategories;
  final List<String> availableSellers;
  final List<String> availableLocations;
  final double maxProductPrice;

  const SearchFiltersSheet({
    super.key,
    required this.availableCategories,
    this.availableSellers = const [],
    this.availableLocations = const [],
    this.maxProductPrice = 1000,
  });

  @override
  ConsumerState<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends ConsumerState<SearchFiltersSheet> {
  late RangeValues _priceRange;
  final TextEditingController _locationCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final filters = ref.read(searchFiltersProvider);
    _priceRange = RangeValues(
      filters.minPrice ?? 0,
      filters.maxPrice ?? widget.maxProductPrice,
    );
    _locationCtrl.text = filters.location ?? '';
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 16),

            // ── PRIX (RangeSlider) ──
            const Text(
              'PRIX',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPriceLabel(_priceRange.start),
                const Text('—', style: TextStyle(color: Colors.grey)),
                _buildPriceLabel(_priceRange.end),
              ],
            ),
            RangeSlider(
              values: _priceRange,
              min: 0,
              max: widget.maxProductPrice,
              divisions: 50,
              activeColor: const Color(0xFF1E7DBA),
              labels: RangeLabels(
                '\$${_priceRange.start.toInt()}',
                '\$${_priceRange.end.toInt()}',
              ),
              onChanged: (values) {
                setState(() => _priceRange = values);
              },
            ),
            const SizedBox(height: 16),

            // ── CATÉGORIES ──
            if (widget.availableCategories.isNotEmpty) ...[
              const Text(
                'CATÉGORIES',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.availableCategories.map((category) {
                  final isSelected = filters.category == category;
                  return FilterChip(
                    label: Text(category, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : null)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1E7DBA),
                    checkmarkColor: Colors.white,
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

            // ── VENDEURS ──
            if (widget.availableSellers.isNotEmpty) ...[
              const Text(
                'VENDEURS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.availableSellers.map((seller) {
                  final isSelected = filters.sellerName == seller;
                  return FilterChip(
                    avatar: CircleAvatar(
                      backgroundColor: const Color(0xFF1E7DBA).withOpacity(0.2),
                      child: Text(
                        seller.isNotEmpty ? seller[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF1E7DBA),
                        ),
                      ),
                    ),
                    label: Text(
                      seller,
                      style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : null),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1E7DBA),
                    checkmarkColor: Colors.white,
                    onSelected: (selected) {
                      ref.read(searchFiltersProvider.notifier).setSellerName(
                            selected ? seller : null,
                          );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // ── LOCALISATION ──
            const Text(
              'LOCALISATION',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (widget.availableLocations.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.availableLocations.map((loc) {
                  final isSelected = filters.location == loc;
                  return FilterChip(
                    avatar: Icon(Icons.location_on, size: 16, color: isSelected ? Colors.white : Colors.orange),
                    label: Text(loc, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : null)),
                    selected: isSelected,
                    selectedColor: Colors.orange.shade700,
                    checkmarkColor: Colors.white,
                    onSelected: (selected) {
                      ref.read(searchFiltersProvider.notifier).setLocation(
                            selected ? loc : null,
                          );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _locationCtrl,
              decoration: InputDecoration(
                hintText: 'Ex: Lubumbashi, Kinshasa...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // ── BOUTIQUES ──
            const Text(
              'BOUTIQUES',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
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
            const SizedBox(height: 8),

            // ── STOCK ──
            CheckboxListTile(
              title: const Text('Produits en stock uniquement', style: TextStyle(fontSize: 14)),
              value: filters.inStockOnly ?? false,
              dense: true,
              activeColor: const Color(0xFF1E7DBA),
              onChanged: (val) {
                ref.read(searchFiltersProvider.notifier).setInStockOnly(val);
              },
            ),
            const SizedBox(height: 20),

            // ── BOUTONS ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(searchFiltersProvider.notifier).reset();
                      setState(() {
                        _priceRange = RangeValues(0, widget.maxProductPrice);
                        _locationCtrl.clear();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Appliquer les filtres de prix via le slider
                      final minPrice = _priceRange.start > 0 ? _priceRange.start : null;
                      final maxPrice = _priceRange.end < widget.maxProductPrice ? _priceRange.end : null;
                      ref.read(searchFiltersProvider.notifier).setPriceRange(minPrice, maxPrice);

                      // Appliquer le filtre localisation (texte libre)
                      final locText = _locationCtrl.text.trim();
                      if (locText.isNotEmpty) {
                        ref.read(searchFiltersProvider.notifier).setLocation(locText);
                      }

                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E7DBA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceLabel(double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E7DBA).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '\$${value.toInt()}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Color(0xFF1E7DBA),
        ),
      ),
    );
  }
}
