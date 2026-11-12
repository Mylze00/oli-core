
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../providers/market_provider.dart';
import '../pages/product_details_page.dart';
import '../widgets/market_spotlight_carousel.dart';
import '../widgets/market_product_grid.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../tabs/dashboard/widgets/verified_shops_carousel.dart';
import '../../../tabs/dashboard/widgets/product_sections.dart';
import '../../../tabs/dashboard/providers/shops_provider.dart';
import '../../../tabs/dashboard/widgets/category_glass_section.dart';
import '../../../../core/theme/oli_colors.dart';

/// Page Marché - Produits des utilisateurs
class MarketView extends ConsumerStatefulWidget {
  final String? initialCategoryLabel;
  final String? initialSearchQuery;

  const MarketView({
    super.key,
    this.initialCategoryLabel,
    this.initialSearchQuery,
  });

  @override
  ConsumerState<MarketView> createState() => MarketViewState();
}

class MarketViewState extends ConsumerState<MarketView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = "Tout";
  String _searchQuery = "";

  // Cache du shuffle : ne recalcule que si les données ou les filtres changent
  List<Product> _cachedFiltered = [];
  String _lastFilterKey = ''; // clé = "searchQuery|category"
  List<String> _lastProductIds = [];

  /// Défilement continu : la page suivante (50 produits) se charge près du bas.
  final ScrollController _scroll = ScrollController();
  bool _loadingMore = false;

  final Map<String, String> _categories = {'Tout': '', 'Électronique': 'electronics', 'Mode': 'fashion', 'Maison': 'home', 'Alimentation': 'food', 'Beauté': 'beauty', 'Industrie': 'industry', 'Sports': 'sports', 'Outils': 'tools', 'Construction': 'construction', 'Autres': 'other', 'Véhicules': 'vehicles', 'Jouets': 'toys', 'Sécurité': 'security', 'Jardin': 'garden', 'Bébé': 'baby', 'Bureau': 'office', 'Animaux': 'pets', 'Santé': 'health'
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchCtrl.text = widget.initialSearchQuery!;
      _searchQuery = widget.initialSearchQuery!;
    }
    if (widget.initialCategoryLabel != null) {
      _selectedCategory = widget.initialCategoryLabel!;
    }
    _scroll.addListener(_onScroll);
    // Ouverture sur une catégorie précise : produits de cette catégorie depuis le serveur
    final notifier = ref.read(marketProductsProvider.notifier);
    if (_categoryKey != notifier.category) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) notifier.fetchProducts(category: _categoryKey);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Clé serveur de la catégorie choisie (null pour « Tout »).
  String? get _categoryKey {
    final key = _categories[_selectedCategory] ?? '';
    return _selectedCategory == 'Tout' || key.isEmpty ? null : key;
  }

  /// Recharge depuis le serveur : toute la catégorie, pas seulement les produits déjà chargés.
  void _reloadForCategory() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    ref.read(marketProductsProvider.notifier).fetchProducts(category: _categoryKey);
  }

  /// Onglet Marché touché : retour en haut de la page.
  void scrollToTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore) return;
    if (_scroll.position.extentAfter > 1200) return;
    final notifier = ref.read(marketProductsProvider.notifier);
    if (!notifier.hasMore) return;
    setState(() => _loadingMore = true);
    notifier.loadMore().whenComplete(() {
      if (mounted) setState(() => _loadingMore = false);
    });
  }

  List<Product> _filterProducts(List<Product> products) {
    // Clé de cache : si rien n'a changé, on retourne le résultat précédent
    // (le shuffle reste STABLE entre les rebuilds, pas de flashs)
    final ids = products.map((p) => p.id).toList();
    final key = '$_searchQuery|$_selectedCategory';
    final sameFilters = key == _lastFilterKey;
    if (sameFilters && _sameIds(ids, _lastProductIds)) return _cachedFiltered;

    // Page suivante chargée (mêmes filtres, anciens produits en tête) : seuls les
    // nouveaux produits sont mélangés puis ajoutés, la grille déjà vue ne bouge pas.
    if (sameFilters && _lastProductIds.isNotEmpty && ids.length > _lastProductIds.length &&
        _sameIds(ids.sublist(0, _lastProductIds.length), _lastProductIds)) {
      final added = _applyFilters(products.sublist(_lastProductIds.length));
      _cachedFiltered = [..._cachedFiltered, ..._diversify(added)];
      _lastProductIds = ids;
      return _cachedFiltered;
    }

    final result = _diversify(_applyFilters(products));
    _cachedFiltered = result;
    _lastFilterKey = key;
    _lastProductIds = ids;
    return result;
  }

  bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Recherche, catégorie et exclusion des entreprises (visibles dans les Grands Magasins).
  List<Product> _applyFilters(List<Product> products) {
    var filtered = products;

    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains(query) ||
        p.seller.toLowerCase().contains(query) ||
        p.description.toLowerCase().contains(query)
      ).toList();
    }

    // Filtre par catégorie
    if (_selectedCategory != "Tout") {
      final categoryKey = _categories[_selectedCategory] ?? "";
      if (categoryKey.isNotEmpty) {
        filtered = filtered.where((p) =>
          p.category?.toLowerCase() == categoryKey.toLowerCase()
        ).toList();
      }
    }

    // EXIGENCES MÉTIER: Le marché ordinaire exclut les entreprises
    // (Les produits d'entreprises sont visibles dans "Grands Magasins")
    filtered = filtered.where((p) => p.sellerAccountType != 'entreprise').toList();
    return filtered;
  }

  /// Mélange les produits et garantit un maximum de diversité vendeur
  /// en tête de liste (au moins 1 produit par vendeur parmi les premiers)
  List<Product> _diversify(List<Product> products) {
    if (products.length <= 1) return products;

    final rng = Random();
    final shuffled = List<Product>.from(products)..shuffle(rng);

    // Construire une tête diversifiée (un produit par vendeur en premier)
    final head = <Product>[];
    final tail = <Product>[];
    final seenSellers = <String>{};

    for (final p in shuffled) {
      final sid = p.sellerId.trim();
      if (sid.isNotEmpty && !seenSellers.contains(sid)) {
        seenSellers.add(sid);
        head.add(p);
      } else {
        tail.add(p);
      }
    }

    // Mélanger aussi la queue
    tail.shuffle(rng);

    return [...head, ...tail];
  }

  /// Nombre de produits ordinaires avant chaque produit de grand magasin.
  static const _storeEvery = 5;

  List<Product> _cachedStores = [];
  String _lastStoreKey = '';

  /// Produits des grands magasins qui respectent la recherche et la catégorie choisies,
  /// mélangés une fois (ordre stable entre deux affichages).
  List<Product> _storeProductsFor(List<Product> stores) {
    final key = '$_searchQuery|$_selectedCategory|${stores.map((p) => p.id).join(',')}';
    if (key == _lastStoreKey) return _cachedStores;

    var list = stores;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list
          .where((p) => p.name.toLowerCase().contains(query) || p.seller.toLowerCase().contains(query))
          .toList();
    }
    final categoryKey = _categories[_selectedCategory] ?? '';
    if (_selectedCategory != 'Tout' && categoryKey.isNotEmpty) {
      list = list.where((p) => p.category?.toLowerCase() == categoryKey.toLowerCase()).toList();
    }
    _cachedStores = List<Product>.from(list)..shuffle(Random());
    _lastStoreKey = key;
    return _cachedStores;
  }

  /// Après chaque série de [_storeEvery] produits ordinaires, un produit de grand magasin
  /// (sans répétition), pour varier la sélection.
  List<Product> _interleaveStores(List<Product> normal, List<Product> stores) {
    if (stores.isEmpty) return normal;
    final normalIds = normal.map((p) => p.id).toSet();
    final queue = stores.where((p) => !normalIds.contains(p.id)).toList();
    final feed = <Product>[];
    var next = 0;
    for (var i = 0; i < normal.length; i++) {
      feed.add(normal[i]);
      if ((i + 1) % _storeEvery == 0 && next < queue.length) feed.add(queue[next++]);
    }
    return feed;
  }

  /// Produits avant « À la une ».
  static const _headCount = 12;

  /// Taille des tranches équilibrées après « À la une » (fixe : l'ordre déjà vu ne bouge pas).
  static const _chunkSize = 24;

  /// Ordonne un bloc pour que les deux colonnes de la grille en quinconce finissent au même
  /// niveau : chaque paire de cartes hautes suit le motif court, haute, haute, court
  /// (la première à droite, la suivante à gauche). Une carte qui casserait l'équilibre
  /// (nombre impair) est reportée dans [carry], au bloc suivant.
  ({List<Product> balanced, List<Product> carry}) _balanceBlock(List<Product> items, bool Function(Product) isTall) {
    final talls = items.where(isTall).toList();
    final shorts = items.where((p) => !isTall(p)).toList();
    final carry = <Product>[];
    if (talls.length.isOdd) carry.add(talls.removeLast());
    if (shorts.length.isOdd) carry.add(shorts.removeLast());

    final out = <Product>[];
    var t = 0;
    var s = 0;
    while (t < talls.length || s < shorts.length) {
      if (t + 1 < talls.length) {
        if (s + 1 < shorts.length) {
          out..add(shorts[s])..add(talls[t])..add(talls[t + 1])..add(shorts[s + 1]);
          s += 2;
        } else {
          out..add(talls[t])..add(talls[t + 1]);
        }
        t += 2;
        // Une rangée de cartes courtes entre deux blocs hauts, pour le rythme
        if (s + 1 < shorts.length) {
          out..add(shorts[s])..add(shorts[s + 1]);
          s += 2;
        }
      } else {
        out..add(shorts[s])..add(shorts[s + 1]);
        s += 2;
      }
    }
    return (balanced: out, carry: carry);
  }

  void _navigateToProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final backgroundColor = isDark ? Colors.black : Colors.grey[400];
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final productsAsync = ref.watch(marketProductsProvider);
    final verifiedShopsAsync = ref.watch(verifiedShopsProvider);
    final verifiedShops = verifiedShopsAsync.valueOrNull ?? [];
    final verifiedShopsProducts = ref.watch(verifiedShopsProductsProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: productsAsync.when(
        // ── LOADING ──
        loading: () => _buildShell(textColor, isDark, [
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          ),
        ]),
        // ── ERROR ──
        error: (error, _) => _buildShell(textColor, isDark, [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Erreur de chargement', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('$error', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(marketProductsProvider.notifier).fetchProducts(category: _categoryKey),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  ),
                ],
              ),
            ),
          ),
        ]),
        // ── DATA ──
        data: (allProducts) {
          final filtered = _filterProducts(allProducts);
          final storeProducts = _storeProductsFor(verifiedShopsProducts);
          final storeIds = storeProducts.map((p) => p.id).toSet();
          bool isStore(Product p) => storeIds.contains(p.id);
          final feed = _interleaveStores(filtered, storeProducts);

          // Avant « À la une » : un seul bloc de 12 produits, équilibré pour que les deux
          // colonnes finissent à la même hauteur ; après : tranches de 24 équilibrées.
          bool isTall(Product p) => MarketProductGrid.isTall(p, isStore: isStore(p));
          final head = _balanceBlock(feed.take(_headCount).toList(), isTall);
          final gridBefore = head.balanced;
          final gridAfterA = <Product>[];
          var carry = head.carry;
          final rest = feed.length > _headCount ? feed.skip(_headCount).toList() : <Product>[];
          for (var i = 0; i < rest.length; i += _chunkSize) {
            final chunk = [...carry, ...rest.skip(i).take(_chunkSize)];
            final isLast = i + _chunkSize >= rest.length;
            final balanced = _balanceBlock(chunk, isTall);
            gridAfterA.addAll(balanced.balanced);
            carry = balanced.carry;
            if (isLast) gridAfterA.addAll(carry);
          }
          if (rest.isEmpty) gridAfterA.addAll(carry);

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(marketProductsProvider.notifier).fetchProducts(category: _categoryKey);
            },
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                // ── 1. APP BAR avec recherche ──
                _buildSearchAppBar(textColor, isDark),

                // ── 2. CATÉGORIES ──
                _buildCategoryChips(isDark),

                // ── 3. BOUTIQUES VÉRIFIÉES ──
                SliverToBoxAdapter(
                  child: VerifiedShopsCarousel(shops: verifiedShops),
                ),

                // ── 4. PRODUITS BOUTIQUES CERTIFIÉES ──
                if (verifiedShopsProducts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: VerifiedShopProductsSection(products: verifiedShopsProducts),
                  ),

                // ── 5. GRILLE AVANT « À LA UNE » (12 produits, colonnes à niveau) ──
                if (gridBefore.isNotEmpty)
                  MarketProductGrid(products: gridBefore, isStoreProduct: isStore),

                // ── 7. SPOTLIGHT CAROUSEL ── (produits non encore affichés)
                if (filtered.length >= 4)
                  SliverToBoxAdapter(
                    child: MarketSpotlightCarousel(products: filtered),
                  ),

                // ── 6. GRILLE APRÈS « À LA UNE » (tranches de 24 équilibrées) ──
                if (gridAfterA.isNotEmpty)
                  MarketProductGrid(products: gridAfterA, isStoreProduct: isStore),



                // ── EMPTY STATE ──
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: textColor.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text('Aucun produit trouvé', style: TextStyle(color: textColor, fontSize: 16)),
                          if (_searchQuery.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'pour "$_searchQuery"',
                                style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // ── PAGE SUIVANTE EN COURS DE CHARGEMENT ──
                if (_loadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                        ),
                      ),
                    ),
                  ),

                SliverPadding(padding: EdgeInsets.only(bottom: bottomNavClearance(context))),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Shell pour loading/error (AppBar + contenu)
  Widget _buildShell(Color textColor, bool isDark, List<Widget> slivers) {
    return CustomScrollView(
      slivers: [
        _buildSearchAppBar(textColor, isDark),
        ...slivers,
      ],
    );
  }

  /// AppBar avec barre de recherche intégrée
  Widget _buildSearchAppBar(Color textColor, bool isDark) {
    return SliverAppBar(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      floating: true,
      snap: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 70,
      title: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Rechercher un produit...',
            hintStyle: TextStyle(color: textColor.withOpacity(0.4), fontSize: 14),
            prefixIcon: Icon(Icons.search, color: textColor.withOpacity(0.4), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() {
                    _searchQuery = "";
                    _searchCtrl.clear();
                  }),
                  child: Icon(Icons.close, color: textColor.withOpacity(0.4), size: 18),
                )
              : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
    );
  }

  /// Chips de catégories horizontales
  Widget _buildCategoryChips(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: CategoryGlassSection(
          categories: _categories,
          selectedCategory: _selectedCategory,
          onCategorySelected: (label) {
            if (label == _selectedCategory) return;
            setState(() => _selectedCategory = label);
            _reloadForCategory();
          },
        ),
      ),
    );
  }
}