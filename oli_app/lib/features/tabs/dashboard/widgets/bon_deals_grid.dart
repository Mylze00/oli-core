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
            child: deals.isEmpty 
              ? const Center(child: Text("Aucun deal", style: TextStyle(color: Colors.white54, fontSize: 10)))
              : Row(
                  children: [
                    // ITEM 1 (GRAND À GAUCHE)
                    Expanded(
                      flex: 2, // Prend plus de place si possible ou 50/50 ? Mettons 1 pour 50/50 avec la colonne
                      child: _buildDealTile(context, deals[0], isBig: true),
                    ),
                    
                    // COLONNE DROITE (ITEMS 2 & 3)
                    if (deals.length > 1) ...[
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 1, // Colonne droite
                        child: Column(
                          children: [
                            Expanded(child: _buildDealTile(context, deals[1], isSmall: true)),
                            if (deals.length > 2) ...[
                              const SizedBox(height: 4),
                              Expanded(child: _buildDealTile(context, deals[2], isSmall: true)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDealTile(BuildContext context, Product product, {bool isBig = false, bool isSmall = false}) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product.images.isNotEmpty
                    ? Image.network(product.images.first, fit: BoxFit.cover)
                    : Container(color: Colors.grey[800], child: const Icon(Icons.image, color: Colors.white54)),
              ),
            ),
            
            // Gradient sombre pour lisibilité texte
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.6, 1.0],
                  ),
                ),
              ),
            ),

            // Badge Promo
            Positioned(
              top: 0, left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: isSmall ? 2 : 4, vertical: isSmall ? 1 : 2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(8), bottomRight: Radius.circular(4)),
                ),
                child: Text(
                  product.promoPrice != null && (double.tryParse(product.price) ?? 0) > 0
                    ? "-${((1 - (product.promoPrice! / (double.tryParse(product.price) ?? 1))) * 100).round()}%" 
                    : "PROMO",
                  style: TextStyle(color: Colors.white, fontSize: isSmall ? 8 : 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Prix
            Positioned(
              bottom: 4, left: 4, right: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (double.tryParse(product.price) != null)
                    Text(
                      "${product.price}\$", 
                      style: TextStyle(
                        color: Colors.grey[400], 
                        fontSize: isSmall ? 8 : 10, 
                        decoration: TextDecoration.lineThrough
                      )
                    ),
                  Text(
                    "${product.promoPrice ?? product.price}\$", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isSmall ? 11 : 13)
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
