import 'package:flutter/material.dart';
import '../../../models/product_model.dart';
import '../../marketplace/presentation/pages/product_details_page.dart';

/// Section horizontale de produits avec gradient et badges
class HorizontalProductSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Product> products;
  final String badgeText;
  final Color badgeColor;
  final List<Color> gradient;
  final String Function(double price) formatPrice;

  const HorizontalProductSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.products,
    required this.badgeText,
    required this.badgeColor,
    required this.gradient,
    required this.formatPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                child: product.images.isNotEmpty 
                                  ? Image.network(product.images.first, fit: BoxFit.cover, width: double.infinity)
                                  : const Center(child: Icon(Icons.image, color: Colors.grey)),
                              ),
                              Positioned(
                                top: 0, left: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10)),
                              Text(
                                formatPrice(double.tryParse(product.price) ?? 0.0), 
                                style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)
                              ),
                            ],
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
}
