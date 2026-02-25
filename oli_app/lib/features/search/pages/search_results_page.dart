import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../models/product_model.dart';
import '../widgets/search_result_card.dart';
import '../providers/search_filters_provider.dart';
import '../providers/search_history_provider.dart';
import '../widgets/search_filters_sheet.dart';
import '../widgets/product_request_widget.dart';

/// Page dédiée pour afficher les résultats de recherche
class SearchResultsPage extends ConsumerStatefulWidget {
  final String initialQuery;

  const SearchResultsPage({
    super.key,
    required this.initialQuery,
  });

  @override
  ConsumerState<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends ConsumerState<SearchResultsPage> {
  late TextEditingController _searchController;
  List<Product> _filteredProducts = [];
  List<Product> _allSearchResults = [];
  bool _isLoading = false;

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

  /// Effectue la recherche via l'API backend puis applique les filtres avec tri par pertinence
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredProducts = [];
        _allSearchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Appel API direct — indépendant de la page market
      final uri = Uri.parse('${ApiConfig.baseUrl}/products').replace(
        queryParameters: {
          'search': query.trim(),
          'limit': '100',
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['products'] != null) {
          data = decoded['products'] as List<dynamic>;
        } else {
          data = [];
        }

        final products = <Product>[];
        for (final json in data) {
          try {
            products.add(Product.fromJson(json));
          } catch (e) {
            debugPrint('⚠️ Skipping malformed product: $e');
          }
        }

        _allSearchResults = products;
      } else {
        debugPrint('❌ Search API error: ${response.statusCode}');
        _allSearchResults = [];
      }
    } catch (e) {
      debugPrint('❌ Search error: $e');
      _allSearchResults = [];
    }

    // Tri par pertinence côté client
    final filters = ref.read(searchFiltersProvider);
    final lowerQuery = query.toLowerCase().trim();
    final queryWords = lowerQuery.split(RegExp(r'\s+'));

    var results = List<Product>.from(_allSearchResults);

    // Tri par pertinence (starts-with en premier, puis par nombre de matches)
    results.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();

      // Priorité 1 : Le nom commence par la requête complète
      final aStartsFull = aName.startsWith(lowerQuery);
      final bStartsFull = bName.startsWith(lowerQuery);
      if (aStartsFull && !bStartsFull) return -1;
      if (bStartsFull && !aStartsFull) return 1;

      // Priorité 2 : Le nom commence par le premier mot recherché
      final aStartsFirst = aName.startsWith(queryWords.first);
      final bStartsFirst = bName.startsWith(queryWords.first);
      if (aStartsFirst && !bStartsFirst) return -1;
      if (bStartsFirst && !aStartsFirst) return 1;

      // Priorité 3 : Le mot-clé est dans le nom (pas juste la description)
      final aInName = queryWords.every((w) => aName.contains(w));
      final bInName = queryWords.every((w) => bName.contains(w));
      if (aInName && !bInName) return -1;
      if (bInName && !aInName) return 1;

