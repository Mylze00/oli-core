import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_controller.dart';
import '../../../config/api_config.dart';
import '../../../models/product_model.dart';
import '../../notifications/screens/notifications_view.dart';
import '../../marketplace/presentation/pages/product_details_page.dart';
import '../../marketplace/presentation/widgets/market_product_card.dart';
import '../../services/request_product_page.dart';
import '../../services/services_page.dart';
import '../../services/miniapps_page.dart';
import '../../services/live_shopping_page.dart';
import '../../shop/shop_details_page.dart';
import '../dashboard/providers/shops_provider.dart';
import '../../../models/shop_model.dart';
import '../../../widgets/auto_refresh_avatar.dart';
import '../../marketplace/providers/market_provider.dart';
import 'widgets/dynamic_search_bar.dart';
import 'widgets/ads_carousel.dart';
import 'widgets/bon_deals_grid.dart';

import '../../marketplace/presentation/pages/all_categories_page.dart';

class MainDashboardView extends ConsumerStatefulWidget {
  const MainDashboardView({super.key});

  @override
  ConsumerState<MainDashboardView> createState() => _MainDashboardViewState();
}

class _MainDashboardViewState extends ConsumerState<MainDashboardView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = "Tout";

  // Mapping Labels UI -> Filtres API (si applicable)
  // "Tout" envoie string vide ou null
  final Map<String, String> _categories = {
    "Tout": "",
    "Industrie": "industry",
    "Maison": "home",
    "Véhicules": "vehicles",
    "Mode": "fashion",
    "Électronique": "electronics",
  };

  void _onSearch(String value) {
    // Featured products ne sont pas filtrables - ce sont des produits mis en avant par l'admin
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Les produits mis en avant ne sont pas filtrables"))
    );
  }

  void _onCategorySelected(String label) {
    setState(() => _selectedCategory = label);
    // Featured products ne sont pas filtrables par catégorie
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Utilisez l'onglet Marché pour filtrer par catégorie"))
    );
  }

  void _navigateToProduct(Product product) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)));
  }

  @override
  Widget build(BuildContext context) {
    // ✨ Produits admin (featured)
    // ✨ Produits admin (featured)
    final allProducts = ref.watch(featuredProductsProvider);
    
    // Découpage pour éviter les doublons (5 pour Super Offres, 5 pour Découverte, le reste pour Top)
    // Si pas assez de produits, on gère les cas limites
    final superOffersList = allProducts.take(5).toList();
    final discoveryList = allProducts.length > 5 ? allProducts.skip(5).take(5).toList() : <Product>[];
    final rankingList = allProducts.length > 10 ? allProducts.skip(10).toList() : <Product>[];

    // Si vraiment peu de produits (<5), on affiche quand même en Top Classement pour ne pas faire vide
    final effectiveRankingList = rankingList.isEmpty && discoveryList.isEmpty ? superOffersList : rankingList;
    // ⭐ Meilleurs vendeurs du marketplace
    final topSellers = ref.watch(topSellersProvider);
    // 🏪 Produits des grands magasins vérifiés
    final verifiedShopsProducts = ref.watch(verifiedShopsProductsProvider);
    final verifiedShopsAsync = ref.watch(verifiedShopsProvider); 
    final verifiedShops = verifiedShopsAsync.valueOrNull ?? []; // ✨ Boutiques vérifiées (Carousel)
    final verifiedShops = verifiedShopsAsync.valueOrNull ?? []; // ✨ Boutiques vérifiées (Carousel)
    final authState = ref.watch(authControllerProvider);
    
    // 🔥 Bons Deals (Aléatoires & Sans Doublons)
    final rawGoodDeals = ref.watch(goodDealsProvider);
    final displayedIds = allProducts.map((p) => p.id).toSet();
    final filteredGoodDeals = rawGoodDeals
        .where((p) => !displayedIds.contains(p.id))
        .take(3)
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // 1. APP BAR AVEC HEADER PERSONNALISÉ & RECHERCHE
          SliverAppBar(
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue, Colors.black],
                ),
              ),
            ),
            floating: true,
            pinned: true,
            elevation: 0,
            // Augmenter la hauteur pour accommoder le Header + SearchBar
            expandedHeight: 120, 
            title: Row(
              children: [
                // Coin Gauche : Avatar + Nom
                AutoRefreshAvatar(
                  avatarUrl: authState.userData?['avatar_url'],
                  size: 32,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    authState.userData?['name'] ?? 'Utilisateur',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Centre : Logo Oli
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 30,
                    ),
                  ),
                ),
                
                // Équilibrer l'espace à droite
                const Spacer(),
                const SizedBox(width: 40), // Placeholder pour actions ou vide
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
                child: DynamicSearchBar(
                  controller: _searchCtrl,
                  onSubmitted: _onSearch,
                  productNames: [
                    ...allProducts.map((p) => p.name),
                    ...verifiedShopsProducts.map((p) => p.name)
                  ].take(10).toList(), // On prend les 10 premiers pour l'anim
                ),
            ),
            actions: [
               IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsView())),
              ),
            ],
          ),

          // 2. BOUTONS D'ACTION RAPIDE (Modification précédente conservée)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // 3. ROW NAVIGATION (5 Items fixe)
                  _buildQuickActionCard("Catégorie", Icons.grid_view, Colors.orange, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AllCategoriesPage()));
                  }),
                  _buildQuickActionCard("Demande", Icons.campaign, Colors.blue, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestProductPage()));
                  }),
                  _buildQuickActionCard("Service", Icons.public, Colors.green, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesPage()));
                  }),
                  _buildQuickActionCard("Mini-app", Icons.apps, Colors.purple, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MiniAppsPage()));
                  }),
                  _buildQuickActionCard("Live", Icons.live_tv, Colors.red, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveShoppingPage()));
                  }),
                ],
              ),
            ),
          ),
          
          // 3. HISTORIQUE ("Continuer à regarder") (Conservé ou déplacé ?)
          // L'utilisateur voulait "une ligne avant super offre".
          // Je vais insérer la "Singing Product Row" ICI, avant "Super offres" mais après l'historique ou à la place ?
          // "avant le widget super offre" -> OK.
          


          // 4. CATEGORY TABS (Conserver)
          SliverToBoxAdapter(
            child: Container(
              height: 50,
              // Marge réduite au strict minimum (2)
              margin: const EdgeInsets.symmetric(vertical: 2), 
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _categories.keys.map((label) {
                  return GestureDetector(
                    onTap: () => _onCategorySelected(label),
                    child: _buildCategoryChip(label, _selectedCategory == label),
                  );
                }).toList(),
              ),
            ),
          ),

          // 3. CAROUSEL BOUTIQUES VÉRIFIÉES (Déplacé ici)
          SliverToBoxAdapter(
            child: verifiedShops.isEmpty
              ? const SizedBox.shrink()
              : Container(
                height: 115, // Ajusté pour cercles 80px
                margin: const EdgeInsets.only(top: 0, bottom: 2), // Marge quasi nulle
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: verifiedShops.length,
                  itemBuilder: (context, index) {
                    final shop = verifiedShops[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopDetailsPage(shop: shop))),
                      child: Container(
                        width: 100, // Augmenté pour éviter de couper
                        margin: const EdgeInsets.only(right: 8), // Réduit l'espace entre les cercles
                        child: Column(
                          children: [
                            Container(
                              width: 80, height: 80, // +10% de plus (Total ~80px)
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.white, width: 2),
                                image: shop.logoUrl != null 
                                   ? DecorationImage(image: NetworkImage(shop.logoUrl!), fit: BoxFit.cover)
                                   : null,
                              ),
                              child: shop.logoUrl == null 
                                  ? Center(child: Text(shop.name[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: Colors.black)))
                                  : null,
                            ),
                            const SizedBox(height: 2), // Espace texte reduit
                            Text(
                              shop.name,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // 5. SECTIONS SPECIALES (Top Deals)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), // Espacement vertical augmenté
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Super Offres 🔥", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Icon(Icons.arrow_forward, color: Colors.grey[400], size: 18),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: superOffersList.isEmpty ? 3 : superOffersList.length,
                      itemBuilder: (context, index) {
                        if (superOffersList.isEmpty) return _buildPlaceholderCard();
                        return GestureDetector(
                          onTap: () => _navigateToProduct(superOffersList[index]),
                          child: _buildDealCard(superOffersList[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🆕 SECTION PUBS ET BONS DEALS
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 160,
              child: Row(
                children: [
                  // Widget Pub à Gauche
                  Expanded(
                    flex: 5,
                    child: AdsCarousel(ads: ref.watch(adsProvider)),
                  ),
                  const SizedBox(width: 10),
                  // Widget Bons Deals à Droite
                  Expanded(
                    flex: 5,
                    child: BonDealsGrid(deals: filteredGoodDeals),
                  ),
                ],
              ),
            ),
          ),

          // 6. SECTION DÉCOUVERTE (Carousel Auto)
          const SliverPadding(
             padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             sliver: SliverToBoxAdapter(
               child: Text("Découverte", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
             ),
          ),
          SliverToBoxAdapter(
            child: discoveryList.isEmpty 
              ? const SizedBox.shrink() // On cache si vide
              : _DiscoveryCarousel(
                  products: discoveryList, 
                  onTap: (p) => _navigateToProduct(p)
                ),
          ),

          // 7. MEILLEURS VENDEURS (Top Sellers du Marketplace)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade900, Colors.orange.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("⭐ Meilleurs Vendeurs", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Icon(Icons.trending_up, color: Colors.white.withValues(alpha: 0.8), size: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("Les produits les plus populaires", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: topSellers.isEmpty ? 3 : topSellers.length,
                      itemBuilder: (context, index) {
                        if (topSellers.isEmpty) return _buildPlaceholderCard();
                        return GestureDetector(
                          onTap: () => _navigateToProduct(topSellers[index]),
                          child: _buildTopSellerCard(topSellers[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 7. GRANDS MAGASINS VÉRIFIÉS
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade900, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("🏪 Grands Magasins", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: Colors.white, size: 12),
                            SizedBox(width: 2),
                            Text("Certifié", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("Supermarchés et commerces vérifiés", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: verifiedShopsProducts.isEmpty ? 3 : verifiedShopsProducts.length,
                      itemBuilder: (context, index) {
                        if (verifiedShopsProducts.isEmpty) return _buildPlaceholderCard();
                        return GestureDetector(
                          onTap: () => _navigateToProduct(verifiedShopsProducts[index]),
                          child: _buildVerifiedShopCard(verifiedShopsProducts[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 8. TOP RANKING (Grid 3 Colonnes)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            sliver: SliverToBoxAdapter(
               child: Text("Top Classement", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8), // Marge réduite pour 3 colonnes
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3 colonnes demandées
                childAspectRatio: 0.75, // Ratio hauteur/largeur ajusté (Réduit de ~25% vs 0.55)
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (effectiveRankingList.isEmpty) return _buildPlaceholderCard();
                  final product = effectiveRankingList[index];
                  return GestureDetector(
                    onTap: () => _navigateToProduct(product),
                    child: _buildProductGridCard(product),
                  );
                },
                childCount: effectiveRankingList.isEmpty ? 6 : effectiveRankingList.length,
              ),
            ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05), // Fond subtil
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              title, 
              textAlign: TextAlign.center, 
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.normal)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Product product) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: product.images.isNotEmpty 
                ? Image.network(product.images.first, fit: BoxFit.cover, width: double.infinity)
                : const Center(child: Icon(Icons.image, color: Colors.grey)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text("\$${product.price}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildDealCard(Product product) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
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
                    color: Colors.red,
                    child: const Text("FLASH", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("\$${product.price}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                Text("Low price", style: TextStyle(color: Colors.grey[500], fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildProductGridCard(Product product) {
    return MarketProductCard(product: product);
  }

  Widget _buildCategoryChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Text(
            label, 
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            )
          ),
          if (isSelected) 
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 3, 
              width: 20, 
              color: Colors.orange
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard() {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      color: Colors.grey[900],
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  /// Carte pour les meilleurs vendeurs du marketplace
  Widget _buildTopSellerCard(Product product) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
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
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: const Text("TOP", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(height: 2),
                Text("\$${product.price}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                Row(
                  children: [
                    const Icon(Icons.visibility, size: 10, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text("Populaire", style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Carte pour les produits des grands magasins vérifiés
  Widget _buildVerifiedShopCard(Product product) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
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
                  top: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 10, color: Colors.white),
                        SizedBox(width: 2),
                        Text("Vérifié", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(height: 2),
                Text("\$${product.price}", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                if (product.shopName != null)
                  Text(product.shopName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryCarousel extends StatefulWidget {
  final List<Product> products;
  final Function(Product) onTap;

  const _DiscoveryCarousel({required this.products, required this.onTap});

  @override
  State<_DiscoveryCarousel> createState() => _DiscoveryCarouselState();
}

class _DiscoveryCarouselState extends State<_DiscoveryCarousel> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % widget.products.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) return const SizedBox();
    final product = widget.products[_currentIndex];

    return GestureDetector(
      onTap: () => widget.onTap(product),
      child: Container(
        height: 120, // Taille réduite pour mobile
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Container(
            key: ValueKey<String>(product.id), // Clé unique pour l'animation
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Image Carrée à gauche
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product.images.isNotEmpty 
                     ? Image.network(product.images.first, width: 100, height: 100, fit: BoxFit.cover)
                     : Container(width: 100, height: 100, color: Colors.grey[800], child: const Icon(Icons.image)),
                ),
                const SizedBox(width: 12),
                // Infos Produit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("DÉCOUVERTE", style: TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "\$${product.price}", 
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                    ],
                  ),
                ),
                // Icône Arrow
                Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 14),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
