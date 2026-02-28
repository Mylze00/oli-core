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

  // ── Lazy loading Top Classement ──────────────────────────────────────────
  static const int _rankingBatchSize = 8;
  int _rankingLoadedCount = _rankingBatchSize;
  bool _isLoadingMore = false;

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
    if (_isLoadingMore) return;
    final offset = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;

    final nowScrolled = offset > 10;
    if (nowScrolled != _isScrolled) {
      setState(() => _isScrolled = nowScrolled);
    }
    // Infinite scroll : charger plus de produits featured + ranking
    if (offset >= maxScroll - 400) {
      _loadMoreRankingProducts();
      // Charger de nouveaux produits featured (30 par batch)
      ref.read(featuredProductsProvider.notifier).loadMore();
    }
  }

  void _loadMoreRankingProducts() {
    _isLoadingMore = true;
    setState(() => _rankingLoadedCount += _rankingBatchSize);
    Future.delayed(const Duration(milliseconds: 500), () {
      _isLoadingMore = false;
    });
  }

  // ────────────────────────────────────────────────────────────────────────
  // Navigation
  // ────────────────────────────────────────────────────────────────────────

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
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CategoryProductsPage(
        categoryKey: _categories[label] ?? '',
        categoryLabel: label,
        categoryIcon: categoryIcons[label],
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
      _hideCategoriesTimer?.cancel();
      _hideCategoriesTimer = Timer(const Duration(seconds: 6), () {
        if (mounted && _showCategories) _categoryAnimController.reverse();
      });
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final backgroundColor = isDark ? Colors.black : Colors.grey[400];
    final textColor = isDark ? Colors.white : Colors.black;

    // Providers de données
    final allProducts = ref.watch(featuredProductsProvider);         // produits admin OLI
    final allProductsForSearch =
        ref.watch(marketProductsProvider).valueOrNull ?? [];         // tous les produits (recherche)
    final topSellers = ref.watch(topSellersProvider);
    final verifiedShopsProducts = ref.watch(verifiedShopsProductsProvider);
    final verifiedShops = ref.watch(verifiedShopsProvider).valueOrNull ?? [];

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

    // Top Classement (jamais vide tant que l'admin a des produits)
    final fullRankingList =
        cachedRankingList.isNotEmpty ? cachedRankingList : cachedSuperOffers;
    final effectiveRankingList =
        fullRankingList.take(_rankingLoadedCount).toList();
    final hasMoreRanking = fullRankingList.length > _rankingLoadedCount;

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
                _rankingLoadedCount = _rankingBatchSize;
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

                // 9. Top Classement (tous les produits admin)
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

                // Indicateur de chargement lazy
                if (hasMoreRanking)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: textColor.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ),

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
                          color: Colors.black.withOpacity(0.60),
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16)),
                          border: Border(
                            bottom: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                                width: 1),
                          ),
                        ),
                        padding:
                            const EdgeInsets.only(top: 8, bottom: 12),
                        child: CategoryGlassSection(
                          selectedCategory: 'Tout',
                          onCategorySelected: (label) {
                            _onCategorySelected(label);
                            _categoryAnimController.reverse();
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
