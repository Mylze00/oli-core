import 'dart:math';
import 'package:flutter/material.dart';
import '../../../models/product_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/exchange_rate_provider.dart';

/// Widget affichant les produits populaires de la boutique (8 produits aléatoires)
class PopularProductsCircles extends ConsumerWidget {
  final String title;
  final List<Product> products;
  final Function(Product product)? onProductTap;

  const PopularProductsCircles({
    super.key,
    this.title = "Populaire sur la boutique",
    required this.products,
    this.onProductTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) return const SizedBox.shrink();
    
    // Sélectionner 8 produits aléatoires
    final random = Random();
    final shuffled = List<Product>.from(products)..shuffle(random);
    final displayProducts = shuffled.take(8).toList();
    
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ligne de séparation pointillée
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: CustomPaint(
            size: const Size(double.infinity, 1),
            painter: _DashedLinePainter(
              color: Colors.grey.withOpacity(0.6), // Gris 60%
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Padding réduit (top 24 -> 8)
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: displayProducts.length,
            itemBuilder: (context, index) {
              final product = displayProducts[index];
              // Couleurs alternées pour les bordures
              final colors = [
                const Color(0xFF3665F3), // Bleu
                const Color(0xFFE53238), // Rouge
                const Color(0xFFF5AF02), // Jaune
                const Color(0xFF86B817), // Vert
                const Color(0xFF9B59B6), // Violet
                const Color(0xFF00BCD4), // Cyan
              ];
              final borderColor = colors[index % colors.length];
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: GestureDetector(
                  onTap: () => onProductTap?.call(product),
                  child: Column(
                    children: [
                      // Image circulaire du produit
                      Container(
                        width: 85,
                        height: 85,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: borderColor,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: borderColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[900],
                            image: product.imageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(product.imageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: product.imageUrl == null
                              ? const Icon(Icons.shopping_bag, color: Colors.white54, size: 30)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Nom du produit
                      SizedBox(
                        width: 90,
                        child: Text(
                          product.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Prix du produit
                      Text(
                        exchangeNotifier.formatProductPrice(double.tryParse(product.price) ?? 0.0),
                        style: TextStyle(
                          color: borderColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  _DashedLinePainter({
    required this.color,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
