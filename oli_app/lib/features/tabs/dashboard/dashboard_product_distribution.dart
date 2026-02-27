import '../../../models/product_model.dart';

/// Mixin qui encapsule toute la logique de distribution des produits admin
/// sur les sections de la page d'accueil (Sélection, Découverte, Top Classement).
///
/// Usage : ajouter `with DashboardProductDistribution` sur le State du dashboard.
mixin DashboardProductDistribution {
  // ── Constantes ──────────────────────────────────────────────────────────
  static const List<String> stopWords = [
    'Paire', 'Lot', 'Set', 'Kit', 'Nouveau', 'Promo', 'Super', 'Pack',
    'Mini', 'La', 'Le', 'Les',
  ];

  // ── Caches (calculés une seule fois) ────────────────────────────────────
  String cachedSelectionKeyword = '';
  List<Product> cachedSelectionProducts = [];
  List<Product> cachedSuperOffers = [];
  List<Product> cachedDiscoveryList = [];
  List<Product> cachedRankingList = [];
  bool distributionComputed = false;

  // ── Logique principale ───────────────────────────────────────────────────

  /// Distribue les [allProducts] (produits admin OLI) dans les différentes
  /// sections de la page d'accueil de façon INDÉPENDANTE.
  ///
  /// Chaque section puise dans l'ensemble complet — aucune section ne vide
  /// les autres.
  void computeProductDistribution(List<Product> allProducts) {
    cachedSelectionKeyword = '';
    cachedSelectionProducts = [];

    // ── 1. Section "Sélection" : groupe par mot-clé (seuil min 3 produits) ──
    final Map<String, List<Product>> groupedProducts = {};
    for (final product in allProducts) {
      final words = product.name.split(' ');
      String focusKW = words.isNotEmpty ? words.first : '';
      if (words.length > 1 &&
          (focusKW.length <= 2 || stopWords.contains(focusKW))) {
        focusKW = words[1];
      }
      focusKW = focusKW.replaceAll(RegExp(r'[^\w\s]+'), '');
      if (focusKW.length > 2) {
        focusKW =
            focusKW[0].toUpperCase() + focusKW.substring(1).toLowerCase();
        groupedProducts.putIfAbsent(focusKW, () => []).add(product);
      }
    }

    final validKeys = groupedProducts.keys
        .where((k) => groupedProducts[k]!.length >= 3)
        .toList();
    if (validKeys.isNotEmpty) {
      validKeys.shuffle();
      cachedSelectionKeyword = validKeys.first;
      cachedSelectionProducts =
          groupedProducts[cachedSelectionKeyword]!.take(15).toList();
    }

    // ── 2. Section "Découverte" : 5 produits aléatoires parmi TOUS les produits admin ──
    final shuffledForDiscovery = List<Product>.from(allProducts)..shuffle();
    cachedDiscoveryList = shuffledForDiscovery.take(5).toList();

    // ── 3. Super Offres (donnée intermédiaire pour fallback) ──
    cachedSuperOffers = allProducts.take(10).toList();

    // ── 4. Section "Top Classement" : TOUS les produits admin, triés par nom ──
    cachedRankingList = List<Product>.from(allProducts)
      ..sort((a, b) => a.name.compareTo(b.name));

    distributionComputed = true;
  }

  /// Remet à zéro les caches (ex: lors d'un pull-to-refresh).
  void resetDistribution() {
    distributionComputed = false;
    cachedSelectionKeyword = '';
    cachedSelectionProducts = [];
    cachedSuperOffers = [];
    cachedDiscoveryList = [];
    cachedRankingList = [];
  }
}
