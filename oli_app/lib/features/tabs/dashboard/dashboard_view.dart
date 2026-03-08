import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../marketplace/presentation/pages/product_details_page.dart';
import '../../marketplace/presentation/pages/market_view.dart';
import '../../marketplace/presentation/pages/category_products_page.dart';
import '../../marketplace/providers/market_provider.dart';
import '../../search/providers/search_filters_provider.dart';
import '../dashboard/providers/shops_provider.dart';
import '../../../models/product_model.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../widgets/oli_refresh_indicator.dart';

// Widgets de la section dashboard
import 'widgets/ads_carousel.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/quick_actions_row.dart';
import 'widgets/quick_actions_delegate.dart';
import 'widgets/category_glass_section.dart';
import 'widgets/verified_shops_carousel.dart';
import 'widgets/super_offers_section.dart';
import 'widgets/discovery_carousel.dart';
import 'widgets/horizontal_product_section.dart';
import 'widgets/product_sections.dart'; // VerifiedShopProductsSection
import 'widgets/ranking_section.dart';
import '../../marketplace/presentation/widgets/market_product_card.dart';

// Logique métier extraite
import 'dashboard_product_distribution.dart';


class MainDashboardView extends ConsumerStatefulWidget {
  final VoidCallback? onSwitchToMarket;
  final VoidCallback? onBecameVisible;

  const MainDashboardView({
    super.key,
    this.onSwitchToMarket,
    this.onBecameVisible,
  });

  @override
  ConsumerState<MainDashboardView> createState() => MainDashboardViewState();
}

