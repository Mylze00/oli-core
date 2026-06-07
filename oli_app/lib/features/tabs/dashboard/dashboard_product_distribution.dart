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
    
    final Set<String> usedIds = {};
    
    // Pour que ce soit aléatoire à chaque fois
    final shuffledProducts = List<Product>.from(allProducts)..shuffle();

    // ── 1. Section "Sélection" : groupe par mot-clé (seuil min 3 produits) ──
    final Map<String, List<Product>> groupedProducts = {};
    for (final product in shuffledProducts) {
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
      for (var p in cachedSelectionProducts) {
        usedIds.add(p.id);
      }
    }

    // Méthode locale pour piocher sans doublon
    List<Product> getAvailable(int count) {
      final available = shuffledProducts
          .where((p) => !usedIds.contains(p.id))
          .take(count)
          .toList();
      for (var p in available) {
        usedIds.add(p.id);
      }
      return available;
    }

    // ── 2. Super Offres (10 produits max) ──
    cachedSuperOffers = getAvailable(10);

    // ── 3. Section "Découverte" (5 produits max) ──
    cachedDiscoveryList = getAvailable(5);

    // ── 4. Section "Top Classement" : Diversification par catégorie ──
    // On récupère tout ce qui reste
    final remainingProducts = shuffledProducts
        .where((p) => !usedIds.contains(p.id))
        .toList();
    
    // On les regroupe par catégorie (ou un fallback "Autre")
    final Map<String, List<Product>> categoryGroups = {};
    for (var p in remainingProducts) {
      final cat = p.category ?? 'Autre';
      categoryGroups.putIfAbsent(cat, () => []).add(p);
    }

    // On les pioche à tour de rôle (Round-Robin) pour assurer la diversité
    List<Product> diversifiedRanking = [];
    bool hasAdded = true;
    while(hasAdded) {
      hasAdded = false;
      for (var key in categoryGroups.keys) {
        if (categoryGroups[key]!.isNotEmpty) {
          diversifiedRanking.add(categoryGroups[key]!.removeAt(0));
          hasAdded = true;
        }
      }
    }
    
    cachedRankingList = diversifiedRanking;
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
