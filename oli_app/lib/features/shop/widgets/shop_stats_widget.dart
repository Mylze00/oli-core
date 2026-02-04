import 'package:flutter/material.dart';
import '../../../models/product_model.dart';

/// Stats de la boutique (Produits, Promotions, Note)
class ShopStatsWidget extends StatelessWidget {
  final List<Product> products;
  final double shopRating;

  const ShopStatsWidget({
    super.key,
    required this.products,
    required this.shopRating,
  });

  @override
  Widget build(BuildContext context) {
    final totalProducts = products.length;
    final activePromotions = products.where((p) => p.discountPrice != null).length;

    final stats = [
      {
        'label': 'Produits',
        'value': totalProducts.toString(),
        'icon': Icons.shopping_bag,
        'color': const Color(0xFF6C63FF),
      },
      {
        'label': 'Promotions',
        'value': activePromotions.toString(),
        'icon': Icons.local_offer,
        'color': const Color(0xFFFF6B6B),
      },
      {
        'label': 'Note',
        'value': shopRating.toStringAsFixed(1),
        'icon': Icons.star,
        'color': const Color(0xFFFFBE0B),
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: stats.map((stat) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Icon(stat['icon'] as IconData, color: stat['color'] as Color, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    stat['value'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stat['label'] as String,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
