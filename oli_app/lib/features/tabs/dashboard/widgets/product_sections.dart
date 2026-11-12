import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/services/oli_image_cache.dart';
import 'package:flutter/material.dart';
import '../../../../utils/price_color.dart';
import '../../../marketplace/presentation/pages/product_details_page.dart';
import '../../../../models/product_model.dart';
import 'product_card_common.dart';
import '../pages/verified_shops_products_page.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../utils/cloudinary_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Couleurs cycliques pour les bordures des cercles ──────────────────────────
const List<Color> _circleBorderColors = [
  Color(0xFF00B4FF), // bleu vif
  Color(0xFFFF3B30), // rouge
  Color(0xFF34C759), // vert
  Color(0xFFFFCC00), // jaune
];

/// Nom de marque raccourci : 10 caractères maximum, pour éviter que les
/// colonnes de la section « À la une » ne se chevauchent.
String _shortBrand(String? brand) {
  final b = (brand ?? '').trim();
  if (b.isEmpty) return 'Original';
  return b.length <= 10 ? b : '${b.substring(0, 10)}…';
}

/// Assombrit une couleur vive pour qu'elle reste lisible sur fond clair.
Color _darken(Color c, [double amount = 0.32]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// Widget "À la une" — produits circulaires avec Branding (brandCertified)
class BrandedCircleSection extends ConsumerWidget {
  final List<Product> products;
  final String title;

  const BrandedCircleSection({
    super.key,
    required this.products,
    this.title = 'À la une',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) return const SizedBox.shrink();

    final exchangeState  = ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Titre ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFFFF8C00), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1A1F2E),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
        // ── Carrousel horizontal ───────────────────────────────────────────
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, i) {
              final product = products[i];
              final borderColor = _circleBorderColors[i % _circleBorderColors.length];
              // Thème clair : texte sombre et couleur de prix assombrie pour rester lisible
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final nameColor = isDark ? Colors.white : const Color(0xFF1A1F2E);
              final priceColor = isDark ? borderColor : _darken(borderColor);

              // Prix formaté
              final priceUsd = double.tryParse(product.price) ?? 0.0;
              final displayPrice = exchangeState.selectedCurrency == Currency.USD
                  ? priceUsd
                  : exchangeNotifier.convertAmount(priceUsd, from: Currency.USD);
              final formattedPrice = exchangeNotifier.formatAmount(
                  displayPrice, currency: exchangeState.selectedCurrency);

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
                ),
                child: Container(
                  width: 106,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Cercle image ────────────────────────────────────
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 3),
                          color: Colors.black,
                          boxShadow: [
                            BoxShadow(
                              color: borderColor.withOpacity(0.45),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: product.images.isNotEmpty
                              ? Image.network(
                                  product.images[0],
                                  fit: BoxFit.cover,
                                  cacheWidth: 180,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.image, color: Colors.grey, size: 32),
                                )
                              : const Icon(Icons.image, color: Colors.grey, size: 32),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // ── Nom du produit ──────────────────────────────────
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'CreatoDisplay',
                          color: nameColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ── Badge prix coloré ───────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? borderColor.withValues(alpha: 0.18)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: priceColor, width: 1),
                        ),
                        child: Text(
                          formattedPrice,
                          style: TextStyle(
                            fontFamily: 'CreatoDisplay',
                            color: priceColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // ── Badge "Original" — uniquement si brandCertified ──
                      if (product.brandCertified)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, color: Color(0xFFFF8C00), size: 9),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                // 10 caractères maximum : évite le chevauchement entre colonnes
                                _shortBrand(product.brandDisplayName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: const TextStyle(
                                  color: Color(0xFFFF8C00),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}


class TopSellersSection extends StatelessWidget {
  final List<Product> products;

  const TopSellersSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade900, Colors.orange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("⭐ Meilleurs Vendeurs", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Icon(Icons.trending_up, color: Colors.white.withOpacity(0.8), size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text("Les produits les plus populaires", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: products.isEmpty ? 3 : products.length,
              itemBuilder: (context, index) {
                if (products.isEmpty) return _buildPlaceholderCard();
                final product = products[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
                  child: DashboardProductCard(
                    product: product,
                    priceColor: Colors.orange,
                    badgeText: "TOP",
                    badgeColor: Colors.orange,
                    subtitleWidget: Row(
                      children: [
                        const Icon(Icons.visibility, size: 10, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text("Populaire", style: TextStyle(color: Colors.grey[500], fontSize: 10)),
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

  Widget _buildPlaceholderCard() {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      color: Colors.grey[900],
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class VerifiedShopProductsSection extends StatelessWidget {
  final List<Product> products;

  const VerifiedShopProductsSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // ── Drapeau DRC en fond (40% opacité) ──
            Positioned.fill(
              child: Opacity(
                opacity: 0.4,
                child: Image.asset(
                  'assets/images/drc flag.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // ── Gradient bleu par-dessus pour lisibilité ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade900.withOpacity(0.78),
                      Colors.blue.shade700.withOpacity(0.60),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // ── Contenu ──
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Grands Magasins", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: Colors.white, size: 12),
                                SizedBox(width: 2),
                                Text("Certifié", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const VerifiedShopsProductsPage()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("Supermarchés et commerces vérifiés", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 178,
                    child: Builder(
                      builder: (context) {
                        // ── Round-robin multi-passes pour atteindre 10 produits minimum ──
                        // Passe 1 : 1 produit par boutique (diversité maximale)
                        // Passe 2+ : remplissage avec les boutiques qui ont plus de produits
                        const int targetCount = 10;
                        const int maxPerShop = 4; // max produits par boutique

                        // Regrouper par boutique (shopId ou seller)
                        final Map<String, List<Product>> byShop = {};
                        for (final p in products) {
                          final rawShopName = p.shopName ?? '';
                          final isGenericName = rawShopName.toUpperCase().contains('BOUTIQUE ENTREPRISE') ||
                              rawShopName.toUpperCase() == 'BOUTIQUE';
                          final shopKey = p.shopId ?? (isGenericName ? null : p.shopName) ?? p.seller;
                          byShop.putIfAbsent(shopKey, () => []).add(p);
                        }

                        // Round-robin progressif jusqu'à targetCount ou épuisement
                        final diversified = <Product>[];
                        final seenIds = <String>{};
                        for (int pass = 0; pass < maxPerShop && diversified.length < targetCount; pass++) {
                          for (final shopProducts in byShop.values) {
                            if (pass < shopProducts.length) {
                              final p = shopProducts[pass];
                              if (!seenIds.contains(p.id)) {
                                seenIds.add(p.id);
                                diversified.add(p);
                              }
                            }
                          }
                        }

                        final displayProducts = diversified.isEmpty ? products : diversified;

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: displayProducts.isEmpty ? 3 : displayProducts.length,
                          itemBuilder: (context, index) {
                            if (displayProducts.isEmpty) return _buildPlaceholderCard();
                            final product = displayProducts[index];
                            return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
                              child: DashboardProductCard(
                                product: product,
                                priceColor: Colors.blueAccent,
                                priceFontSize: 12,
                                badgeText: "Vérifié",
                                badgeColor: Colors.green,
                                badgeOnRight: true,
                                cardColor: Colors.white,
                                imageBackgroundColor: Colors.white,
                                subtitleWidget: () {
                                  final rawShopName = product.shopName ?? '';
                                  final isGenericName = rawShopName.toUpperCase().contains('BOUTIQUE ENTREPRISE') ||
                                      rawShopName.toUpperCase() == 'BOUTIQUE';
                                  final displayName = (!isGenericName && rawShopName.isNotEmpty)
                                      ? rawShopName
                                      : product.seller;
                                  return Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                                  );
                                }(),
                              ),
                            );
                          },
                        );
                      },
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

  
  Widget _buildPlaceholderCard() {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      color: Colors.grey[900],
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

/// Grille du Top Classement : toujours 2 colonnes, cartes au style « marketplace » (2 par ligne).
/// La hauteur des cellules est calculée depuis la largeur de l'écran pour que
/// le visuel reste carré et que le bloc texte (74 px) ne déborde jamais.
class TopRankingGrid extends StatelessWidget {
  final List<Product> products;
  /// Conservé pour compatibilité d'appel : la grille est forcée à 2 colonnes.
  final int crossAxisCount;
  final double childAspectRatio;
  /// Index global du premier produit de ce chunk dans la liste totale du classement
  final int startIndex;
  /// Produits de grands magasins intercalés dans la grille : ils portent un badge.
  final bool Function(Product product)? isStoreProduct;

  static const int columns = 2;
  static const double gutter = 8;
  static const double textBlockHeight = 78;

  const TopRankingGrid({
    super.key,
    required this.products,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.7,
    this.startIndex = 0,
    this.isStoreProduct,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Padding horizontal du SliverPadding (8 + 8) et espace entre les colonnes
    final cellWidth = (screenWidth - 16 - gutter) / columns;
    final aspect = cellWidth / (cellWidth + textBlockHeight);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: aspect,
          crossAxisSpacing: gutter,
          mainAxisSpacing: 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (products.isEmpty) return Container(color: Colors.grey[900]);
            return TopRankingProductCard(
              product: products[index],
              storeBadge: isStoreProduct?.call(products[index]) ?? false,
            );
          },
          childCount: products.isEmpty ? columns : products.length,
        ),
      ),
    );
  }
}

/// Carte produit du Top Classement (style 2 colonnes) :
/// visuel carré · titre sur 1 ligne · boutique en rouge (+ avatar) · prix rouge · nombre vendu.
class TopRankingProductCard extends ConsumerWidget {
  final Product product;

  /// Badge « Grand magasin » (produit certifié intercalé dans la grille du marché).
  final bool storeBadge;

  const TopRankingProductCard({super.key, required this.product, this.storeBadge = false});

  static const Color _priceBlue = Color(0xFF64B5F6); // bleu clair (un ton plus clair)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    ref.watch(exchangeRateProvider);
    final priceUsd = double.tryParse(product.price) ?? 0.0;
    final formattedPrice = ref
        .read(exchangeRateProvider.notifier)
        .formatProductPrice(priceUsd);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(6),
        ),
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
              height: TopRankingGrid.textBlockHeight,
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
                    Text(
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
                    // Boutique vérifiée : livraison en 24 h
                    if (product.shopVerified || product.sellerHasCertifiedShop || storeBadge) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Delivery24hIcon(size: 18, color: titleColor),
                          const SizedBox(width: 5),
                          Text(
                            'Livraison 24h',
                            style: TextStyle(color: titleColor.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w600),
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
                      placeholder: (_, __) => Container(
                        color: isDark ? Colors.grey[900] : Colors.grey[200],
                      ),
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
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
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
                      errorWidget: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 12, color: Colors.black54),
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