class MainDashboardViewState extends ConsumerState<MainDashboardView>
    with SingleTickerProviderStateMixin, DashboardProductDistribution {

  // ── Contrôleurs ──────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ── Catégories ───────────────────────────────────────────────────────────
  final Map<String, String> _categories = {
    'Tout': '', 'Industrie': 'industry', 'Maison': 'home',
    'Véhicules': 'vehicles', 'Mode': 'fashion', 'Électronique': 'electronics',
    'Sports': 'sports', 'Beauté': 'beauty', 'Jouets': 'toys',
    'Santé': 'health', 'Construction': 'construction', 'Outils': 'tools',
    'Bureau': 'office', 'Jardin': 'garden', 'Animaux': 'pets',
    'Bébé': 'baby', 'Alimentation': 'food', 'Sécurité': 'security',
    'Autres': 'other',
  };
  bool _showCategories = false;
  bool _isScrolled = false;
  Timer? _hideCategoriesTimer;

  // ── Animation catégories ─────────────────────────────────────────────────
  late AnimationController _categoryAnimController;
  late Animation<Offset> _categorySlideAnimation;
  late Animation<double> _categoryFadeAnimation;

  static const int _rankingMaxCount  = 64;

  // ── Lazy loading 5 sections anonymes ───────────────────────────────
  static const int _anonSectionCount = 5;
  static const int _anonSectionSize  = 500;  // produits max par section (total 2500)
  static const int _anonBatchSize    = 16;   // produits chargés par scroll
  int _anonLoadedCount = 16;                  // total produits révélés — démarre à 16 pour afficher le 1er batch

  // ────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _categoryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _categorySlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _categoryAnimController,
      curve: Curves.easeOutCubic,
    ));
    _categoryFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _categoryAnimController, curve: Curves.easeOut),
    );
    _categoryAnimController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() => _showCategories = false);
      }
    });
  }

  @override
  void didUpdateWidget(MainDashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onBecameVisible != oldWidget.onBecameVisible) {
      _searchCtrl.clear();
    }
  }

  @override
  void dispose() {
    _hideCategoriesTimer?.cancel();
    _categoryAnimController.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Scroll & Lazy loading
  // ────────────────────────────────────────────────────────────────────────

  void scrollToTop() {
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  void _onScroll() {
    final offset = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;

    final nowScrolled = offset > 10;
    if (nowScrolled != _isScrolled) {
      setState(() => _isScrolled = nowScrolled);
    }
    // Infinite scroll : charger plus produits pour les sections anonymes (le Top Classement est déjà contraint)
    if (offset >= maxScroll - 400) {
      _loadMoreAnonProducts();
    }
  }

  // ── Chargement progressif des 5 sections nommées ─────────────────────
  void _loadMoreAnonProducts() {
    const totalMax = _anonSectionCount * _anonSectionSize;
    if (_anonLoadedCount >= totalMax) return;

    final oliProducts = ref.read(featuredProductsProvider);
    if (oliProducts.isEmpty) return;

    // Nombre de produits disponibles pour les sections (hors Top Classement contraint à _rankingMaxCount)
    final topRankingReserved = oliProducts.length.clamp(0, _rankingMaxCount);
    final availableForAnon = (oliProducts.length - topRankingReserved).clamp(0, oliProducts.length);

    // Demander plus de produits au provider si on s'approche de la fin
    final notifier = ref.read(featuredProductsProvider.notifier);
    if (notifier.hasMore && availableForAnon - _anonLoadedCount < _anonBatchSize * 4) {
      notifier.loadMore();
    }

    // Ne pas dépasser les produits réellement disponibles
    if (availableForAnon <= _anonLoadedCount) return;

    final newCount = (_anonLoadedCount + _anonBatchSize)
        .clamp(0, totalMax.clamp(0, availableForAnon));
    if (newCount > _anonLoadedCount) {
      setState(() => _anonLoadedCount = newCount);
    }
  }

  // ── Grille alternée 3-2 (réutilisable) ──────────────────────────────────
  Widget _buildAlternatingSliver(List<Product> products, double screenWidth) {
    final rows = <List<Product>>[];
    int i = 0;
    bool threeCol = true;
    while (i < products.length) {
      final count = threeCol ? 3 : 2;
      rows.add(products.sublist(i, (i + count).clamp(0, products.length)));
      i += count;
      threeCol = !threeCol;
    }
    const hPad = 12.0;
    const gap  = 4.0;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, idx) {
          final rowProducts = rows[idx];
          final colCount  = rowProducts.length.toDouble();
          final cardWidth = (screenWidth - hPad - gap * (colCount - 1)) / colCount;
          final rowHeight = cardWidth / 0.62;
          return Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
            child: SizedBox(
              height: rowHeight,
              child: Row(
                children: rowProducts.map((p) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () => _navigateToProduct(p),
                      child: MarketProductCard(product: p),
                    ),
                  ),
                )).toList(),
              ),
            ),
          );
        },
        childCount: rows.length,
      ),
    );
  }

  /// Layout 6-2-3 : première ligne de 6 petits produits,
  /// puis alternance lignes de 2 et 3 produits
  Widget _buildSection6x2x3Sliver(List<Product> products, double screenWidth) {
    if (products.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    const hPad = 12.0;
    const gap = 4.0;

    // ── Ligne 1 : 4 petits produits ──
    final firstRowProducts = products.take(4).toList();
    final remainingProducts = products.skip(4).toList();

    // ── Lignes suivantes : alternance 2-3 ──
    final rows = <List<Product>>[];
    int i = 0;
    bool twoCol = true;
    while (i < remainingProducts.length) {
      final count = twoCol ? 2 : 3;
      rows.add(remainingProducts.sublist(
          i, (i + count).clamp(0, remainingProducts.length)));
      i += count;
      twoCol = !twoCol;
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, idx) {
          // Index 0 = première ligne de 6 petits produits
          if (idx == 0) {
            final colCount = firstRowProducts.length.toDouble();
            final cardWidth =
                (screenWidth - hPad - gap * (colCount - 1)) / colCount;
            final rowHeight = cardWidth / 0.55; // Plus compact pour 6 colonnes
            return Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
              child: SizedBox(
                height: rowHeight,
                child: Row(
                  children: firstRowProducts
                      .map((p) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 1),
                              child: GestureDetector(
                                onTap: () => _navigateToProduct(p),
                                child: MarketProductCard(
                                  product: p,
                                  isCompact: true,
                                  hideSellerOverlay: true,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            );
          }

          // Index 1+ = lignes alternées 2-3
          final rowIdx = idx - 1;
          if (rowIdx >= rows.length) return const SizedBox.shrink();

          final rowProducts = rows[rowIdx];
          final colCount = rowProducts.length.toDouble();
          final cardWidth =
              (screenWidth - hPad - gap * (colCount - 1)) / colCount;
          final rowHeight = cardWidth / 0.62;
          return Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
            child: SizedBox(
              height: rowHeight,
              child: Row(
                children: rowProducts
                    .map((p) => Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2),
                            child: GestureDetector(
                              onTap: () => _navigateToProduct(p),
                              child: MarketProductCard(
                                product: p,
                                hideSellerOverlay: true,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          );
        },
        childCount: 1 + rows.length, // 1 ligne de 6 + N lignes 2-3
      ),
    );
  }

  void _navigateToProduct(Product product) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)));
  }

  void _onSearch(String value) {
    if (value.trim().isEmpty) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => MarketView(initialSearchQuery: value.trim())));
  }

  void _onCategorySelected(String label) {
    _hideCategoriesTimer?.cancel();
    const categoryIcons = <String, IconData>{
      'Industrie': Icons.factory, 'Maison': Icons.chair,
      'Véhicules': Icons.directions_car, 'Mode': Icons.checkroom,
      'Électronique': Icons.phone_android, 'Sports': Icons.sports_soccer,
      'Beauté': Icons.face, 'Jouets': Icons.toys,
      'Santé': Icons.medical_services, 'Construction': Icons.construction,
      'Outils': Icons.build, 'Bureau': Icons.desk,
      'Jardin': Icons.grass, 'Animaux': Icons.pets,
      'Bébé': Icons.child_friendly, 'Alimentation': Icons.restaurant,
      'Sécurité': Icons.security, 'Autres': Icons.category,
    };

    // ── Filtrer les produits OLI admin par catégorie sélectionnée ──
    final categoryKey = _categories[label] ?? '';
    final oliFiltered = categoryKey.isEmpty
        ? <Product>[]
        : ref.read(featuredProductsProvider).where((p) {
            return (p.category ?? '') == categoryKey;
          }).toList();

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CategoryProductsPage(
        categoryKey: categoryKey,
        categoryLabel: label,
        categoryIcon: categoryIcons[label],
        oliProducts: oliFiltered,
      ),
    ));
  }

  void _toggleCategories() {
    if (_showCategories) {
      _hideCategoriesTimer?.cancel();
      _categoryAnimController.reverse();
    } else {
      setState(() => _showCategories = true);
      _categoryAnimController.forward();
      _resetCategoryTimer();
    }
  }

  /// Réinitialise le timer d'auto-masquage des icônes de catégorie (7 secondes).
  /// Appelé à chaque sélection de catégorie pour garder le panneau visible.
  void _resetCategoryTimer() {
    _hideCategoriesTimer?.cancel();
    _hideCategoriesTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && _showCategories) _categoryAnimController.reverse();
    });
  }

  // ────────────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final backgroundColor = isDark ? Colors.black : const Color(0xFFD9D9D9);
    final textColor = isDark ? Colors.white : Colors.black87;

    // Providers de données
    final allProducts = ref.watch(featuredProductsProvider);         // produits admin OLI
    final allProductsForSearch =
        ref.watch(marketProductsProvider).valueOrNull ?? [];         // tous les produits (recherche)
    final topSellers = ref.watch(topSellersProvider);
    final verifiedShopsProducts = ref.watch(verifiedShopsProductsProvider);
    final verifiedShops = ref.watch(verifiedShopsProvider).valueOrNull ?? [];
    final brandedProducts = ref.watch(brandedProductsProvider);      // produits Original (brand_certified)

    // Déclencher la distribution avec setState quand les produits arrivent
    // ref.listen garantit un rebuild propre après l'appel asynchrone du provider
    ref.listen<List<Product>>(featuredProductsProvider, (prev, next) {
      if (next.isNotEmpty && !distributionComputed && mounted) {
        setState(() {
          computeProductDistribution(next);
        });
      }
    });

    // Safeguard synchrone : si les produits sont déjà là au 1er build
    if (!distributionComputed && allProducts.isNotEmpty) {
      computeProductDistribution(allProducts);
    }

    // Top Classement (statiquement limité à _rankingMaxCount pour éviter le glitch d'entrelacement au défilement)
    final fullRankingList =
        cachedRankingList.isNotEmpty ? cachedRankingList : cachedSuperOffers;
    
    // effectiveRankingList prend directement le max pour profiter du virtual scroll natif de SliverGrid
    final effectiveRankingListLength = fullRankingList.length.clamp(0, _rankingMaxCount);
    final effectiveRankingList =
        fullRankingList.take(effectiveRankingListLength).toList();
        
    final featuredNotifier = ref.read(featuredProductsProvider.notifier);
    
    // Produits OLI restants (non affichés dans Top Classement)
    // → alimentent directement les 5 sections nommées
    final shownIds = effectiveRankingList.map((p) => p.id).toSet();
    final anonOliProducts =
        allProducts.where((p) => !shownIds.contains(p.id)).toList();

    // Produits pour la section circulaire "À la une" — endpoint dédié /products/branded
    final brandedSliceFiltered = brandedProducts.take(12).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // ── Contenu principal scrollable ──
          OliRefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(featuredProductsProvider.notifier)
                  .fetchFeaturedProducts();
              setState(() {
                _anonLoadedCount = _anonBatchSize;
                resetDistribution();
              });
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // 1. App Bar
                HomeAppBar(
                  searchCtrl: _searchCtrl,
                  onSearch: _onSearch,
                  allProducts: allProductsForSearch,
                  verifiedShopsProducts: verifiedShopsProducts,
                  isScrolled: _isScrolled,
                ),

                // 2. Quick Actions (épinglée)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: QuickActionsDelegate(
                    child: QuickActionsRow(onCategoryTap: _toggleCategories),
                    backgroundColor: backgroundColor ?? Colors.black,
                    isScrolled: _isScrolled,
                  ),
                ),

                // 3. Boutiques vérifiées
                SliverToBoxAdapter(
                  child: VerifiedShopsCarousel(shops: verifiedShops),
                ),

                // 4. Super Offres (top sellers)
                SliverToBoxAdapter(
                  child: SuperOffersSection(
                      products: topSellers.take(10).toList()),
                ),

                // 5. Publicités
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    height: 221,
                    child: AdsCarousel(ads: ref.watch(adsProvider)),
                  ),
                ),

                // 6. Sélection par mot-clé (produits admin groupés)
                if (cachedSelectionProducts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: HorizontalProductSection(
                        title: 'Sélection : $cachedSelectionKeyword',
                        subtitle: 'Inspiration pour vous',
                        products: cachedSelectionProducts,
                        badgeText: 'NEW',
                        badgeColor: Colors.tealAccent.shade700,
                        searchKeyword: cachedSelectionKeyword,
                        onProductTap: _navigateToProduct,
                      ),
                    ),
                  ),

                // 7. Découverte (5 produits admin aléatoires)
                if (cachedDiscoveryList.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Découverte',
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: DiscoveryCarousel(
                        products: cachedDiscoveryList,
                        onTap: _navigateToProduct),
                  ),
                ],

                // 8. Grands Magasins (boutiques certifiées)
                SliverToBoxAdapter(
                  child:
                      VerifiedShopProductsSection(products: verifiedShopsProducts),
                ),

                // 9. Section "À la une" — produits Original (brandCertified)
                if (brandedSliceFiltered.isNotEmpty)
                  SliverToBoxAdapter(
                    child: BrandedCircleSection(products: brandedSliceFiltered),
                  ),

                // 10. Top Classement (tous les produits admin)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  sliver: SliverToBoxAdapter(
                    child: Text('Top Classement',
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ),
                ),

                ...RankingSectionHelper.buildSlivers(
                    effectiveRankingList, textColor),

                const SliverPadding(padding: EdgeInsets.only(bottom: 16)),

                // ── 5 sections nommées avec layout 6-2-3 ───
                ...List.generate(_anonSectionCount, (s) {
                  const sectionTitles = [
                    'Meilleures choix pour vous',
                    'Tendances du moment',
                    'Récemment ajoutés',
                    'Les mieux notés',
                    'À ne pas manquer',
                  ];
                  const sectionIcons = [
                    Icons.star_rounded,
                    Icons.trending_up_rounded,
                    Icons.schedule_rounded,
                    Icons.thumb_up_rounded,
                    Icons.local_fire_department_rounded,
                  ];

                  final start = s * _anonSectionSize;
                  if (_anonLoadedCount <= start) return const <Widget>[];

                  final countForSection =
                      (_anonLoadedCount - start).clamp(0, _anonSectionSize);
                  final sectionProducts = anonOliProducts
                      .skip(start)
                      .take(countForSection)
                      .toList();
                  if (sectionProducts.isEmpty) return const <Widget>[];

                  final sw = MediaQuery.of(context).size.width;
                  return [
                    // Titre de la section
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Icon(sectionIcons[s], color: textColor, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              sectionTitles[s],
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Grille 6-2-3
                    _buildSection6x2x3Sliver(sectionProducts, sw),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 4)),
                  ];
                }).expand((x) => x),

                const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
              ],
            ),
          ),

          // ── Overlay catégories (coulissant) ──
          if (_showCategories) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleCategories,
                child: FadeTransition(
                  opacity: _categoryFadeAnimation,
                  child:
                      Container(color: Colors.black.withOpacity(0.3)),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  kToolbarHeight +
                  60 +
                  90,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _categorySlideAnimation,
                child: FadeTransition(
                  opacity: _categoryFadeAnimation,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(16)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.60)
                              : Colors.white.withOpacity(0.90),
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16)),
                          border: Border(
                            bottom: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.08),
                                width: 1),
                          ),
                        ),
                        padding:
                            const EdgeInsets.only(top: 8, bottom: 12),
                        child: CategoryGlassSection(
                          selectedCategory: 'Tout',
                          onCategorySelected: (label) {
                            // Garder les icônes visibles et réinitialiser le timer
                            _resetCategoryTimer();
                            _onCategorySelected(label);
                          },
                          categories: _categories,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
