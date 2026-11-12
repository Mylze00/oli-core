import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/oli_image_cache.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../utils/cloudinary_helper.dart';
import '../../../../utils/price_color.dart';
import '../pages/product_details_page.dart';

/// Grille propre à la page Marché, séparée de celle de l'accueil :
/// rangées équilibrées (cartes de hauteurs différentes, colonnes à niveau, liste stable), produits de grands magasins
/// signalés par l'avatar et le nom du magasin, « Livraison 24h » pour les boutiques vérifiées.
class MarketProductGrid extends StatelessWidget {
  final List<Product> products;

  /// Produits de grands magasins intercalés : ils portent l'avatar et le nom du magasin.
  final bool Function(Product product)? isStoreProduct;

  const MarketProductGrid({super.key, required this.products, this.isStoreProduct});

  static const int columns = 2;
  static const double gutter = 8;
  static const double textBlockHeight = 58;

  /// Bloc texte d'une carte « Livraison 24h » (une ligne de plus).
  static const double textBlockHeightWithDelivery = 78;

  /// Carte haute (une ligne « Livraison 24h » en plus) : boutique vérifiée, certifiée ou grand magasin.
  static bool isTall(Product product, {bool isStore = false}) =>
      product.shopVerified || product.sellerHasCertifiedShop || isStore;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final blocks = _blocks();
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildBlock(blocks[index]),
          ),
          childCount: blocks.length,
        ),
      ),
    );
  }

  bool _tall(Product p) => isTall(p, isStore: isStoreProduct?.call(p) ?? false);

  /// Découpe la liste (déjà équilibrée par la page) en blocs affichables :
  /// - court, haute, haute, court → deux colonnes décalées qui finissent à niveau ;
  /// - sinon des paires côte à côte (et une carte seule en toute fin de liste).
  List<List<Product>> _blocks() {
    final blocks = <List<Product>>[];
    var i = 0;
    while (i < products.length) {
      if (i + 3 < products.length &&
          !_tall(products[i]) &&
          _tall(products[i + 1]) &&
          _tall(products[i + 2]) &&
          !_tall(products[i + 3])) {
        blocks.add(products.sublist(i, i + 4));
        i += 4;
      } else {
        blocks.add(products.sublist(i, (i + 2).clamp(0, products.length)));
        i += 2;
      }
    }
    return blocks;
  }

  Widget _card(Product p) => MarketProductCard(product: p, storeBadge: isStoreProduct?.call(p) ?? false);

  Widget _buildBlock(List<Product> block) {
    if (block.length == 4) {
      // Colonne gauche : court puis haute ; colonne droite : haute puis court
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: [_card(block[0]), const SizedBox(height: 10), _card(block[2])])),
          const SizedBox(width: gutter),
          Expanded(child: Column(children: [_card(block[1]), const SizedBox(height: 10), _card(block[3])])),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _card(block[0])),
        const SizedBox(width: gutter),
        Expanded(child: block.length > 1 ? _card(block[1]) : const SizedBox.shrink()),
      ],
    );
  }
}

/// Carte produit du Marché : visuel carré sur fond blanc, titre, prix et,
/// pour les boutiques vérifiées, « Livraison 24h » sous le prix.
class MarketProductCard extends ConsumerWidget {
  final Product product;

  /// Badge « Grand magasin » (produit certifié intercalé dans la grille du marché).
  final bool storeBadge;

  const MarketProductCard({super.key, required this.product, this.storeBadge = false});

