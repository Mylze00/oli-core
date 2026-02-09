import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product_model.dart';
import '../widgets/search_result_card.dart';
import '../providers/search_filters_provider.dart';
import '../providers/search_history_provider.dart';
import '../widgets/search_filters_sheet.dart';

/// Page dédiée pour afficher les résultats de recherche
class SearchResultsPage extends ConsumerStatefulWidget {
  final String initialQuery;
  final List<Product> allProducts;

  const SearchResultsPage({
    super.key,
    required this.initialQuery,
    required this.allProducts,
  });

  @override
  ConsumerState<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends ConsumerState<SearchResultsPage> {
  late TextEditingController _searchController;
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _performSearch(widget.initialQuery);
    
    // Ajouter à l'historique
    if (widget.initialQuery.isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).add(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Effectue la recherche et applique les filtres
  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredProducts = [];
      });
      return;
    }

    final filters = ref.read(searchFiltersProvider);
    final lowerQuery = query.toLowerCase();

    // 1. Filtrer par recherche textuelle
    var results = widget.allProducts.where((product) {
      return product.name.toLowerCase().contains(lowerQuery) ||
          (product.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();

    // 2. Appliquer les autres filtres
    results = _applyFilters(results, filters);

    setState(() {
      _filteredProducts = results;
    });
  }

  /// Applique les filtres actifs
  List<Product> _applyFilters(List<Product> products, filters) {
    var filtered = products;

    // Filtre catégorie (utilise maintenant le vrai champ category)
    if (filters.category != null) {
      filtered = filtered.where((p) {
        return p.category?.toLowerCase() == filters.category!.toLowerCase();
      }).toList();
    }
    
    // Filtre prix
    if (filters.minPrice != null) {
      filtered = filtered.where((p) {
        final price = double.tryParse(p.price) ?? 0;
        return price >= filters.minPrice!;
      }).toList();
    }
    if (filters.maxPrice != null) {
      filtered = filtered.where((p) {
        final price = double.tryParse(p.price) ?? 0;
        return price <= filters.maxPrice!;
      }).toList();
    }

    // Filtre boutiques vérifiées
    if (filters.verifiedShopsOnly == true) {
      filtered = filtered.where((p) => p.shopVerified == true).toList();
    }

    // Filtre disponibilité
    if (filters.inStockOnly == true) {
      filtered = filtered.where((p) => p.quantity > 0).toList();
    }

    return filtered;
  }

  /// Extrait les catégories disponibles depuis les résultats
  List<String> _getAvailableCategories() {
    return _filteredProducts
        .where((p) => p.category != null && p.category!.isNotEmpty)
        .map((p) => p.category!)
        .toSet()
        .toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E7DBA),
        foregroundColor: Colors.white,
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Rechercher...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            suffixIcon: Icon(Icons.search, color: Colors.white),
          ),
          onSubmitted: (value) {
            _performSearch(value);
            ref.read(searchHistoryProvider.notifier).add(value);
          },
        ),
        actions: [
          // Bouton filtres avec badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Filtres',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => SearchFiltersSheet(
                      availableCategories: _getAvailableCategories(),
                    ),
                  ).then((_) {
                    // Réappliquer la recherche après modification des filtres
                    _performSearch(_searchController.text);
                  });
                },
              ),
              if (filters.hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${filters.activeFiltersCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres actifs chips
          if (filters.hasActiveFilters)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.grey[100],
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (filters.category != null)
                    Chip(
                      label: Text(filters.category!),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        ref.read(searchFiltersProvider.notifier).clearCategory();
                        _performSearch(_searchController.text);
                      },
                    ),
                  if (filters.minPrice != null || filters.maxPrice != null)
                    Chip(
                      label: Text(
                        '${filters.minPrice?.toInt() ?? 0} - ${filters.maxPrice?.toInt() ?? "∞"} CDF',
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        ref.read(searchFiltersProvider.notifier).clearPrice();
                        _performSearch(_searchController.text);
                      },
                    ),
                  if (filters.verifiedShopsOnly == true)
                    Chip(
                      label: const Text('Boutiques vérifiées'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        ref.read(searchFiltersProvider.notifier).clearShopType();
                        _performSearch(_searchController.text);
                      },
                    ),
                  if (filters.inStockOnly == true)
                    Chip(
                      label: const Text('En stock'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        ref.read(searchFiltersProvider.notifier).clearStock();
                        _performSearch(_searchController.text);
                      },
                    ),
                ],
              ),
            ),

          // Nombre de résultats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredProducts.length} produit${_filteredProducts.length > 1 ? 's' : ''} trouvé${_filteredProducts.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
          ),

          // Liste des résultats (disposition horizontale)
          Expanded(
            child: _filteredProducts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SearchResultCard(product: _filteredProducts[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Widget affiché quand aucun résultat
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun produit trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez d\'ajuster vos filtres ou votre recherche',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
