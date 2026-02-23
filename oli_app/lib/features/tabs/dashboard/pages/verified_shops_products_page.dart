import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../marketplace/providers/market_provider.dart';
import '../../../marketplace/presentation/pages/product_details_page.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../utils/cloudinary_helper.dart';

/// Page affichant tous les produits de boutiques certifiées
class VerifiedShopsProductsPage extends ConsumerStatefulWidget {
  const VerifiedShopsProductsPage({super.key});

  @override
  ConsumerState<VerifiedShopsProductsPage> createState() => _VerifiedShopsProductsPageState();
}

class _VerifiedShopsProductsPageState extends ConsumerState<VerifiedShopsProductsPage> {
  String _sortBy = 'shop'; // 'shop', 'price_asc', 'price_desc', 'recent'
  String _selectedShop = 'Tout';

  List<Product> _filterAndSort(List<Product> products) {
    // Exclure les produits admin OLI (sécurité côté frontend)
    var filtered = products.where((p) => 
      p.sellerAccountType != 'admin' && 
      p.sellerId != 'admin'
    ).toList();

    // Filtrer par boutique
    if (_selectedShop != 'Tout') {
      filtered = filtered.where((p) => 
        (p.shopName ?? p.seller) == _selectedShop
      ).toList();
    }

    // Tri
    switch (_sortBy) {
      case 'shop':
        filtered.sort((a, b) => (a.shopName ?? a.seller).compareTo(b.shopName ?? b.seller));
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
    final products = ref.watch(verifiedShopsProductsProvider);
    final sortedProducts = _filterAndSort(products);

    // Extraire les noms de boutiques uniques pour le filtre
    final shopNames = <String>{'Tout'};
    for (final p in products) {
      final name = p.shopName ?? p.seller;
      if (name.isNotEmpty) shopNames.add(name);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── HEADER ──
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: Colors.blue.shade900,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade900, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Text("🏪", style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 10),
                          const Text(
                            "Grands Magasins",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: Colors.white, size: 12),
                                SizedBox(width: 3),
                                Text("Certifié", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${sortedProducts.length} produits de supermarchés et commerces vérifiés",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
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
                        _buildSortChip('🏪 Par boutique', 'shop', isDark),
                        _buildSortChip('💰 Prix ↑', 'price_asc', isDark),
                        _buildSortChip('💎 Prix ↓', 'price_desc', isDark),
                        _buildSortChip('🆕 Récents', 'recent', isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Shop filter chips
                  SizedBox(
                    height: 34,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: shopNames.length,
                      itemBuilder: (context, index) {
                        final name = shopNames.elementAt(index);
                        final isSelected = name == _selectedShop;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedShop = name),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.shade700
                                    : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.grey.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected && name != 'Tout')
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(Icons.verified, size: 12, color: Colors.white),
                                    ),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.white70 : Colors.black87),
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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

          // ── RESULT COUNT ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${sortedProducts.length} produit${sortedProducts.length > 1 ? 's' : ''}',
                    style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12),
                  ),
                  if (_selectedShop != 'Tout')
                    GestureDetector(
                      onTap: () => setState(() => _selectedShop = 'Tout'),
                      child: Row(
                        children: [
                          Icon(Icons.clear, size: 14, color: Colors.blue.shade400),
                          const SizedBox(width: 4),
                          Text('Tout voir', style: TextStyle(color: Colors.blue.shade400, fontSize: 12)),
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
                    Icon(Icons.store, size: 48, color: textColor.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Text('Aucun produit trouvé', style: TextStyle(color: textColor, fontSize: 16)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = sortedProducts[index];
                    return _VerifiedShopCard(product: product);
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
                ? Colors.blue.shade700
                : (isDark ? const Color(0xFF1E1E1E) : Colors.grey[200]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// Card for verified shop product
class _VerifiedShopCard extends ConsumerWidget {
  final Product product;

  const _VerifiedShopCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    ref.watch(exchangeRateProvider);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    product.images.isEmpty
                        ? Container(
                            color: const Color(0xFF2C2C2C),
                            child: const Center(child: Icon(Icons.image, size: 36, color: Colors.grey)),
                          )
                        : Image.network(
                            CloudinaryHelper.thumbnail(product.images[0]),
                            fit: BoxFit.cover,
                            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded) return child;
                              return AnimatedOpacity(
                                opacity: frame == null ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOut,
                                child: child,
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: const Color(0xFF1A1A1A),
                                child: Center(
                                  child: SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey[700],
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (ctx, err, stack) =>
                                const Center(child: Icon(Icons.broken_image, size: 28, color: Colors.grey)),
                          ),

                    // Verified badge
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 10, color: Colors.white),
                            SizedBox(width: 2),
                            Text("Vérifié", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
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
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exchangeNotifier.formatProductPrice(double.tryParse(product.price) ?? 0.0),
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (product.shopName != null && product.shopName!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.store, size: 10, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.shopName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[500], fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
