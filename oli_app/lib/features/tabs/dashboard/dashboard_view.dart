
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_controller.dart';
import '../../../models/product_model.dart';
import '../../marketplace/presentation/pages/product_details_page.dart'; // For navigation if needed
import '../dashboard/providers/shops_provider.dart';
import '../../marketplace/providers/market_provider.dart';
import '../../marketplace/presentation/pages/market_view.dart';
import 'widgets/ads_carousel.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/quick_actions_row.dart';
import 'widgets/category_glass_section.dart';
import 'widgets/verified_shops_carousel.dart';
import 'widgets/super_offers_section.dart';
import 'widgets/discovery_carousel.dart';
import 'widgets/product_sections.dart';

class MainDashboardView extends ConsumerStatefulWidget {
  const MainDashboardView({super.key});

  @override
  ConsumerState<MainDashboardView> createState() => _MainDashboardViewState();
}

class _MainDashboardViewState extends ConsumerState<MainDashboardView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = "Tout";
  bool _showCategories = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Les produits mis en avant ne sont pas filtrables"))
    );
  }

  void _onCategorySelected(String label) {
    // Navigate to MarketView with selected category
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarketView(initialCategoryLabel: label),
      ),
    );
  }

  void _toggleCategories() {
    setState(() {
      _showCategories = !_showCategories;
    });
  }

  void _navigateToProduct(Product product) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)));
  }

  @override
  Widget build(BuildContext context) {
    // 1. Data Providers
    final allProducts = ref.watch(featuredProductsProvider);
    final topSellers = ref.watch(topSellersProvider);
    final verifiedShopsProducts = ref.watch(verifiedShopsProductsProvider);
    final verifiedShopsAsync = ref.watch(verifiedShopsProvider); 
    final verifiedShops = verifiedShopsAsync.valueOrNull ?? [];
    
    // 2. Logic for lists
    final superOffersList = allProducts.take(5).toList();
    final discoveryList = allProducts.length > 5 ? allProducts.skip(5).take(5).toList() : <Product>[];
    final rankingList = allProducts.length > 10 ? allProducts.skip(10).toList() : <Product>[];
    final effectiveRankingList = rankingList.isEmpty && discoveryList.isEmpty ? superOffersList : rankingList;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // 1. APP BAR
          HomeAppBar(
            searchCtrl: _searchCtrl, 
            onSearch: _onSearch,
            allProducts: allProducts,
            verifiedShopsProducts: verifiedShopsProducts,
          ),

          // 2. QUICK ACTIONS
          SliverToBoxAdapter(
            child: QuickActionsRow(onCategoryTap: _toggleCategories),
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
            child: SuperOffersSection(products: superOffersList),
          ),

          // 5. ADS
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 160,
              child: SizedBox(
                width: double.infinity,
                height: 160,
                child: AdsCarousel(ads: ref.watch(adsProvider)),
              ),
            ),
          ),

          // 6. DISCOVERY
          const SliverPadding(
             padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             sliver: SliverToBoxAdapter(
               child: Text("Découverte", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
             ),
          ),
          SliverToBoxAdapter(
            child: discoveryList.isEmpty 
              ? const SizedBox.shrink()
              : DiscoveryCarousel(
                  products: discoveryList, 
                  onTap: _navigateToProduct
                ),
          ),

          // 7. BEST SELLERS
          SliverToBoxAdapter(
            child: TopSellersSection(products: topSellers),
          ),

          // 8. VERIFIED SHOP PRODUCTS
          SliverToBoxAdapter(
            child: VerifiedShopProductsSection(products: verifiedShopsProducts),
          ),

          // 9. TOP RANKING
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            sliver: SliverToBoxAdapter(
               child: Text("Top Classement", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
          
          TopRankingGrid(products: effectiveRankingList),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }
}
