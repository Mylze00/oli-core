import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../config/api_config.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../utils/cloudinary_helper.dart';
import '../../../search/widgets/search_result_card.dart';
import '../pages/product_details_page.dart';

/// Page dédiée pour afficher les produits d'une catégorie
class CategoryProductsPage extends ConsumerStatefulWidget {
  final String categoryKey;   // 'electronics', 'fashion', etc.
  final String categoryLabel; // 'Électronique', 'Mode', etc.
  final IconData? categoryIcon;
  /// Produits OLI admin pré-filtrés par catégorie (optionnel)
  final List<Product> oliProducts;

  const CategoryProductsPage({
    super.key,
    required this.categoryKey,
    required this.categoryLabel,
    this.categoryIcon,
    this.oliProducts = const [],
  });

  @override
  ConsumerState<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends ConsumerState<CategoryProductsPage> {
  List<Product> _products = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 30;
  String _sortBy = 'recent'; // 'recent', 'price_asc', 'price_desc', 'popular'
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) {
        _loadMore();
      }
    }
  }

  Future<void> _fetchProducts({bool append = false}) async {
    if (!append) {
      setState(() {
        _isLoading = true;
        _offset = 0;
      });
    }

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/products').replace(
        queryParameters: {
          'category': widget.categoryKey,
          'limit': '$_pageSize',
          'offset': '$_offset',
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
          _hasMore = decoded['hasMore'] ?? false;
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

        if (products.length < _pageSize) _hasMore = false;
        _offset += products.length;

        if (mounted) {
          setState(() {
            if (append) {
              _products.addAll(products);
            } else {
              _products = products;
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error fetching category products: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoading = true);
    await _fetchProducts(append: true);
  }

  List<Product> _getSortedProducts() {
    final sorted = List<Product>.from(_products);
    switch (_sortBy) {
      case 'price_asc':
        sorted.sort((a, b) => (double.tryParse(a.price) ?? 0).compareTo(double.tryParse(b.price) ?? 0));
        break;
      case 'price_desc':
        sorted.sort((a, b) => (double.tryParse(b.price) ?? 0).compareTo(double.tryParse(a.price) ?? 0));
        break;
      case 'popular':
        sorted.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        break;
      case 'recent':
      default:
        // API returns in chronological order
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final sortedProducts = _getSortedProducts();
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            if (widget.categoryIcon != null) ...[
              Icon(widget.categoryIcon, size: 22, color: Colors.blueAccent),
              const SizedBox(width: 10),
            ],
            Text(
              widget.categoryLabel,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Colors.white70),
            color: const Color(0xFF21262D),
            onSelected: (value) {
              setState(() => _sortBy = value);
            },
            itemBuilder: (context) => [
              _buildSortItem('recent', 'Plus récents', Icons.access_time),
              _buildSortItem('price_asc', 'Prix croissant', Icons.arrow_upward),
              _buildSortItem('price_desc', 'Prix décroissant', Icons.arrow_downward),
              _buildSortItem('popular', 'Plus populaires', Icons.trending_up),
            ],
          ),
        ],
      ),
      body: _isLoading && _products.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _products.isEmpty && widget.oliProducts.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // ── Section OLI admin (si des produits OLI sont disponibles) ──
                    if (widget.oliProducts.isNotEmpty) _buildOliSection(),
                    // Compteur de résultats marketplace
                    if (_products.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: const Color(0xFF161B22),
                        child: Text(
                          '${_products.length} produit${_products.length > 1 ? 's' : ''} sur le marché',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    // Grille de produits marketplace
                    if (_products.isNotEmpty)
                      Expanded(
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.62,
                        ),
                        itemCount: sortedProducts.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= sortedProducts.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2),
                              ),
                            );
                          }

                          final product = sortedProducts[index];
                          final priceUsd = double.tryParse(product.price) ?? 0.0;
                          final formattedPrice = exchangeNotifier.formatProductPrice(priceUsd);

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailsPage(product: product),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image du produit
                                  Expanded(
                                    flex: 3,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                      child: product.images.isNotEmpty
                                          ? Image.network(
                                              CloudinaryHelper.thumbnail(product.images.first),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              errorBuilder: (_, __, ___) => Container(
                                                color: const Color(0xFF21262D),
                                                child: const Icon(Icons.image_not_supported, color: Colors.white24, size: 40),
                                              ),
                                            )
                                          : Container(
                                              color: const Color(0xFF21262D),
                                              child: const Icon(Icons.image, color: Colors.white24, size: 40),
                                            ),
                                    ),
                                  ),
                                  // Infos produit
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            formattedPrice,
                                            style: const TextStyle(
                                              color: Colors.blueAccent,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Spacer(),
                                          Row(
                                            children: [
                                              Icon(
                                                product.sellerIsVerified ? Icons.verified : Icons.storefront,
                                                size: 12,
                                                color: product.sellerIsVerified ? Colors.blue : Colors.white38,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  product.seller,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              if (product.viewCount > 0) ...[
                                                const Icon(Icons.visibility, size: 11, color: Colors.white24),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '${product.viewCount}',
                                                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  PopupMenuItem<String> _buildSortItem(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isSelected ? Colors.blueAccent : Colors.white54),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blueAccent : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section horizontale Produits OLI ────────────────────────────────────
  Widget _buildOliSection() {
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    return Container(
      color: const Color(0xFF0D1117),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFFAA00)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Sélection OLI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.oliProducts.length} article${widget.oliProducts.length > 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          // Carousel horizontal
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.oliProducts.length,
              itemBuilder: (context, index) {
                final product = widget.oliProducts[index];
                final priceUsd = double.tryParse(product.price) ?? 0.0;
                final formattedPrice = exchangeNotifier.formatProductPrice(priceUsd);
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailsPage(product: product),
                    ),
                  ),
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 10, bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF6B00).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: SizedBox(
                            height: 110,
                            width: double.infinity,
                            child: product.images.isNotEmpty
                                ? Image.network(
                                    CloudinaryHelper.thumbnail(product.images.first),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFF21262D),
                                      child: const Icon(Icons.image, color: Colors.white24, size: 32),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFF21262D),
                                    child: const Icon(Icons.image, color: Colors.white24, size: 32),
                                  ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  formattedPrice,
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B00),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (product.subcategory != null) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      product.subcategory!.replaceAll('_', ' '),
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Séparateur
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.categoryIcon ?? Icons.category,
            size: 64,
            color: Colors.white.withOpacity(0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun produit dans "${widget.categoryLabel}"',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les produits apparaîtront ici dès qu\'ils seront ajoutés',
            style: TextStyle(color: Colors.white30, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
