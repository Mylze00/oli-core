
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_controller.dart';
import '../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../marketplace/presentation/pages/product_details_page.dart'; // For navigation if needed
import '../dashboard/providers/shops_provider.dart';
import '../../marketplace/providers/market_provider.dart';
import '../../marketplace/presentation/pages/market_view.dart';
import '../../search/providers/search_filters_provider.dart'; // <- Added
import 'widgets/ads_carousel.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/quick_actions_row.dart';
import 'widgets/category_glass_section.dart';
import 'widgets/verified_shops_carousel.dart';
import 'widgets/super_offers_section.dart';
import 'widgets/discovery_carousel.dart';
import 'widgets/product_sections.dart';
import '../../../../app/theme/theme_provider.dart';


class MainDashboardView extends ConsumerStatefulWidget {
  final VoidCallback? onSwitchToMarket;
  final VoidCallback? onBecameVisible;
  
  const MainDashboardView({super.key, this.onSwitchToMarket, this.onBecameVisible});

  @override
  ConsumerState<MainDashboardView> createState() => _MainDashboardViewState();
}

class _MainDashboardViewState extends ConsumerState<MainDashboardView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, String> _categories = {
    "Tout": "",
    "Industrie": "industry",
    "Maison": "home",
    "Véhicules": "vehicles",
    "Mode": "fashion",
    "Électronique": "electronics",
    "Beauté": "beauty",
    "Enfants": "kids",
  };
  String _selectedCategory = "Tout";
  bool _showCategories = false;
  bool _isScrolled = false;

  Timer? _hideCategoriesTimer;
  
  // Lazy loading pour Top Classement
  static const int _rankingBatchSize = 8; // Nombre de produits chargés par batch
  int _rankingLoadedCount = _rankingBatchSize; // Initialement 8 produits visibles
  bool _isLoadingMore = false;

  // Cache pour la distribution des produits (calculé une seule fois)
  String _cachedSelectionKeyword = "";
  List<Product> _cachedSelectionProducts = [];
  List<Product> _cachedSuperOffers = [];
  List<Product> _cachedDiscoveryList = [];
  List<Product> _cachedRankingList = [];
  bool _distributionComputed = false;

  static const List<String> stopWords = ['Paire', 'Lot', 'Set', 'Kit', 'Nouveau', 'Promo', 'Super', 'Pack', 'Mini', 'La', 'Le', 'Les'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (_isLoadingMore) return;
    final offset = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;

    // Glass effect dès 10px de scroll
    final nowScrolled = offset > 10;
    if (nowScrolled != _isScrolled) {
      setState(() => _isScrolled = nowScrolled);
    }

    // Charger plus quand l'utilisateur est à 300px du bas
    if (offset >= maxScroll - 300) {
      _loadMoreRankingProducts();
    }
  }
  
  void _loadMoreRankingProducts() {
    _isLoadingMore = true;
    setState(() {
      _rankingLoadedCount += _rankingBatchSize;
    });
    // Petit délai pour éviter les appels multiples rapides
    Future.delayed(const Duration(milliseconds: 500), () {
      _isLoadingMore = false;
    });
  }
  
  @override
  void didUpdateWidget(MainDashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear search when dashboard becomes visible (callback triggered)
    if (widget.onBecameVisible != oldWidget.onBecameVisible) {
      _searchCtrl.clear();
    }
  }

  @override
  void dispose() {
    _hideCategoriesTimer?.cancel();
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    if (value.trim().isEmpty) return;
    
    // Set the search query in the market provider
    // For now, still use Navigator.push for search since it needs the query parameter
    // MarketView will need to read from a provider instead
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MarketView(initialSearchQuery: value.trim())),
    );
  }

  void _onCategorySelected(String label) {
    _hideCategoriesTimer?.cancel();
    
    // Set the category filter in the provider
    final categoryKey = _categories[label] ?? '';
    ref.read(searchFiltersProvider.notifier).setCategory(categoryKey);
    
    // Switch to the Market tab instead of pushing a new page
    if (widget.onSwitchToMarket != null) {
      widget.onSwitchToMarket!();
    } else {
      // Fallback: push if callback not provided (shouldn't happen)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MarketView(initialCategoryLabel: label),
        ),
      );
    }
  }

  void _toggleCategories() {
    setState(() {
      _showCategories = !_showCategories;
    });

    if (_showCategories) {
      _startCategoryTimer();
    } else {
      _hideCategoriesTimer?.cancel();
    }
  }

  void _startCategoryTimer() {
    _hideCategoriesTimer?.cancel(); // Toujours annuler avant de recréer
    _hideCategoriesTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _showCategories) {
        setState(() => _showCategories = false);
      }
    });
  }

  /// Calcule la distribution des produits UNE SEULE FOIS
  void _computeProductDistribution(List<Product> allProducts) {
    _cachedSelectionKeyword = "";
    _cachedSelectionProducts = [];

    final Map<String, List<Product>> groupedProducts = {};
    
    for (var product in allProducts) {
      final words = product.name.split(' ');
      String focusKW = words.isNotEmpty ? words.first : "";
      
      if (words.length > 1 && (focusKW.length <= 2 || stopWords.contains(focusKW))) {
        focusKW = words[1];
      }
      
      focusKW = focusKW.replaceAll(RegExp(r'[^\w\s]+'), '');

      if (focusKW.length > 2) {
         focusKW = focusKW[0].toUpperCase() + focusKW.substring(1).toLowerCase();
         if (!groupedProducts.containsKey(focusKW)) {
           groupedProducts[focusKW] = [];
         }
         groupedProducts[focusKW]!.add(product);
      }
    }

    final validKeys = groupedProducts.keys.where((k) => groupedProducts[k]!.length >= 5).toList();

    if (validKeys.isNotEmpty) {
      validKeys.shuffle();
      _cachedSelectionKeyword = validKeys.first;
      _cachedSelectionProducts = groupedProducts[_cachedSelectionKeyword]!.take(15).toList();
    }

    final remainingProducts = allProducts.where((p) => !_cachedSelectionProducts.contains(p)).toList();
    _cachedSuperOffers = remainingProducts.take(5).toList();
    _cachedDiscoveryList = remainingProducts.length > 5 
        ? remainingProducts.skip(5).take(5).toList() 
        : <Product>[];
    _cachedRankingList = remainingProducts.length > 10 
        ? remainingProducts.skip(10).toList() 
        : <Product>[];
    _cachedRankingList.sort((a, b) => a.name.compareTo(b.name));

    _distributionComputed = true;
  }

  void _navigateToProduct(Product product) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)));
  }

  @override
  Widget build(BuildContext context) {
    // 0. Theme
    final isDark = ref.watch(themeProvider);
    final backgroundColor = isDark ? Colors.black : Colors.grey[400];
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white.withOpacity(0.7) : Colors.black87;

    // 1. Data Providers
    final featuredProductsAsync = ref.watch(featuredProductsProvider);
    final allProducts = featuredProductsAsync; // Pour l'affichage page d'accueil
    
    // IMPORTANT: Pour la recherche, utiliser TOUS les produits de la marketplace
    final allProductsForSearchAsync = ref.watch(marketProductsProvider);
    final allProductsForSearch = allProductsForSearchAsync.valueOrNull ?? [];
    
    final topSellers = ref.watch(topSellersProvider);
    final verifiedShopsProducts = ref.watch(verifiedShopsProductsProvider);
    final verifiedShopsAsync = ref.watch(verifiedShopsProvider); 
    final verifiedShops = verifiedShopsAsync.valueOrNull ?? [];
    
    // 2. Calcul de la distribution UNE SEULE FOIS (stable entre les rebuilds)
    if (!_distributionComputed && allProducts.isNotEmpty) {
      _computeProductDistribution(allProducts);
    }

    final fullRankingList = _cachedRankingList.isNotEmpty 
        ? _cachedRankingList 
        : (_cachedDiscoveryList.isNotEmpty ? _cachedDiscoveryList : _cachedSuperOffers);
    
    // Lazy loading : limiter les produits affichés dans le ranking
    final effectiveRankingList = fullRankingList.take(_rankingLoadedCount).toList();
    final hasMoreRanking = fullRankingList.length > _rankingLoadedCount;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          // Recharger les produits
          await ref.read(featuredProductsProvider.notifier).fetchFeaturedProducts();
          // Réinitialiser le lazy loading ET la distribution
          setState(() {
            _rankingLoadedCount = _rankingBatchSize;
            _distributionComputed = false;
          });
        },
        child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. APP BAR
          HomeAppBar(
            searchCtrl: _searchCtrl,
            onSearch: _onSearch,
            allProducts: allProductsForSearch,
            verifiedShopsProducts: verifiedShopsProducts,
            isScrolled: _isScrolled,
          ),

          // 2. QUICK ACTIONS (épinglé au scroll)
          SliverPersistentHeader(
            pinned: true,
            delegate: _QuickActionsDelegate(
              child: QuickActionsRow(onCategoryTap: _toggleCategories),
              backgroundColor: backgroundColor ?? Colors.black,
              isScrolled: _isScrolled,
            ),
          ),
          
          // 2b. CATEGORIES (SLIDE DOWN ANIMATION)
          SliverToBoxAdapter(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _showCategories
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: CategoryGlassSection(
                        selectedCategory: _selectedCategory,
                        onCategorySelected: _onCategorySelected,
                        categories: _categories,
                      ),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ),

          // 3. VERIFIED SHOPS CAROUSEL
          SliverToBoxAdapter(
            child: VerifiedShopsCarousel(shops: verifiedShops),
          ),

          // 4. SUPER OFFERS
          SliverToBoxAdapter(
            child: SuperOffersSection(products: _cachedSuperOffers),
          ),

          // 5. ADS
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 221, // +15%
              child: SizedBox(
                width: double.infinity,
                height: 221, // +15%
                child: AdsCarousel(ads: ref.watch(adsProvider)),
              ),
            ),
          ),

          // 6. RANDOM CATEGORY SECTION (STRICT KEYWORD)
          if (_cachedSelectionProducts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildHorizontalSection(
                  title: "Sélection : $_cachedSelectionKeyword",
                  subtitle: "Inspiration pour vous",
                  products: _cachedSelectionProducts,
                  gradient: null, // Transparent background
                  badgeText: "NEW",
                  badgeColor: Colors.tealAccent.shade700,
                ),
              ),
            ),

          // 7. DISCOVERY
          SliverPadding(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             sliver: SliverToBoxAdapter(
               child: Text("Découverte", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
             ),
          ),
          SliverToBoxAdapter(
            child: _cachedDiscoveryList.isEmpty 
              ? const SizedBox.shrink()
              : DiscoveryCarousel(
                  products: _cachedDiscoveryList, 
                  onTap: _navigateToProduct
                ),
          ),

          // 7. BEST SELLERS
          // 7. BEST SELLERS (Masqué temporairement)
          // SliverToBoxAdapter(
          //   child: TopSellersSection(products: topSellers),
          // ),

          // 8. VERIFIED SHOP PRODUCTS
          SliverToBoxAdapter(
            child: VerifiedShopProductsSection(products: verifiedShopsProducts),
          ),

          // 9. TOP RANKING

          
          // 9. TOP RANKING (Patron répétitif : 6 produits (3 cols) -> 2 produits (2 cols))
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            sliver: SliverToBoxAdapter(
               child: Text("Top Classement", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
          
          ..._buildPatternedRankingGrid(effectiveRankingList, textColor),
          
          // Indicateur de chargement si plus de produits disponibles
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
    );
  }

  /// Messages promotionnels rotatifs avec couleurs et tailles uniques
  static const List<Map<String, dynamic>> _promoMessages = [
    {
      'title': 'Guérite Oli 🏪',
      'text': 'Achetez et récupérez vos commandes dans le guérite Oli de votre supermarché',
      'gradient1': Color(0xFF4A0E8F),
      'gradient2': Color(0xFF2D0A5E),
      'paddingV': 20.0,
      'titleSize': 17.0,
      'textSize': 13.0,
    },
    {
      'title': 'Meilleurs Prix 💰',
      'text': 'Achetez au meilleur prix avec Oli, livraison rapide garantie',
      'gradient1': Color(0xFF0D7377),
      'gradient2': Color(0xFF14463A),
      'paddingV': 12.0,
      'titleSize': 14.0,
      'textSize': 11.0,
    },
    {
      'title': 'Vendez sur Oli 🚀',
      'text': 'Profitez des avantages en vendant sur Oli, commencez gratuitement',
      'gradient1': Color(0xFFD84315),
      'gradient2': Color(0xFF8F2B00),
      'paddingV': 32.0,
      'titleSize': 22.0,
      'textSize': 15.0,
    },
  ];

  /// Construit la liste de Slivers pour le Top Ranking avec le motif 3-3-2
  List<Widget> _buildPatternedRankingGrid(List<Product> allProducts, Color textColor) {
    List<Widget> slivers = [];
    int index = 0;
    int promoIndex = 0;
    
    // Boucle tant qu'il reste des produits
    while (index < allProducts.length) {
      // 1. Prendre 6 produits pour la grille 3 colonnes
      int take3Cols = 6;
      final chunk3Cols = allProducts.skip(index).take(take3Cols).toList();
      if (chunk3Cols.isNotEmpty) {
        slivers.add(
          TopRankingGrid(
            products: chunk3Cols,
            crossAxisCount: 3,
            childAspectRatio: 0.75,
          )
        );
        index += chunk3Cols.length;
      }

      // 2. Prendre 2 produits pour la grille 2 colonnes (si dispo)
      if (index < allProducts.length) {
        int take2Cols = 2;
        final chunk2Cols = allProducts.skip(index).take(take2Cols).toList();
        if (chunk2Cols.isNotEmpty) {
                    
          // Generate a context title based on the first product's name (first word)
          if (chunk2Cols.isNotEmpty) {
             final firstProduct = chunk2Cols.first;
             final words = firstProduct.name.split(' ');
             String focusWord = words.isNotEmpty ? words.first : "";

             // Utiliser la liste de stop words définie dans la classe
             if (words.length > 1 && (focusWord.length <= 2 || stopWords.contains(focusWord))) {
                focusWord = words[1];
             }

             if (focusWord.length > 2) {
                slivers.add(
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Container(width: 4, height: 16, color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          Text(
                            "Focus : $focusWord", 
                            style: TextStyle(
                              color: textColor.withOpacity(0.9), 
                              fontWeight: FontWeight.bold, 
                              fontSize: 14
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                );
             }
          }

          slivers.add(
             // Un peu d'espace entre les sections de grille
             const SliverPadding(padding: EdgeInsets.only(top: 8))
          );
          slivers.add(
            TopRankingGrid(
              products: chunk2Cols,
              crossAxisCount: 2,
              childAspectRatio: 0.85, // Plus haut (+25%) pour 2 colonnes
            )
          );
          slivers.add(
             const SliverPadding(padding: EdgeInsets.only(top: 8))
          );
          index += chunk2Cols.length;
        }
      }

      // 3. Bannière promotionnelle après chaque cycle de 8 produits
      final promo = _promoMessages[promoIndex % _promoMessages.length];
      final Color grad1 = promo['gradient1'] as Color;
      final Color grad2 = promo['gradient2'] as Color;
      final double padV = promo['paddingV'] as double;
      final double tSize = promo['titleSize'] as double;
      final double dSize = promo['textSize'] as double;
      promoIndex++;
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: padV),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [grad1, grad2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: grad1.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo['title'] as String,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: tSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  promo['text'] as String,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: dSize,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return slivers;
  }

  /// Section horizontale réutilisable (copiée de MarketView pour usage local)
  Widget _buildHorizontalSection({
    required String title,
    required String subtitle,
    required List<Product> products,
    List<Color>? gradient,
    required String badgeText,
    required Color badgeColor,
  }) {
    // Local theme logic (since this method is inside the class)
    // Ideally pass it as param or check theme here too, but let's check provider again or assume dark for cards if not passed?
    // Actually we need to make sure the TITLE of the section adapts. 
    // BUT the section logic inside uses "Colors.white" for titles.
    // We should fix this method to respect the background. Use Consumer or pass color.
    // The easiest is to use a Consumer here or just access the values if passed.
    // Let's assume we want to use the method as is but change the text color.
    // However, this method is inside the State class so we can access ref if we change to ConsumerState logic properly
    // Check if we can access 'textColor' from the build context logic? No, it's a helper method.
    // Let's refactor the helper to take textColor or use a default.
    // For now, I'll modify the usages to pass it or just use a hack since I closed the build method signature.
    // Wait, I can't change signature easily without changing all callers.
    // Callers: 
    // 1. Random Section (line 214) -> does not pass color
    // 2. Others commented out?
    // Let's change signature to accept textColor, optional.

    return Consumer(
      builder: (context, ref, _) {
       final isDark = ref.watch(themeProvider);
       final sectionTitleColor = isDark ? Colors.white : Colors.black;
       final sectionSubtitleColor = isDark ? Colors.white.withOpacity(0.7) : Colors.black54;

       return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: gradient != null ? LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          color: gradient == null ? Colors.transparent : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: sectionTitleColor, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: sectionSubtitleColor, fontSize: 11)),
                  ],
                ),
                Icon(Icons.arrow_forward_ios, color: sectionTitleColor, size: 14),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return GestureDetector(
                    onTap: () => _navigateToProduct(product),
                    child: Container(
                      width: 110,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C), // Cards always dark for now
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                  child: product.images.isNotEmpty 
                                    ? Image.network(product.images.first, fit: BoxFit.cover, width: double.infinity)
                                    : const Center(child: Icon(Icons.image, color: Colors.grey)),
                                ),
                                Positioned(
                                  top: 0, left: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10)),
                                Consumer(
                                  builder: (context, ref, _) {
                                    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
                                    ref.watch(exchangeRateProvider); // React to currency changes
                                    return Text(
                                      exchangeNotifier.formatProductPrice(double.tryParse(product.price) ?? 0.0), 
                                      style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)
                                    );
                                  }
                                ),
                              ],
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
    );
  }
}

/// Delegate pour épingler la QuickActionsRow lors du scroll
class _QuickActionsDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color backgroundColor;
  final bool isScrolled;
  const _QuickActionsDelegate({
    required this.child,
    required this.backgroundColor,
    this.isScrolled = false,
  });

  @override
  double get minExtent => 90.0;
  @override
  double get maxExtent => 90.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Fond : glass ou solide selon le scroll
        if (isScrolled)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: backgroundColor.withOpacity(0.60),
              ),
            ),
          )
        else
          ColoredBox(color: backgroundColor),
        // 2. Icônes toujours visibles par-dessus
        AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: 1.0,
          child: child,
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_QuickActionsDelegate oldDelegate) =>
      oldDelegate.child != child ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.isScrolled != isScrolled;
}
