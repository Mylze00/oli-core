import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../widgets/verification_badge.dart';
import '../../../user/providers/favorites_provider.dart';
import '../pages/product_details_page.dart';

class MarketProductCard extends ConsumerWidget {
  final Product product;
  final bool isCompact;

  const MarketProductCard({
    super.key, 
    required this.product, 
    this.isCompact = false
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.any((p) => p.id == product.id);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: Stack(
                  fit: StackFit.expand, // Ensure stack fills the parent
                  children: [
                    // Image
                    product.images.isEmpty
                      ? const Center(child: Icon(Icons.image, size: 40, color: Colors.grey))
                      : Image.network(
                          product.images[0],
                          width: double.infinity,
                          fit: BoxFit.fill, // Etirer l'image comme demandé
                          errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                        ),
                    
                    // Info Vendeur (Overlay Bottom)
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 7,
                                  backgroundImage: product.sellerAvatar != null 
                                      ? NetworkImage(product.sellerAvatar!) 
                                      : null,
                                  child: product.sellerAvatar == null 
                                      ? const Icon(Icons.person, size: 8, color: Colors.white) 
                                      : null,
                                ),
                                // Verification badge
                                if (product.sellerIsVerified || product.sellerAccountType != 'ordinaire' || product.sellerHasCertifiedShop)
                                  Positioned(
                                    bottom: -2, left: 0, right: 0,
                                    child: Center(
                                      child: VerificationBadge(
                                        type: VerificationBadge.fromSellerData(
                                          isVerified: product.sellerIsVerified,
                                          accountType: product.sellerAccountType,
                                          hasCertifiedShop: product.sellerHasCertifiedShop,
                                        ),
                                        size: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                product.seller,
                                style: const TextStyle(color: Colors.white, fontSize: 8),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Badge Bouton Favoris (Top Right)
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () {
                          ref.read(favoritesProvider.notifier).toggleFavorite(product);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                    // Badge Certifié (Top Right, shifted left if fav exists)
                    if (product.shopVerified)
                      Positioned(
                        top: 2, right: 28, // Shifted to not overlap heart
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.verified, size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(5.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10)),
                  const SizedBox(height: 2),
                  Text("\$${product.price}", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
