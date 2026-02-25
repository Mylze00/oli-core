import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../pages/product_details_page.dart';

/// Couleurs de contour épais, une par carte
const List<Color> _kBorderColors = [
  Color(0xFF00C6FF),
  Color(0xFFFF6B6B),
  Color(0xFF6BCB77),
  Color(0xFFFFD93D),
  Color(0xFFCB6CE6),
  Color(0xFFFF9F43),
  Color(0xFF48DBFB),
  Color(0xFFFF6EB4),
  Color(0xFF54A0FF),
  Color(0xFF1DD1A1),
];

/// Sélectionne jusqu'à [max] produits : priorité aux vendeurs uniques,
/// complète avec d'autres produits ayant une image si besoin.
List<Product> _pickSpotlight(List<Product> all, {int max = 10}) {
  final shuffled = List<Product>.from(all)..shuffle(Random());
  final result = <Product>[];
  final usedIds = <String>{};

  // Passe 1 : un produit par sellerId non-vide
  for (final p in shuffled) {
    if (result.length >= max) break;
    if (p.images.isEmpty) continue;
    final sid = p.sellerId.trim();
    if (sid.isNotEmpty && !usedIds.contains(sid)) {
      usedIds.add(sid);
      result.add(p);
    }
  }

  // Passe 2 : compléter avec n'importe quel produit avec image (pas déjà ajouté)
  if (result.length < max) {
    for (final p in shuffled) {
      if (result.length >= max) break;
      if (p.images.isEmpty) continue;
      if (!result.contains(p)) {
        result.add(p);
      }
    }
  }

  return result;
}

class MarketSpotlightCarousel extends ConsumerStatefulWidget {
  final List<Product> products;
  const MarketSpotlightCarousel({super.key, required this.products});

  @override
  ConsumerState<MarketSpotlightCarousel> createState() =>
      _MarketSpotlightCarouselState();
}

class _MarketSpotlightCarouselState
    extends ConsumerState<MarketSpotlightCarousel> {
  late final List<Product> _items;

  @override
  void initState() {
    super.initState();
    _items = _pickSpotlight(widget.products);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Titre ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
          child: Row(
            children: [
              Container(
                width: 3, height: 18,
                decoration: BoxDecoration(
                  color: Colors.amberAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'À la une',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 6),
              const Text('✨', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),

        // ── Liste horizontale des cercles ──────────────────────────────
        SizedBox(
          height: 192,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final product = _items[index];
              final color = _kBorderColors[index % _kBorderColors.length];
              final price = double.tryParse(product.price) ?? 0.0;
              final effectivePrice =
                  (product.discountPrice != null && product.discountPrice! > 0)
                      ? product.discountPrice!
                      : price;
              final formattedPrice =
                  exchangeNotifier.formatProductPrice(effectivePrice);
              final location =
                  (product.location != null && product.location!.isNotEmpty)
                      ? product.location!
                      : 'Kinshasa';
              final sellerName =
                  (product.shopName != null && product.shopName!.isNotEmpty)
                      ? product.shopName!
                      : product.seller;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailsPage(product: product),
                  ),
                ),
                child: _SpotlightCircleItem(
                  product: product,
                  borderColor: color,
                  formattedPrice: formattedPrice,
                  location: location,
                  sellerName: sellerName,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Carte circulaire individuelle ──────────────────────────────────────────
class _SpotlightCircleItem extends StatelessWidget {
  final Product product;
  final Color borderColor;
  final String formattedPrice;
  final String location;
  final String sellerName;

  const _SpotlightCircleItem({
    required this.product,
    required this.borderColor,
    required this.formattedPrice,
    required this.location,
    required this.sellerName,
  });

  @override
  Widget build(BuildContext context) {
    const double circleSize = 100;

    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Image circulaire avec contour épais coloré ───────────────
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 4),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withOpacity(0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: product.images.isNotEmpty
                  ? Image.network(
                      product.images.first,
                      fit: BoxFit.cover,
                      width: circleSize,
                      height: circleSize,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF2A2A2A),
                        child: Icon(Icons.image_not_supported,
                            color: borderColor, size: 32),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF2A2A2A),
                      child: Icon(Icons.storefront,
                          color: borderColor, size: 32),
                    ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Nom du produit ──────────────────────────────────────────
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 3),

          // ── Prix ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor.withOpacity(0.5), width: 1),
            ),
            child: Text(
              formattedPrice,
              style: TextStyle(
                color: borderColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 3),

          // ── Localisation ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_rounded, size: 10, color: Colors.white38),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
