import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../utils/cloudinary_helper.dart';
import '../pages/product_details_page.dart';

/// Filtre strict : UNIQUEMENT les vendeurs ordinaires.
/// Exclut : entreprises, certifiés, boutiques vérifiées, sellerIsVerified.
List<Product> _pickSecondhand(List<Product> all, {int max = 20}) {
  final ordinary = all.where((p) {
    if (p.images.isEmpty) return false;
    final type = (p.sellerAccountType).toLowerCase().trim();
    // Exclure tous les types professionnels/certifiés
    if (type == 'entreprise') return false;
    if (type == 'certifie' || type == 'certified') return false;
    if (type == 'shop' || type == 'boutique') return false;
    if (p.sellerIsVerified) return false;          // badge ✓ bleu/or
    if (p.sellerHasCertifiedShop) return false;    // boutique certifiée
    if (p.shopVerified) return false;              // shop vérifiée
    return true;
  }).toList();

  // Plus récents en premier
  ordinary.sort((a, b) {
    final dateA = a.createdAt ?? DateTime(2000);
    final dateB = b.createdAt ?? DateTime(2000);
    return dateB.compareTo(dateA);
  });

  return ordinary.take(max).toList();
}

/// Widget "Seconde Main & Vendeurs Personnels"
/// Fond violet unifié, carousel horizontal de cartes rectangulaires coins carrés.
class MarketSecondhandCarousel extends ConsumerStatefulWidget {
  final List<Product> products;
  const MarketSecondhandCarousel({super.key, required this.products});

  @override
  ConsumerState<MarketSecondhandCarousel> createState() =>
      _MarketSecondhandCarouselState();
}

class _MarketSecondhandCarouselState
    extends ConsumerState<MarketSecondhandCarousel> {
  late List<Product> _items;

  @override
  void initState() {
    super.initState();
    _items = _pickSecondhand(widget.products);
  }

  @override
  void didUpdateWidget(MarketSecondhandCarousel old) {
    super.didUpdateWidget(old);
    if (old.products != widget.products) {
      _items = _pickSecondhand(widget.products);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    final screenW = MediaQuery.of(context).size.width;

    // 3 cartes visibles
    const spacing  = 6.0;
    const sidePad  = 10.0;
    final cardW = (screenW - sidePad * 2 - spacing * 2) / 3.0;
    final imgH  = cardW * 1.0;    // image carrée
    const infoH = 76.0;           // zone texte (prix gros → plus de place)
    final cardH = imgH + infoH;

    // Palette violette
    const bg      = Color(0xFF3B006E);
    const bgDark  = Color(0xFF28004E);
    const accent  = Color(0xFFCE93D8);  // prix violet clair
    const locCol  = Color(0xFFB39DDB);  // localisation lilas

    return Container(
      color: bg,
      // ── Interligne haut et bas ──
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── En-tête ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                const Icon(Icons.recycling, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seconde Main',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      'Vendeurs personnels · Récemment ajoutés',
                      style: TextStyle(color: Colors.white60, fontSize: 9.5),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_items.length} articles',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Carousel ──
          SizedBox(
            height: cardH,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: sidePad),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final product = _items[index];
                final priceUsd = double.tryParse(product.price) ?? 0.0;
                final formattedPrice = exchangeNotifier.formatProductPrice(priceUsd);

                // Localisation : product.location en priorité, sinon shopName
                final location = (product.location?.isNotEmpty == true)
                    ? product.location!
                    : (product.shopName?.isNotEmpty == true ? product.shopName! : '');

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailsPage(product: product),
                    ),
                  ),
                  child: Container(
                    width: cardW,
                    margin: EdgeInsets.only(
                      right: index < _items.length - 1 ? spacing : 0,
                      bottom: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bgDark,
                      borderRadius: BorderRadius.zero,  // coins carrés
                      border: Border.all(color: Colors.white, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Image ──
                        SizedBox(
                          height: imgH,
                          width: double.infinity,
                          child: Image.network(
                            CloudinaryHelper.thumbnail(
                              product.images.first,
                              width: 200,
                              height: 200,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF4A006A),
                              child: const Center(
                                child: Icon(Icons.image_not_supported,
                                    color: Colors.white24, size: 24),
                              ),
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: const Color(0xFF4A006A),
                                child: const Center(
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // ── Infos ──
                        SizedBox(
                          height: infoH,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [

                                // Nom du produit (2 lignes max)
                                Text(
                                  product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                // Prix — 150% plus grand (9 × 1.5 = 13.5)
                                Text(
                                  formattedPrice,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: accent,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                // Nom du vendeur
                                Text(
                                  product.seller,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.1,
                                  ),
                                ),

                                // Localisation (si disponible)
                                if (location.isNotEmpty) ...[
                                  const SizedBox(height: 1),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on,
                                          size: 7, color: locCol),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          location,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: locCol,
                                            fontSize: 7,
                                            height: 1.1,
                                          ),
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
