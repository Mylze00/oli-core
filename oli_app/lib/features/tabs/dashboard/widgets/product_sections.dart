import 'package:flutter/material.dart';
import '../../../marketplace/presentation/pages/product_details_page.dart';
import '../../../../models/product_model.dart';
import 'product_card_common.dart';
import '../pages/verified_shops_products_page.dart';
import '../../../marketplace/presentation/widgets/market_product_card.dart';

class TopSellersSection extends StatelessWidget {
  final List<Product> products;

  const TopSellersSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade900, Colors.orange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("⭐ Meilleurs Vendeurs", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Icon(Icons.trending_up, color: Colors.white.withOpacity(0.8), size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text("Les produits les plus populaires", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: products.isEmpty ? 3 : products.length,
              itemBuilder: (context, index) {
                if (products.isEmpty) return _buildPlaceholderCard();
                final product = products[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
                  child: DashboardProductCard(
                    product: product,
                    priceColor: Colors.orange,
                    badgeText: "TOP",
                    badgeColor: Colors.orange,
                    subtitleWidget: Row(
                      children: [
                        const Icon(Icons.visibility, size: 10, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text("Populaire", style: TextStyle(color: Colors.grey[500], fontSize: 10)),
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

  Widget _buildPlaceholderCard() {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      color: Colors.grey[900],
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class VerifiedShopProductsSection extends StatelessWidget {
  final List<Product> products;

  const VerifiedShopProductsSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // ── Drapeau DRC en fond (40% opacité) ──
            Positioned.fill(
              child: Opacity(
                opacity: 0.4,
                child: Image.asset(
                  'assets/images/drc flag.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // ── Gradient bleu par-dessus pour lisibilité ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade900.withOpacity(0.78),
                      Colors.blue.shade700.withOpacity(0.60),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // ── Contenu ──
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Grands Magasins", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: Colors.white, size: 12),
                                SizedBox(width: 2),
                                Text("Certifié", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const VerifiedShopsProductsPage()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("Supermarchés et commerces vérifiés", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: Builder(
                      builder: (context) {
                        // Diversifier: max 1 produit par boutique (dédup par shopId en priorité, sinon shopName)
                        final diversified = <Product>[];
                        final seenShops = <String>{};
                        for (final p in products) {
                          // Filtrer les noms génériques
                          final rawShopName = p.shopName ?? '';
                          final isGenericName = rawShopName.toUpperCase().contains('BOUTIQUE ENTREPRISE') ||
                              rawShopName.toUpperCase() == 'BOUTIQUE';

                          // Clé de déduplication : shopId en priorité, sinon shopName, sinon seller
                          final shopKey = p.shopId ?? (isGenericName ? null : p.shopName) ?? p.seller;
                          if (!seenShops.contains(shopKey)) {
                            seenShops.add(shopKey);
                            diversified.add(p);
                          }
                        }
                        final displayProducts = diversified.isEmpty ? products : diversified;

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: displayProducts.isEmpty ? 3 : displayProducts.length,
                          itemBuilder: (context, index) {
                            if (displayProducts.isEmpty) return _buildPlaceholderCard();
                            final product = displayProducts[index];
                            return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
                              child: DashboardProductCard(
                                product: product,
                                priceColor: Colors.blueAccent,
                                priceFontSize: 12,
                                badgeText: "Vérifié",
                                badgeColor: Colors.green,
                                badgeOnRight: true,
                                cardColor: Colors.white,
                                imageBackgroundColor: Colors.white,
                                subtitleWidget: () {
                                  final rawShopName = product.shopName ?? '';
                                  final isGenericName = rawShopName.toUpperCase().contains('BOUTIQUE ENTREPRISE') ||
                                      rawShopName.toUpperCase() == 'BOUTIQUE';
                                  final displayName = (!isGenericName && rawShopName.isNotEmpty)
                                      ? rawShopName
                                      : product.seller;
                                  return Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                                  );
                                }(),
                              ),
                            );
                          },
                        );
                      },
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

  
  Widget _buildPlaceholderCard() {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      color: Colors.grey[900],
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class TopRankingGrid extends StatelessWidget {
  final List<Product> products;
  final int crossAxisCount;
  final double childAspectRatio;
  /// Index global du premier produit de ce chunk dans la liste totale du classement
  final int startIndex;

  /// Positions (1-indexées) où afficher l'animation badge note
  static const Set<int> rankingPositions = {1, 5, 15, 22, 35, 50};

  const TopRankingGrid({
    super.key, 
    required this.products,
    this.crossAxisCount = 3,
    this.childAspectRatio = 0.75,
    this.startIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
             if (products.isEmpty) return Container(color: Colors.grey[900]);
            final product = products[index];
            final globalPos = startIndex + index + 1; // 1-indexé
            final showBadge = rankingPositions.contains(globalPos);
            return MarketProductCard(product: product, showRatingAnimation: showBadge);
          },
          childCount: products.isEmpty ? 6 : products.length,
        ),
      ),
    );
  }
}
