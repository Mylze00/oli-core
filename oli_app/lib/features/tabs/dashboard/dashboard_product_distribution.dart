import 'dart:math';
import '../../../core/services/hive_cache_service.dart';
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

  /// Clé de stockage local de la Sélection (mot-clé + ids + date du tirage).
  static const String _selectionCacheKey = 'dashboard_selection';

  /// La Sélection ne change qu'une fois toutes les 12 heures.
  static const Duration selectionLifetime = Duration(hours: 12);

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
    
    // Mélange reproductible : tant que la liste en cache est la même (12 h),
    // chaque section garde les mêmes produits à la réouverture.
    final random = Random(allProducts.isEmpty
        ? 0
        : allProducts.first.id.codeUnits.fold<int>(0, (seed, c) => (seed * 31 + c) & 0x7fffffff));
    final shuffledProducts = List<Product>.from(allProducts)..shuffle(random);

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

    // Sélection mémorisée : on la réutilise tant qu'elle a moins de 12 h,
    // même après un pull-to-refresh ou un redémarrage de l'app.
    final saved = _loadSaved(_selectionCacheKey, allProducts,
        minCount: 3, requireKeyword: true);
    if (saved != null) {
      cachedSelectionKeyword = saved.key;
      cachedSelectionProducts = saved.value;
    } else {
      final validKeys = groupedProducts.keys
          .where((k) => groupedProducts[k]!.length >= 3)
          .toList();
      if (validKeys.isNotEmpty) {
        // Tirage vraiment aléatoire : la graine de [random] dépend de la liste,
        // elle redonnerait toujours le même mot-clé.
        validKeys.shuffle(Random());
        cachedSelectionKeyword = validKeys.first;
        cachedSelectionProducts =
            groupedProducts[cachedSelectionKeyword]!.take(15).toList();
        _save(_selectionCacheKey, cachedSelectionProducts,
            keyword: cachedSelectionKeyword);
      }
    }
    for (var p in cachedSelectionProducts) {
      usedIds.add(p.id);
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

  /// Relit un tirage stocké sous [key] s'il a moins de [selectionLifetime].
  /// Retourne (mot-clé, produits encore présents dans [allProducts] et absents
  /// de [excludedIds]), ou null si le tirage est expiré, absent, ou s'il reste
  /// moins de [minCount] produits (ou pas de mot-clé si [requireKeyword]).
  MapEntry<String, List<Product>>? _loadSaved(
    String key,
    List<Product> allProducts, {
    required int minCount,
    Set<String> excludedIds = const {},
    bool requireKeyword = false,
  }) {
    final raw = HiveCacheService.getCache(key);
    if (raw is! Map) return null;
    final savedAt = DateTime.tryParse(raw['savedAt']?.toString() ?? '');
    final ids = (raw['ids'] as List?)?.map((e) => e.toString()).toList();
    if (savedAt == null || ids == null) return null;
    if (DateTime.now().difference(savedAt) >= selectionLifetime) return null;

    final byId = {for (final p in allProducts) p.id: p};
    final products = [
      for (final id in ids)
        if (byId[id] != null && !excludedIds.contains(id)) byId[id]!,
    ];
    if (products.length < minCount) return null;
    final keyword = raw['keyword']?.toString() ?? '';
    if (requireKeyword && keyword.isEmpty) return null;
    return MapEntry(keyword, products);
  }

  /// Mémorise un tirage avec l'heure du tirage.
  void _save(String key, List<Product> products, {String keyword = ''}) {
    HiveCacheService.setCache(key, {
      'keyword': keyword,
      'ids': products.map((p) => p.id).toList(),
      'savedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Remet à zéro les caches (ex: lors d'un pull-to-refresh).
  /// La Sélection stockée est conservée : elle sera relue au prochain calcul.
  void resetDistribution() {
    distributionComputed = false;
    cachedSelectionKeyword = '';
    cachedSelectionProducts = [];
    cachedSuperOffers = [];
    cachedDiscoveryList = [];
    cachedRankingList = [];
  }
}
