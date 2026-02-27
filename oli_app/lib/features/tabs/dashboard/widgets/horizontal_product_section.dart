import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../utils/cloudinary_helper.dart';
import '../../presentation/pages/market_view.dart';

/// Widget réutilisable pour afficher une section horizontale de produits
/// avec titre, sous-titre, badge et scroll horizontal.
///
/// - Adapte automatiquement ses couleurs au thème (dark/light)
/// - Mène vers MarketView filtrée par mot-clé au tap sur la flèche
/// - Affiche le prix formaté en FC/USD via [exchangeRateProvider]
class HorizontalProductSection extends ConsumerWidget {
  final String title;
  final String subtitle;
  final List<Product> products;
  final List<Color>? gradient;
  final String badgeText;
  final Color badgeColor;
  final String? searchKeyword;
  final void Function(Product) onProductTap;

  const HorizontalProductSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.products,
    this.gradient,
    required this.badgeText,
    required this.badgeColor,
    this.searchKeyword,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white.withOpacity(0.7) : Colors.black54;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: gradient != null
            ? LinearGradient(
                colors: gradient!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: gradient == null ? Colors.transparent : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête : titre + bouton navigation ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(color: subtitleColor, fontSize: 11)),
                ],
              ),
              GestureDetector(
                onTap: () {
                  final keyword =
                      searchKeyword ?? title.replaceFirst('Sélection : ', '');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            MarketView(initialSearchQuery: keyword)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: titleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.arrow_forward_ios,
                      color: titleColor, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Liste horizontale de cartes produits ──
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return GestureDetector(
                  onTap: () => onProductTap(product),
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
                        // Image + badge
                        Expanded(
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8)),
                                child: product.images.isNotEmpty
                                    ? Image.network(
                                        CloudinaryHelper.small(
                                            product.images.first),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        frameBuilder: (context, child, frame,
                                            wasSynchronouslyLoaded) {
                                          if (wasSynchronouslyLoaded) {
                                            return child;
                                          }
                                          return AnimatedOpacity(
                                            opacity:
                                                frame == null ? 0.0 : 1.0,
                                            duration: const Duration(
                                                milliseconds: 400),
                                            curve: Curves.easeOut,
                                            child: child,
                                          );
                                        },
                                        loadingBuilder: (context, child,
                                            loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Container(
                                            color: const Color(0xFF1A1A1A),
                                            child: const Center(
                                              child: SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.grey),
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (ctx, err, stack) =>
                                            const Center(
                                              child: Icon(Icons.broken_image,
                                                  size: 20,
                                                  color: Colors.grey),
                                            ),
                                      )
                                    : const Center(
                                        child: Icon(Icons.image,
                                            color: Colors.grey)),
                              ),
                              // Badge en haut à gauche
                              Positioned(
                                top: 0,
                                left: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Text(badgeText,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Nom + prix
                        Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10)),
                              Consumer(builder: (context, ref, _) {
                                final notifier =
                                    ref.read(exchangeRateProvider.notifier);
                                ref.watch(exchangeRateProvider);
                                return Text(
                                  notifier.formatProductPrice(
                                      double.tryParse(product.price) ?? 0.0),
                                  style: TextStyle(
                                      color: badgeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                );
                              }),
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