      // Priorité 4 : Nombre de vues (popularité)
      return b.viewCount.compareTo(a.viewCount);
    });

    // Appliquer les autres filtres
    results = _applyFilters(results, filters);

    if (mounted) {
      setState(() {
        _filteredProducts = results;
        _isLoading = false;
      });
    }
  }

  /// Applique les filtres actifs
  List<Product> _applyFilters(List<Product> products, filters) {
    var filtered = products;

    // Filtre catégorie
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

    // Filtre vendeur
    if (filters.sellerName != null) {
      filtered = filtered.where((p) =>
          p.seller.toLowerCase() == filters.sellerName!.toLowerCase()).toList();
    }

    // Filtre localisation
    if (filters.location != null) {
      final loc = filters.location!.toLowerCase();
      filtered = filtered.where((p) =>
          p.location != null && p.location!.toLowerCase().contains(loc)).toList();
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

  /// Extrait les vendeurs uniques depuis les résultats
  List<String> _getAvailableSellers() {
    return _filteredProducts
        .where((p) => p.seller.isNotEmpty)
        .map((p) => p.seller)
        .toSet()
        .toList()..sort();
  }

  /// Extrait les localisations uniques depuis les résultats
  List<String> _getAvailableLocations() {
    return _filteredProducts
        .where((p) => p.location != null && p.location!.isNotEmpty)
        .map((p) => p.location!)
        .toSet()
        .toList()..sort();
  }

  /// Calcule le prix maximum parmi les résultats
  double _getMaxPrice() {
    if (_allSearchResults.isEmpty) return 1000;
    double maxP = 0;
    for (final p in _allSearchResults) {
      final price = double.tryParse(p.price) ?? 0;
      if (price > maxP) maxP = price;
    }
    // Arrondir au centième supérieur
    return (maxP / 100).ceilToDouble() * 100;
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
                      availableSellers: _getAvailableSellers(),
                      availableLocations: _getAvailableLocations(),
                      maxProductPrice: _getMaxPrice(),
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
                      avatar: const Icon(Icons.category, size: 16),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        ref.read(searchFiltersProvider.notifier).clearCategory();
                        _performSearch(_searchController.text);
                      },
                    ),
                  if (filters.minPrice != null || filters.maxPrice != null)
                    Chip(
                      label: Text(
                        '\$${filters.minPrice?.toInt() ?? 0} - \$${filters.maxPrice?.toInt() ?? "∞"}',
                      ),
                      avatar: const Icon(Icons.attach_money, size: 16),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        ref.read(searchFiltersProvider.notifier).clearPrice();
                        _performSearch(_searchController.text);
                      },
                    ),
                  if (filters.sellerName != null)
                    Chip(
                      label: Text(filters.sellerName!),
                      avatar: const Icon(Icons.store, size: 16),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        ref.read(searchFiltersProvider.notifier).clearSellerName();
                        _performSearch(_searchController.text);
                      },
                    ),
                  if (filters.location != null)
                    Chip(
                      label: Text(filters.location!),
                      avatar: const Icon(Icons.location_on, size: 16),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        ref.read(searchFiltersProvider.notifier).clearLocation();
                        _performSearch(_searchController.text);
                      },
                    ),
                  if (filters.verifiedShopsOnly == true)
                    Chip(
                      label: const Text('Boutiques vérifiées'),
                      avatar: const Icon(Icons.verified, size: 16, color: Colors.blue),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        ref.read(searchFiltersProvider.notifier).clearShopType();
                        _performSearch(_searchController.text);
                      },
                    ),
                  if (filters.inStockOnly == true)
                    Chip(
                      label: const Text('En stock'),
                      avatar: const Icon(Icons.inventory, size: 16),
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
                '${_filteredProducts.length} produit${_filteredProducts.length > 1 ? 's' : ''} trouvé${_filteredProducts.length > 1 ? 's' : ''} chez ${_getGroupedProducts().length} vendeur${_getGroupedProducts().length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
          ),

          // Liste des résultats groupés par vendeur
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E7DBA)))
                : _filteredProducts.isEmpty
                    ? _buildEmptyState()
                    : _buildGroupedResults(),
          ),
        ],
      ),
    );
  }

  /// Regroupe les produits par vendeur (sellerId)
  LinkedHashMap<String, List<Product>> _getGroupedProducts() {
    final grouped = LinkedHashMap<String, List<Product>>();
    for (final product in _filteredProducts) {
      final key = product.sellerId.isNotEmpty ? product.sellerId : product.seller;
      grouped.putIfAbsent(key, () => []).add(product);
    }
    return grouped;
  }

  /// Construit la liste groupée par vendeur
  Widget _buildGroupedResults() {
    final grouped = _getGroupedProducts();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final sellerId = grouped.keys.elementAt(index);
        final products = grouped[sellerId]!;
        final firstProduct = products.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête vendeur
            Container(
              margin: EdgeInsets.only(top: index == 0 ? 0 : 16, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  // Avatar vendeur
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF1E7DBA),
                    backgroundImage: firstProduct.sellerAvatar != null &&
                            firstProduct.sellerAvatar!.isNotEmpty
                        ? NetworkImage(firstProduct.sellerAvatar!)
                        : null,
                    child: firstProduct.sellerAvatar == null ||
                            firstProduct.sellerAvatar!.isEmpty
                        ? Text(
                            firstProduct.seller.isNotEmpty
                                ? firstProduct.seller[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  // Nom du vendeur
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                firstProduct.seller,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (firstProduct.sellerIsVerified)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.verified,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                              ),
                            if (firstProduct.sellerHasCertifiedShop)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Certifié',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '${products.length} produit${products.length > 1 ? 's' : ''} trouvé${products.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                            if (firstProduct.location != null && firstProduct.location!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  firstProduct.location!,
                                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Icône chevron
                  Icon(
                    Icons.storefront_outlined,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ),
            // Produits du vendeur
            ...products.map((product) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SearchResultCard(product: product),
                )),
          ],
        );
      },
    );
  }

  /// Widget affiché quand aucun résultat
  Widget _buildEmptyState() {
    // Show product request widget when no results found
    if (_searchController.text.trim().isNotEmpty) {
      return SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.search_off, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Aucun produit trouvé',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            // Product Request Widget
            ProductRequestWidget(searchQuery: _searchController.text.trim()),
          ],
        ),
      );
    }

    // Default empty state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucun résultat',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
