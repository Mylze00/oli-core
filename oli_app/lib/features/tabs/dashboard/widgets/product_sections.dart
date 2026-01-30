import 'package:flutter/material.dart';
import '../../../marketplace/presentation/pages/product_details_page.dart';
import '../../../../models/product_model.dart';
import 'product_card_common.dart';
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade600],
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
              const Text("🏪 Grands Magasins", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
            ],
          ),
          const SizedBox(height: 4),
          Text("Supermarchés et commerces vérifiés", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
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
                    priceColor: Colors.blueAccent,
                    badgeText: "Vérifié",
                    badgeColor: Colors.green,
                    badgeOnRight: true,
                    subtitleWidget: product.shopName != null
                      ? Text(product.shopName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[500], fontSize: 10))
                      : null,
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

class TopRankingGrid extends StatelessWidget {
  final List<Product> products;

  const TopRankingGrid({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
             if (products.isEmpty) return Container(color: Colors.grey[900]);
            final product = products[index];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
              child: MarketProductCard(product: product),
            );
          },
          childCount: products.isEmpty ? 6 : products.length,
        ),
      ),
    );
  }
}

/// New widget: Displays exactly 3 products in a horizontal row
class FeaturedProductsRow extends StatelessWidget {
  final List<Product> products;

  const FeaturedProductsRow({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    // Take only first 3 products
    final displayProducts = products.take(3).toList();
    
    if (displayProducts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "✨ Produits en vedette",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: displayProducts.asMap().entries.map((entry) {
              final product = entry.value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailsPage(product: product),
                    ),
                  ),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: entry.key < 2 ? 8 : 0,
                    ),
                    child: MarketProductCard(product: product),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