  bool get _delivers24h => MarketProductGrid.isTall(product, isStore: storeBadge);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    ref.watch(exchangeRateProvider);
    final priceUsd = double.tryParse(product.price) ?? 0.0;
    final formattedPrice = ref.read(exchangeRateProvider.notifier).formatProductPrice(priceUsd);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
      child: Container(
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visuel carré
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(isDark),
                  if (storeBadge) Positioned(top: 6, left: 6, right: 6, child: _StoreBadge(product: product)),
                ],
              ),
            ),
            // Bloc texte (hauteur fixe)
            SizedBox(
              height: _delivers24h ? MarketProductGrid.textBlockHeightWithDelivery : MarketProductGrid.textBlockHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'CreatoDisplay',
                        color: titleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formattedPrice,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'CreatoDisplay',
                              color: productPriceColor(context),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Boutique vérifiée : livraison en 24 h
                    if (_delivers24h) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Delivery24hIcon(size: 18, color: titleColor),
                          const SizedBox(width: 5),
                          Text(
                            'Livraison 24h',
                            style: TextStyle(
                              color: titleColor.withValues(alpha: 0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(bool isDark) {
    // Fond blanc : les PNG transparents (électroménager, emballages) restent lisibles en mode sombre
    return product.images.isNotEmpty
        ? ColoredBox(
            color: Colors.white,
            child: CachedNetworkImage(
              cacheManager: OliImageCache.instance,
              imageUrl: CloudinaryHelper.card(product.images.first),
              fit: BoxFit.cover,
              memCacheWidth: 540, // décodage à la résolution servie (540 px)
              placeholder: (_, __) => Container(color: isDark ? Colors.grey[900] : Colors.grey[200]),
              errorWidget: (_, __, ___) => Container(
                color: isDark ? Colors.grey[900] : Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          )
        : Container(
            color: isDark ? Colors.grey[900] : Colors.grey[200],
            child: const Icon(Icons.image, color: Colors.grey),
          );
  }
}

/// Étiquette des produits de grands magasins intercalés dans la grille du marché :
/// avatar et nom du magasin.
class _StoreBadge extends StatelessWidget {
  final Product product;

  const _StoreBadge({required this.product});

  @override
  Widget build(BuildContext context) {
    final shop = product.shopName?.trim() ?? '';
    final seller = product.seller.trim();
    // « Boutique Entreprise » est le nom par défaut posé à la création : on préfère le vendeur
    final name = (seller.isNotEmpty && seller != 'Anonyme') || shop.isEmpty || shop == 'Boutique Entreprise'
        ? seller
        : shop;
    final avatar = product.sellerAvatar;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(3, 3, 8, 3),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: avatar != null && avatar.isNotEmpty
                  ? CachedNetworkImage(
                      cacheManager: OliImageCache.instance,
                      imageUrl: avatar,
                      fit: BoxFit.cover,
                      memCacheWidth: 60,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.storefront_rounded, size: 12, color: Colors.black54),
                    )
                  : const Icon(Icons.storefront_rounded, size: 12, color: Colors.black54),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF4ADE80)),
          ],
        ),
      ),
    );
  }
}

/// Icône « livraison en 24 h » : flèche circulaire, pointillés, « 24 » et bandeau jaune.
class Delivery24hIcon extends StatelessWidget {
  final double size;
  final Color color;

  const Delivery24hIcon({super.key, this.size = 18, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _Delivery24hPainter(color)),
    );
  }
}

class _Delivery24hPainter extends CustomPainter {
  final Color color;

  _Delivery24hPainter(this.color);

  static const _yellow = Color(0xFFFFB400);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final radius = w * 0.42;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Arc plein (de bas-droite, par la gauche, jusqu'en haut) terminé par une flèche
    const start = 1.15; // radians, sens horaire depuis l'axe x
    const sweep = 3.75;
    canvas.drawArc(rect, start, sweep, false, stroke);
    final end = start + sweep;
    final tip = center + Offset(radius * math.cos(end), radius * math.sin(end));
    final tangent = Offset(-math.sin(end), math.cos(end)); // direction horaire
    final normal = Offset(math.cos(end), math.sin(end));
    final head = w * 0.17;
    final arrow = Path()
      ..moveTo(tip.dx + tangent.dx * head, tip.dy + tangent.dy * head)
      ..lineTo(tip.dx + normal.dx * head * 0.8, tip.dy + normal.dy * head * 0.8)
      ..lineTo(tip.dx - normal.dx * head * 0.8, tip.dy - normal.dy * head * 0.8)
      ..close();
    canvas.drawPath(arrow, Paint()..color = color);

    // Pointillés sur le reste du cercle
    final dash = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round;
    final gapStart = end + 0.35;
    const gapEnd = start + 2 * math.pi - 0.2;
    for (var a = gapStart; a < gapEnd; a += 0.42) {
      canvas.drawArc(rect, a, 0.18, false, dash);
    }

    // « 24 » et bandeau jaune
    final text = TextPainter(
      text: TextSpan(
        text: '24',
        style: TextStyle(color: color, fontSize: w * 0.36, fontWeight: FontWeight.w900, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(center.dx - text.width / 2, center.dy - text.height * 0.72));
    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(center.dx - w * 0.22, center.dy + w * 0.1, w * 0.44, w * 0.12),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(band, Paint()..color = _yellow);
  }

  @override
  bool shouldRepaint(_Delivery24hPainter old) => old.color != color;
}
