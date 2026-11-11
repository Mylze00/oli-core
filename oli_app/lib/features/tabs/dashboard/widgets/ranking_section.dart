import 'package:flutter/material.dart';
import '../../../../models/product_model.dart';
import 'product_sections.dart'; // TopRankingGrid + BrandedCircleSection
import 'feed_banner_tile.dart';
import '../providers/feed_banners_provider.dart';

/// Helper pour construire la section "Top Classement" de la page d'accueil.
///
/// Utilise un motif visuel répétitif :
///   - 8 produits en grille 2 colonnes (4 lignes)
///   - 1 bannière promotionnelle ou section « Original »
///
/// Le label « Focus » a été supprimé.
class RankingSectionHelper {
  RankingSectionHelper._(); // Non-instanciable

  // ── Bannières promotionnelles ────────────────────────────────────────────
  static const List<Map<String, dynamic>> promoMessages = [
    {
      'title': '',
      'text': '',
      'bg_image': 'assets/images/bandes/pub service fintech.png', // Utilisation de votre image
      'gradient1': Color(0xFF4A0E8F),
      'gradient2': Color(0xFF2D0A5E),
      'paddingV': 50.0,
      'titleSize': 17.0,
      'textSize': 13.0,
    },
    {
      'title': 'Vendez sur Oli',
      'text': 'dès maintenant\net gratuitement',
      'bg_color': Color(0xFF4A78D6), // Bleu plus doux similaire à l'image
      'paddingV': 24.0, // Plus d'espace
      'titleSize': 26.0,
      'textSize': 20.0,
      'isCentered': true, // Nouveau flag pour centrer
      'hasBorder': true, // Nouveau flag pour la bordure blanche
    },
    {
      'title': 'Vendez sur Oli ',
      'text': 'Profitez des avantages en vendant sur Oli, commencez gratuitement',
      'bg_color': Color(0xFFD84315), // Couleur de fond unie
      'paddingV': 24.0,
      'titleSize': 16.0, // Même taille
      'textSize': 16.0,  // Même taille
    },
  ];

  // ── Stop words partagés avec la logique de distribution ──────────────────
  static const List<String> stopWords = [
    'Paire', 'Lot', 'Set', 'Kit', 'Nouveau', 'Promo', 'Super', 'Pack',
    'Mini', 'La', 'Le', 'Les',
  ];

  // ── Builder principal ────────────────────────────────────────────────────

  /// Retourne la liste de Slivers formant le Top Classement.
  ///
  /// [allProducts]     : tous les produits à afficher (déjà triés/limités).
  /// [textColor]       : couleur du texte selon le thème (dark/light).
  /// [brandedProducts] : produits brandCertified pour la section circulaire.
  /// [feedBanners]     : bannières gérées depuis l'admin. Elles prennent la
  ///                     place de la bannière fintech, à tour de rôle ; sans
  ///                     bannière, la bannière fintech locale est affichée.
  static List<Widget> buildSlivers(
    List<Product> allProducts,
    Color textColor, {
    List<Product> brandedProducts = const [],
    List<FeedBanner> feedBanners = const [],
  }) {
    final List<Widget> slivers = [];
    int index = 0;
    int promoIndex = 0;
    int brandedSlotCount = 0; // Compteur pour rotation titre + tranche produits
    int feedBannerSlotCount = 0; // Rotation des bannières gérées depuis l'admin

    // Titres rotatifs pour les sections brandées
    const brandedTitles = ['À la une', 'Branding Original', 'Produit Original'];
    const brandedSliceSize = 6; // produits par slot
    const productsPerBlock = 8; // 4 lignes de 2 produits, puis une bannière

    while (index < allProducts.length) {
      // ── Bloc grille : 8 produits, toujours 2 par ligne (4 lignes) ──
      final chunk = allProducts.skip(index).take(productsPerBlock).toList();
      if (chunk.isNotEmpty) {
        final chunkStart = index;
        index += chunk.length;
        slivers.add(const SliverPadding(padding: EdgeInsets.only(top: 8)));
        slivers.add(TopRankingGrid(
          products: chunk,
          crossAxisCount: TopRankingGrid.columns,
          startIndex: chunkStart,
        ));
      }

      // ── Slot : BrandedCircleSection remplace TOUTE bannière bleue (bg_color) ──
      // La section brandée n'est affichée qu'une seule fois (brandedShown guard).
      final promo = promoMessages[promoIndex % promoMessages.length];
      final bool isBlueBanner = promo.containsKey('bg_color');
      final bool showCircleSlot = isBlueBanner && brandedProducts.isNotEmpty;

      if (showCircleSlot) {
        // Tranche de produits pour ce slot (6 produits chacun, décalés)
        final sliceStart = (brandedSlotCount * brandedSliceSize) % (brandedProducts.length == 0 ? 1 : brandedProducts.length);
        final slice = brandedProducts.length <= brandedSliceSize
            ? brandedProducts
            : brandedProducts.skip(sliceStart).take(brandedSliceSize).toList();

        final title = brandedTitles[brandedSlotCount % brandedTitles.length];

        slivers.add(SliverToBoxAdapter(
          child: BrandedCircleSection(products: slice, title: title),
        ));
        brandedSlotCount++;
        promoIndex++;
      } else {
      final Color? bgCol = promo.containsKey('bg_color') ? promo['bg_color'] as Color : null;
      final String? bgImg = promo.containsKey('bg_image') ? promo['bg_image'] as String : null;
      final String titleStr = promo['title'] as String;
      final String textStr = promo['text'] as String;
      final bool isEmptyContent = titleStr.isEmpty && textStr.isEmpty;

      promoIndex++;

      if (isEmptyContent && bgImg != null && feedBanners.isNotEmpty) {
        final banner = feedBanners[feedBannerSlotCount % feedBanners.length];
        feedBannerSlotCount++;
        slivers.add(SliverToBoxAdapter(
          child: FeedBannerTile(key: ValueKey('feed-banner-${banner.id}'), banner: banner),
        ));
      } else if (isEmptyContent && bgImg != null) {
        slivers.add(SliverToBoxAdapter(
          // Même écart (10 px) et même arrondi (6 px) que les cartes produits.
          // Le bloc suivant ajoute déjà 8 px en haut, d'où les 2 px en bas.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                bgImg,
                fit: BoxFit.fill,
              ),
            ),
          ),
        ));
      } else {
        final Color grad1 = promo.containsKey('gradient1') ? promo['gradient1'] as Color : (bgCol ?? Colors.blue);
        final Color grad2 = promo.containsKey('gradient2') ? promo['gradient2'] as Color : (bgCol ?? Colors.blue);
        final double padV = promo['paddingV'] as double;
        final double tSize = promo['titleSize'] as double;
        final double dSize = promo['textSize'] as double;
        final bool isCentered = promo.containsKey('isCentered') ? promo['isCentered'] as bool : false;

        slivers.add(SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), // horizontal: 16 réduit la largeur
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: padV),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12), // Coins arrondis
              color: bgCol,
              image: bgImg != null
                  ? DecorationImage(
                      image: AssetImage(bgImg),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: (bgCol == null && bgImg == null)
                  ? LinearGradient(
                      colors: [grad1, grad2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: grad1.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Text(
                  titleStr,
                  textAlign: isCentered ? TextAlign.center : TextAlign.left,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: tSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  textStr,
                  textAlign: isCentered ? TextAlign.center : TextAlign.left,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: dSize,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ));
      }
      } // fin else bannière classique
    }

    return slivers;
  }
}
