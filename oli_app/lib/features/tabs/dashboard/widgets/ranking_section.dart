import 'package:flutter/material.dart';
import '../../../../models/product_model.dart';
import 'product_sections.dart'; // TopRankingGrid + BrandedCircleSection

/// Helper pour construire la section "Top Classement" de la page d'accueil.
///
/// Utilise un motif visuel répétitif :
///   - 6 produits en grille 3 colonnes
///   - 2 produits en grille 2 colonnes (avec label "Focus")
///   - 1 bannière promotionnelle
class RankingSectionHelper {
  RankingSectionHelper._(); // Non-instanciable

  // ── Bannières promotionnelles ────────────────────────────────────────────
  static const List<Map<String, dynamic>> promoMessages = [
    {
      'title': 'Guérite Oli ',
      'text':
          'Achetez et récupérez vos commandes dans le guérite Oli de votre supermarché',
      'gradient1': Color(0xFF4A0E8F),
      'gradient2': Color(0xFF2D0A5E),
      'paddingV': 20.0,
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
      'gradient1': Color(0xFFD84315),
      'gradient2': Color(0xFF8F2B00),
      'paddingV': 32.0,
      'titleSize': 22.0,
      'textSize': 15.0,
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
  static List<Widget> buildSlivers(
    List<Product> allProducts,
    Color textColor, {
    List<Product> brandedProducts = const [],
  }) {
    final List<Widget> slivers = [];
    int index = 0;
    int promoIndex = 0;

    while (index < allProducts.length) {
      // ── Bloc 3 colonnes (6 produits) ──
      final chunk3Cols = allProducts.skip(index).take(6).toList();
      if (chunk3Cols.isNotEmpty) {
        final chunkStart = index;
        index += chunk3Cols.length;
        slivers.add(TopRankingGrid(
          products: chunk3Cols,
          crossAxisCount: 3,
          childAspectRatio: 0.75,
          startIndex: chunkStart,
        ));
      }

      // ── Bloc 2 colonnes (2 produits) avec label ──
      if (index < allProducts.length) {
        final chunk2Cols = allProducts.skip(index).take(2).toList();
        if (chunk2Cols.isNotEmpty) {
          // Déduire un mot-clé contextuel depuis le 1er produit
          final firstProduct = chunk2Cols.first;
          final words = firstProduct.name.split(' ');
          String focusWord = words.isNotEmpty ? words.first : '';
          if (words.length > 1 &&
              (focusWord.length <= 2 || stopWords.contains(focusWord))) {
            focusWord = words[1];
          }

          if (focusWord.length > 2) {
            slivers.add(SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Container(width: 4, height: 16, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Focus : $focusWord',
                      style: TextStyle(
                        color: textColor.withOpacity(0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ));
          }

          slivers.add(const SliverPadding(padding: EdgeInsets.only(top: 8)));
          final chunkStart2 = index;
          index += chunk2Cols.length;
          slivers.add(TopRankingGrid(
            products: chunk2Cols,
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            startIndex: chunkStart2,
          ));
          slivers.add(const SliverPadding(padding: EdgeInsets.only(top: 8)));
        }
      }

      // ── Slot : BrandedCircleSection remplace TOUTE bannière bleue (bg_color) ──
      // La section brandée n'est affichée qu'une seule fois (brandedShown guard).
      final promo = promoMessages[promoIndex % promoMessages.length];
      final bool isBlueBanner = promo.containsKey('bg_color');
      final bool showCircleSlot = isBlueBanner && brandedProducts.isNotEmpty;

      if (showCircleSlot) {
        // Widget "À la une" — produits circulaires brandés (1 seule fois)
        slivers.add(SliverToBoxAdapter(
          child: BrandedCircleSection(products: brandedProducts),
        ));
        promoIndex++;
      } else {
      final Color? bgCol = promo.containsKey('bg_color') ? promo['bg_color'] as Color : null;
      final Color grad1 = promo.containsKey('gradient1') ? promo['gradient1'] as Color : (bgCol ?? Colors.blue);
      final Color grad2 = promo.containsKey('gradient2') ? promo['gradient2'] as Color : (bgCol ?? Colors.blue);
      final double padV = promo['paddingV'] as double;
      final double tSize = promo['titleSize'] as double;
      final double dSize = promo['textSize'] as double;
      final bool isCentered = promo.containsKey('isCentered') ? promo['isCentered'] as bool : false;
      promoIndex++;

      slivers.add(SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: padV),
          decoration: BoxDecoration(
            color: bgCol,
            gradient: bgCol == null
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
                promo['title'] as String,
                textAlign: isCentered ? TextAlign.center : TextAlign.left,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: tSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                promo['text'] as String,
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
      } // fin else bannière classique
    }

    return slivers;
  }
}
