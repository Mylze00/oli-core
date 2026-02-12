import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';

class DashboardProductCard extends ConsumerWidget {
  final Product product;
  final Color priceColor;
  final String? badgeText;
  final Color? badgeColor;
  final bool badgeOnRight;
  final Widget? subtitleWidget;
  final double width;

  const DashboardProductCard({
    super.key,
    required this.product,
    this.priceColor = Colors.white,
    this.badgeText,
    this.badgeColor,
    this.badgeOnRight = false,
    this.subtitleWidget,
    this.width = 104, // Reduced by 20%
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: product.images.isNotEmpty 
                    ? Image.network(product.images.first, fit: BoxFit.cover, width: double.infinity)
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
                          ? const BorderRadius.only(topRight: Radius.circular(8), bottomLeft: Radius.circular(8))
                          : const BorderRadius.only(topLeft: Radius.circular(8), bottomRight: Radius.circular(8)), // Original 'Deal' didn't have rounded corners like Top/Verified but let's harmonize
                      ),
                      child: badgeText == "Vérifié" // Cas spécial pour icône vérifié
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
                if (badgeOnRight) // Verified card has name before price
                   Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
                
                Consumer(
                  builder: (context, ref, _) {
                    ref.watch(exchangeRateProvider); // Subscribe
                    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
                    final priceUsd = double.tryParse(product.price) ?? 0.0;
                    final formattedPrice = exchangeNotifier.formatProductPrice(priceUsd);
                    return Text(formattedPrice, style: TextStyle(color: priceColor, fontWeight: FontWeight.bold, fontSize: 14));
                  },
                ),
                
                if (subtitleWidget != null) ...[
                   if (!badgeOnRight) const SizedBox(height: 2), // Spacing for verify card is implicit
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
