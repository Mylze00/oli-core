import 'package:flutter/material.dart';
import '../../../../models/product_model.dart';
import '../../../marketplace/presentation/pages/product_details_page.dart';

class BonDealsGrid extends StatelessWidget {
  final List<Product> deals;

  const BonDealsGrid({super.key, required this.deals});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Fond sombre différent
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("🔥 Bons Deals", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: deals.length > 4 ? 4 : deals.length, // Max 4 produits
              itemBuilder: (context, index) {
                final product = deals[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            child: Stack(
                              children: [
                                product.images.isNotEmpty
                                    ? Image.network(product.images.first, width: double.infinity, height: double.infinity, fit: BoxFit.cover)
                                    : Container(color: Colors.grey, child: const Center(child: Icon(Icons.image))),
                                Positioned(
                                  top: 0, left: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    color: Colors.red,
                                    child: Text(
                                      product.promoPrice != null && (double.tryParse(product.price) ?? 0) > 0
                                        ? "-${((1 - (product.promoPrice! / (double.tryParse(product.price) ?? 1))) * 100).round()}%" 
                                        : "PROMO",
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.price.toString() + "\$", 
                                style: const TextStyle(
                                  color: Colors.grey, 
                                  fontSize: 10, 
                                  decoration: TextDecoration.lineThrough
                                )
                              ),
                              Text(
                                (product.promoPrice ?? product.price).toString() + "\$", 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
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
