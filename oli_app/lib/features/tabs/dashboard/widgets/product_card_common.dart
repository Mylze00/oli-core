import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../utils/cloudinary_helper.dart';

class DashboardProductCard extends ConsumerWidget {
  final Product product;
  final Color priceColor;
  final String? badgeText;
  final Color? badgeColor;
  final bool badgeOnRight;
  final Widget? subtitleWidget;
  final double width;
  final double priceFontSize;
  final Color cardColor;
  final Color imageBackgroundColor;

  const DashboardProductCard({
    super.key,
    required this.product,
    this.priceColor = Colors.white,
    this.badgeText,
    this.badgeColor,
    this.badgeOnRight = false,
    this.subtitleWidget,
    this.width = 104,
    this.priceFontSize = 15,
    this.cardColor = const Color(0xFF2C2C2C),
    this.imageBackgroundColor = const Color(0xFF1A1A1A),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 7),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(6), // réduit de 12 → 6 (−50%)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 100,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  child: product.images.isNotEmpty
                    ? Image.network(
                        CloudinaryHelper.small(product.images.first),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) return child;
                          return AnimatedOpacity(
                            opacity: frame == null ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                            child: child,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: imageBackgroundColor,
                            child: Center(
                              child: SizedBox(
                                width: 16, height: 16,
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
                        errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.broken_image, size: 24, color: Colors.grey)),
                      )
                    : const Center(child: Icon(Icons.image, color: Colors.grey)),
                ),
                if (badgeText != null && badgeColor != null)
                  Positioned(
                    top: 0,
                    left: badgeOnRight ? null : 0,
                    right: badgeOnRight ? 0 : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: badgeOnRight
                          ? const BorderRadius.only(topRight: Radius.circular(4), bottomLeft: Radius.circular(4))
                          : const BorderRadius.only(topLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
                      ),
                      child: badgeText == "Vérifié"
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified, size: 10, color: Colors.white),
                                const SizedBox(width: 2),
                                Text(badgeText!, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ],
                            )
                          : Text(badgeText!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badgeOnRight)
                   Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),

                Consumer(
                  builder: (context, ref, _) {
                    ref.watch(exchangeRateProvider);
                    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
                    final priceUsd = double.tryParse(product.price) ?? 0.0;
                    final formattedPrice = exchangeNotifier.formatProductPrice(priceUsd);
                    return Text(formattedPrice, style: TextStyle(color: priceColor, fontWeight: FontWeight.bold, fontSize: priceFontSize));
                  },
                ),

                if (subtitleWidget != null) ...[
                   if (!badgeOnRight) const SizedBox(height: 2),
                   subtitleWidget!,
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge vendeur animé : affiche le nom du vendeur (ex: "OLI") puis
/// glisse vers le bas et révèle une note étoile (ex: ★ 4.8) en rouge.
/// L'animation se déclenche automatiquement toutes les [interval] secondes.
class SellerRatingBadge extends StatefulWidget {
  final String sellerName;
  final double rating;
  final Duration interval;

  const SellerRatingBadge({
    super.key,
    required this.sellerName,
    this.rating = 5.0,
    this.interval = const Duration(seconds: 4),
  });

  @override
  State<SellerRatingBadge> createState() => _SellerRatingBadgeState();
}

class _SellerRatingBadgeState extends State<SellerRatingBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  // 0.0 = nom visible ; 1.0 = note visible
  late Animation<Offset> _slideOutName;  // nom sort par le bas
  late Animation<Offset> _slideInRating; // note entre par le haut

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideOutName  = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1))
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideInRating = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _startLoop();
  }

  Future<void> _startLoop() async {
    while (mounted) {
      await Future.delayed(widget.interval);
      if (!mounted) return;
      await _controller.forward();          // nom → note
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await _controller.reverse();          // note → nom
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: ClipRect(
        child: Stack(
          children: [
            // Nom du vendeur (sort par le bas)
            SlideTransition(
              position: _slideOutName,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.6), width: 0.5),
                    ),
                    child: Text(
                      widget.sellerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Note étoile (entre par le haut)
            SlideTransition(
              position: _slideInRating,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.red, size: 11),
                  const SizedBox(width: 2),
                  Text(
                    widget.rating % 1 == 0
                        ? widget.rating.toInt().toString()
                        : widget.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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
}
