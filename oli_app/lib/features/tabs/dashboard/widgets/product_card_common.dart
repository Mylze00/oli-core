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
    this.width = 135,
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
            height: 130,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  child: product.images.isNotEmpty
                    ? Image.network(
                        CloudinaryHelper.card(product.images.first),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        cacheWidth: 130, // ← Limite la RAM : redimensionne en décodage
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

/// Carousel animé de labels produit pour les positions "top classement".
/// Défile automatiquement entre 4 messages avec une animation slide verticale.
class SellerRatingBadge extends StatefulWidget {
  final String sellerName; // conservé pour compatibilité API mais non utilisé
  final double rating;
  final Duration interval;

  const SellerRatingBadge({
    super.key,
    this.sellerName = '',
    this.rating = 5.0,
    this.interval = const Duration(seconds: 3),
  });

  @override
  State<SellerRatingBadge> createState() => _SellerRatingBadgeState();
}

class _SellerRatingBadgeState extends State<SellerRatingBadge>
    with SingleTickerProviderStateMixin {

  // Labels qui défilent (ordre cyclique)
  static const List<_BadgeLabel> _labels = [
    _BadgeLabel(icon: Icons.replay, text: 'Taux de rachat 30%',  color: Color(0xFF4CAF50)),
    _BadgeLabel(icon: Icons.verified_user, text: 'CE certification', color: Color(0xFF2196F3)),
    _BadgeLabel(icon: Icons.thumb_up, text: 'Produit recommandé',  color: Color(0xFFFF9800)),
    _BadgeLabel(icon: Icons.star_rounded, text: '5.0',             color: Colors.red, isStar: true),
  ];

  late AnimationController _controller;
  late Animation<Offset> _slideOut; // label courant sort par le bas
  late Animation<Offset> _slideIn;  // prochain label entre par le haut

  int _current = 0;
  int _next = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slideOut = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1))
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideIn = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _startLoop();
  }

  Future<void> _startLoop() async {
    while (mounted) {
      await Future.delayed(widget.interval);
      if (!mounted) return;
      _next = (_current + 1) % _labels.length;
      await _controller.forward();
      if (!mounted) return;
      setState(() { _current = _next; });
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cur  = _labels[_current];
    final next = _labels[_next];

    return SizedBox(
      height: 14,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              children: [
                // Label courant — sort par le bas
                SlideTransition(
                  position: _slideOut,
                  child: _buildChip(cur),
                ),
                // Prochain label — entre par le haut
                SlideTransition(
                  position: _slideIn,
                  child: _buildChip(next),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChip(_BadgeLabel label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(label.icon, size: 9, color: label.color),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            label.isStar ? '${label.text}' : label.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: label.color,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Données d'un label du carousel
class _BadgeLabel {
  final IconData icon;
  final String text;
  final Color color;
  final bool isStar;

  const _BadgeLabel({
    required this.icon,
    required this.text,
    required this.color,
    this.isStar = false,
  });
}
