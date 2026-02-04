import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../widgets/verification_badge.dart';
import '../../../user/providers/favorites_provider.dart';
import '../pages/product_details_page.dart';
import '../../../../providers/exchange_rate_provider.dart';

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
    
    // Utiliser watch pour que le widget se mette à jour automatiquement
    final exchangeState = ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    // Calculer si le produit est en promotion
    final bool hasDiscount = product.discountPrice != null && product.discountPrice! > 0;
    
    // Calculer le pourcentage de rÃ©duction pour le badge
    String? discountBadgeText;
    if (hasDiscount) {
      final originalPrice = double.tryParse(product.price) ?? 0;
      if (originalPrice > 0) {
        final discount = ((originalPrice - product.discountPrice!) / originalPrice) * 100;
        if (discount > 0) {
          discountBadgeText = "-${discount.round()}%";
        }
      }
    }

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
                          fit: BoxFit.fill, // Etirer l'image comme demandÃ©
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
                                // Verification badge - only show for certified users
                                if (product.sellerHasCertifiedShop || 
                                    product.sellerAccountType == 'entreprise' ||
                                    product.sellerAccountType == 'certifie' ||
                                    product.sellerIsVerified)
                                  Positioned(
                                    bottom: -2, left: 0, right: 0,
                                    child: Center(
                                      child: VerificationBadge(
                                        type: (product.sellerHasCertifiedShop || product.sellerAccountType == 'entreprise')
                                            ? BadgeType.gold
                                            : BadgeType.blue,
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

                    // Badge CertifiÃ© (Top Right, shifted left if fav exists)
                    if (product.shopVerified)
                      Positioned(
                        top: 2, right: 28, // Shifted to not overlap heart
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.verified, size: 10, color: Colors.white),
                        ),
                      ),
                      
                    // Badge Promo (Top Left)
                    if (hasDiscount)
                      Positioned(
                        top: 4, left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30), // Red apple style
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            discountBadgeText ?? "PROMO",
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    
                    // Badge NEW (Top Left, shifted down if promo exists)
                    if (product.createdAt != null && DateTime.now().difference(product.createdAt!).inDays < 7)
                      Positioned(
                        top: hasDiscount ? 28 : 4, left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ECDC4), // Teal
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "NEW",
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    
                    // Badge STOCK BAS (Bottom Left)
                    if (product.quantity < 5 && product.quantity > 0)
                      Positioned(
                        bottom: 24, left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFBE0B), // Yellow/Gold
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "Stock: ${product.quantity}",
                            style: const TextStyle(color: Colors.black87, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    
                    // Badge BEST SELLER (Top Right, shifted left from heart)
                    if (product.viewCount > 100)
                      Positioned(
                        top: 28, right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_fire_department, size: 10, color: Colors.white),
                              SizedBox(width: 2),
                              Text(
                                "HOT",
                                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
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
                  // Formater le prix en fonction de la devise sÃ©lectionnÃ©e
                  Builder(
                    builder: (context) {
                      final priceUsd = double.tryParse(product.price) ?? 0.0;
                      final discountPriceUsd = product.discountPrice;
                      
                      // Calculate displayed prices
                      final displayPrice = exchangeState.selectedCurrency == Currency.USD
                          ? priceUsd
                          : exchangeNotifier.convertAmount(priceUsd, from: Currency.USD);
                          
                      final formattedPrice = exchangeNotifier.formatAmount(displayPrice, currency: exchangeState.selectedCurrency);
                      
                      // Handle Discount Display
                      if (hasDiscount && discountPriceUsd != null) {
                         final displayDiscount = exchangeState.selectedCurrency == Currency.USD
                            ? discountPriceUsd
                            : exchangeNotifier.convertAmount(discountPriceUsd, from: Currency.USD);
                         final formattedDiscount = exchangeNotifier.formatAmount(displayDiscount, currency: exchangeState.selectedCurrency);
                         
                         return Wrap(
                           crossAxisAlignment: WrapCrossAlignment.center,
                           children: [
                             Text(
                               formattedDiscount,
                               style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.bold, fontSize: 11) // Orange/Gold for discount
                             ),
                             const SizedBox(width: 4),
                             Text(
                               formattedPrice,
                               style: const TextStyle(
                                 color: Colors.grey, 
                                 fontSize: 9, 
                                 decoration: TextDecoration.lineThrough
                               )
                             ),
                           ],
                         );
                      }
                      
                      return Text(
                        formattedPrice,
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11)
                      );
                    },
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
