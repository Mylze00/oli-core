import 'package:cached_network_image/cached_network_image.dart';
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

  static const int columns = 2;
  static const double gutter = 8;
  static const double textBlockHeight = 58;

  const TopRankingGrid({
    super.key,
    required this.products,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.7,
    this.startIndex = 0,
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
            return TopRankingProductCard(product: products[index]);
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

  const TopRankingProductCard({super.key, required this.product});

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
              child: product.images.isNotEmpty
                  ? CachedNetworkImage(
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
                    )
                  : Container(
                      color: isDark ? Colors.grey[900] : Colors.grey[200],
                      child: const Icon(Icons.image, color: Colors.grey),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
