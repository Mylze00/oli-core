import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../marketplace/providers/market_provider.dart';
import '../../../marketplace/presentation/pages/product_details_page.dart';
import '../../../marketplace/presentation/widgets/market_product_card.dart';
import '../../../../app/theme/theme_provider.dart';

/// Super Offres Page — Produits les plus visités
class SuperOffresPage extends ConsumerStatefulWidget {
  const SuperOffresPage({super.key});

  @override
  ConsumerState<SuperOffresPage> createState() => _SuperOffresPageState();
}

class _SuperOffresPageState extends ConsumerState<SuperOffresPage>
    with SingleTickerProviderStateMixin {
  String _sortBy = 'views'; // 'views', 'price_asc', 'price_desc', 'recent'
  String _selectedCategory = 'Tout';
  late AnimationController _headerAnimController;
  late Animation<double> _headerFadeAnimation;

  final Map<String, String> _categories = {
    "Tout": "",
    "Électronique": "electronics",
    "Mode": "fashion",
    "Maison": "home",
    "Beauté": "beauty",
    "Sports": "sports",
    "Véhicules": "vehicles",
    "Jouets": "toys",
    "Alimentation": "food",
  };

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerFadeAnimation = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOut,
    );
    _headerAnimController.forward();
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    super.dispose();
  }

  List<Product> _sortAndFilter(List<Product> products) {
    var filtered = List<Product>.from(products);

    // Filter by category
    if (_selectedCategory != 'Tout') {
      final catKey = _categories[_selectedCategory] ?? '';
      if (catKey.isNotEmpty) {
        filtered = filtered
            .where((p) => p.category?.toLowerCase() == catKey.toLowerCase())
            .toList();
      }
    }

    // Sort
    switch (_sortBy) {
      case 'views':
        filtered.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        break;
      case 'price_asc':
        filtered.sort((a, b) {
          final pa = double.tryParse(a.price) ?? 0;
          final pb = double.tryParse(b.price) ?? 0;
          return pa.compareTo(pb);
        });
        break;
      case 'price_desc':
        filtered.sort((a, b) {
          final pa = double.tryParse(a.price) ?? 0;
          final pb = double.tryParse(b.price) ?? 0;
          return pb.compareTo(pa);
        });
        break;
      case 'recent':
        filtered.sort((a, b) {
          final da = a.createdAt ?? DateTime(2000);
          final db = b.createdAt ?? DateTime(2000);
          return db.compareTo(da);
        });
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final backgroundColor = isDark ? Colors.black : Colors.grey[100];
    final textColor = isDark ? Colors.white : Colors.black;
    final topProducts = ref.watch(topSellersProvider);

    final sortedProducts = _sortAndFilter(topProducts);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── HEADER ──
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background fire image
                  Image.asset(
                    'assets/images/fire_bg.png',
                    fit: BoxFit.cover,
                  ),
                  // Dark overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),
                  // Title content
                  FadeTransition(
                    opacity: _headerFadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department,
                                  color: Colors.orangeAccent, size: 32),
                              const SizedBox(width: 10),
                              const Text(
                                "Super Offres",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 26,
                                  shadows: [
                                    Shadow(color: Colors.black54, blurRadius: 8)
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${sortedProducts.length} produits les plus populaires",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              collapseMode: CollapseMode.parallax,
            ),
          ),

          // ── SORT & FILTER BAR ──
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
              child: Column(
                children: [
                  // Sort chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSortChip('🔥 Plus vus', 'views', isDark),
                        _buildSortChip('💰 Prix ↑', 'price_asc', isDark),
                        _buildSortChip('💎 Prix ↓', 'price_desc', isDark),
                        _buildSortChip('🆕 Récents', 'recent', isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Category chips
                  SizedBox(
                    height: 34,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final label = _categories.keys.elementAt(index);
                        final isSelected = label == _selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCategory = label),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.orangeAccent
                                    : (isDark
                                        ? const Color(0xFF2C2C2C)
                                        : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.grey.withOpacity(0.3)),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── PRODUCT COUNT ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${sortedProducts.length} résultat${sortedProducts.length > 1 ? 's' : ''}',
                    style: TextStyle(
                        color: textColor.withOpacity(0.5), fontSize: 12),
                  ),
                  if (_selectedCategory != 'Tout')
                    GestureDetector(
                      onTap: () => setState(() => _selectedCategory = 'Tout'),
                      child: const Row(
                        children: [
                          Icon(Icons.clear, size: 14, color: Colors.orangeAccent),
                          SizedBox(width: 4),
                          Text('Effacer',
                              style: TextStyle(
                                  color: Colors.orangeAccent, fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── PRODUCTS GRID ──
          if (sortedProducts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_fire_department,
                        size: 48, color: textColor.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Text('Aucune super offre trouvée',
                        style: TextStyle(color: textColor, fontSize: 16)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = sortedProducts[index];
                    return _SuperOfferProductCard(
                      product: product,
                      rank: _sortBy == 'views' ? index + 1 : null,
                    );
                  },
                  childCount: sortedProducts.length,
                ),
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value, bool isDark) {
    final isSelected = _sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _sortBy = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFF6B35)
                : (isDark ? const Color(0xFF1E1E1E) : Colors.grey[200]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// Product card with optional ranking badge and view count
class _SuperOfferProductCard extends ConsumerWidget {
  final Product product;
  final int? rank;

  const _SuperOfferProductCard({
    required this.product,
    this.rank,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exchangeState = ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProductDetailsPage(product: product)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: rank != null && rank! <= 3
              ? Border.all(
                  color: rank == 1
                      ? Colors.amber
                      : (rank == 2
                          ? Colors.grey[400]!
                          : Colors.orange[700]!),
                  width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Product image with lazy loading
                    product.images.isEmpty
                        ? Container(
                            color: const Color(0xFF2C2C2C),
                            child: const Center(
                                child: Icon(Icons.image,
                                    size: 36, color: Colors.grey)),
                          )
                        : Image.network(
                            product.images[0],
                            fit: BoxFit.cover,
                            frameBuilder: (context, child, frame,
                                wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded) return child;
                              return AnimatedOpacity(
                                opacity: frame == null ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOut,
                                child: child,
                              );
                            },
                            loadingBuilder:
                                (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: const Color(0xFF1A1A1A),
                                child: Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey[700],
                                      value: loadingProgress
                                                  .expectedTotalBytes !=
                                              null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (ctx, err, stack) => const Center(
                                child: Icon(Icons.broken_image,
                                    size: 28, color: Colors.grey)),
                          ),

                    // Rank badge (top 3)
                    if (rank != null && rank! <= 3)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: rank == 1
                                ? Colors.amber
                                : (rank == 2
                                    ? Colors.grey[400]
                                    : Colors.orange[700]),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            rank == 1
                                ? '🥇 #1'
                                : (rank == 2 ? '🥈 #2' : '🥉 #3'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else if (rank != null)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$rank',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // View count badge
                    if (product.viewCount > 0)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility,
                                  size: 10, color: Colors.white70),
                              const SizedBox(width: 3),
                              Text(
                                _formatViewCount(product.viewCount),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Product info
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10, height: 1.2),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    exchangeNotifier.formatProductPrice(
                        double.tryParse(product.price) ?? 0.0),
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatViewCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}
