import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../widgets/verification_badge.dart';
import '../../../user/providers/favorites_provider.dart';
import '../pages/product_details_page.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../utils/cloudinary_helper.dart';
import '../../../tabs/dashboard/widgets/product_card_common.dart';

class MarketProductCard extends ConsumerWidget {
  final Product product;
  final bool isCompact;
  /// Si true, l'overlay vendeur affiche l'animation SellerRatingBadge (nom → ★ note)
  final bool showRatingAnimation;
  /// Si true, masque l'overlay vendeur (gradient + avatar + nom) en bas de l'image
  final bool hideSellerOverlay;

  const MarketProductCard({
    super.key, 
    required this.product, 
    this.isCompact = false,
    this.showRatingAnimation = false,
    this.hideSellerOverlay = false,
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
          color: const Color(0xFF1A1A1A), // ~90% noir solide, visible sur fond noir
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand, // Ensure stack fills the parent
                  children: [
                    // Image
                    product.images.isEmpty
                      ? const Center(child: Icon(Icons.image, size: 40, color: Colors.grey))
                      : Image.network(
                          CloudinaryHelper.thumbnail(product.images[0]),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 300, // ← Limite RAM : décode à 300px max
                          // Fade-in animation when image loads
                          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded) return child;
                            return AnimatedOpacity(
                              opacity: frame == null ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              child: child,
                            );
                          },
                          // Placeholder while loading
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: const Color(0xFF1A1A1A),
                              child: Center(
                                child: SizedBox(
                                  width: 20, height: 20,
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
                          errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                        ),
                    
                    // Info Vendeur (Overlay Bottom) — masqué sur dashboard
                    if (!hideSellerOverlay)
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
                              child: showRatingAnimation
                                  ? SellerRatingBadge(
                                      sellerName: product.seller.isNotEmpty ? product.seller : 'OLI',
                                      rating: 5.0,
                                      interval: const Duration(seconds: 5),
                                    )
                                  : Text(
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
                    
                    // Badge NEW (Masqué selon demande utilisateur)
                    /*
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
                    */
                    
                    // Badge STOCK BAS masqué
                    // (désactivé — masquer l'info stock sur les cartes)
                    
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
                    // Badge Brand Certifié — overlay bas-gauche image
                    if (product.brandCertified)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, color: Color(0xFFFF8C00), size: 7),
                            const SizedBox(width: 2),
                            Text(
                              product.brandDisplayName?.isNotEmpty == true
                                  ? product.brandDisplayName!
                                  : 'Original',
                              style: const TextStyle(
                                color: Color(0xFFFF8C00),
                                fontSize: 6,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
                              ),
                            ),
                          ],
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const style = TextStyle(color: Colors.white, fontSize: 10, height: 1.2);
                      final tp = TextPainter(
                        text: TextSpan(text: product.name, style: style),
                        maxLines: 2,
                        textDirection: TextDirection.ltr,
                      )..layout(maxWidth: constraints.maxWidth);
                      
                      final isOneLine = tp.height <= 15;

                      return SizedBox(
                        height: 28, // Hauteur fixe pour 2 lignes de texte
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: isOneLine ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: style,
                            ),
                            if (isOneLine)
                              const Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SellerRatingBadge(
                                    interval: Duration(seconds: 5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
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
                               style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.bold, fontSize: 16.5) // Augmenté de 10% (15 -> 16.5)
                             ),
                             const SizedBox(width: 4),
                             Text(
                               formattedPrice,
                               style: const TextStyle(
                                 color: Colors.grey,
                                 fontSize: 13.2, // Augmenté de 10% (12 -> 13.2)
                                 decoration: TextDecoration.lineThrough
                               )
                             ),
                           ],
                         );
                      }
                      
                      return Text(
                        formattedPrice,
                        style: const TextStyle(color: Color(0xFF7CADFF), fontWeight: FontWeight.bold, fontSize: 16.5) // Augmenté de 10% (15 -> 16.5)
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
