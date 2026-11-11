import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/services/oli_image_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../utils/cloudinary_helper.dart';

/// Widget réutilisable pour afficher une section horizontale de produits
/// avec titre, sous-titre et scroll horizontal.
///
/// - Adapte automatiquement ses couleurs au thème (dark/light)
/// - Mène vers MarketView filtrée par mot-clé au tap sur la flèche
/// - Affiche le prix formaté en FC/USD via [exchangeRateProvider]
class HorizontalProductSection extends ConsumerWidget {
  final String title;
  final String subtitle;
  final List<Product> products;
  final List<Color>? gradient;
  /// Couleur d'accent du prix en mode sombre.
  final Color accentColor;
  final String? searchKeyword;
  final void Function(Product) onProductTap;

  const HorizontalProductSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.products,
    this.gradient,
    required this.accentColor,
    this.searchKeyword,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white54 : Colors.grey.shade500;
    final containerBgColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final containerBorderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final productNameColor = isDark ? Colors.white70 : Colors.grey.shade600;
    final placeholderColor =
        isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade200;
    final priceColor = isDark ? accentColor : const Color(0xFFFF6B6B); // Coral red

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        gradient: gradient != null
            ? LinearGradient(
                colors: gradient!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: gradient == null ? containerBgColor : null,
        border: gradient == null ? Border.all(color: containerBorderColor, width: 1) : null,
        borderRadius: BorderRadius.circular(4),
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
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(color: subtitleColor, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

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
                    width: 105,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image (cache disque + mémoire via CachedNetworkImage)
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: product.images.isNotEmpty
                                ? CachedNetworkImage(
                                    cacheManager: OliImageCache.instance,
                                    // 330 px ≈ 3 × 110 px logiques : net sur écrans haute densité
                                    imageUrl: CloudinaryHelper.card(
                                        product.images.first,
                                        width: 330,
                                        height: 330),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    memCacheWidth: 330,
                                    fadeInDuration:
                                        const Duration(milliseconds: 300),
                                    placeholder: (_, __) =>
                                        Container(color: placeholderColor),
                                    errorWidget: (_, __, ___) => Container(
                                      color: placeholderColor,
                                      child: const Center(
                                        child: Icon(Icons.broken_image,
                                            size: 20, color: Colors.grey),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: placeholderColor,
                                    child: const Center(
                                        child: Icon(Icons.image,
                                            color: Colors.grey)),
                                  ),
                          ),
                        ),

                        // Nom + prix
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0, left: 2, right: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: productNameColor,
                                      fontSize: 10)),
                              const SizedBox(height: 2),
                              Consumer(builder: (context, ref, _) {
                                final notifier =
                                    ref.read(exchangeRateProvider.notifier);
                                ref.watch(exchangeRateProvider);
                                return Text(
                                  notifier.formatProductPrice(
                                      double.tryParse(product.price) ?? 0.0),
                                  style: TextStyle(
                                      color: priceColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
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
