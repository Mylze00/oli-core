import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/seller_provider.dart';
import '../../providers/market_provider.dart';
import '../../../../../models/product_model.dart';
import '../widgets/market_product_card.dart';

class SellerProfilePage extends ConsumerStatefulWidget {
  final String sellerId;
  const SellerProfilePage({super.key, required this.sellerId});

  @override
  ConsumerState<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends ConsumerState<SellerProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerProvider.notifier).fetchSellerProfile(widget.sellerId);
      ref.read(marketProductsProvider.notifier).fetchProducts(sellerId: widget.sellerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sellerAsync = ref.watch(sellerProvider);
    final productsAsync = ref.watch(marketProductsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: sellerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
        error: (err, _) => Center(child: Text("Erreur: $err", style: const TextStyle(color: Colors.red))),
        data: (profile) {
          return DefaultTabController(
            length: 3,
            child: Stack(
              children: [
                NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      // Header avec avatar centré et nom de boutique
                      SliverToBoxAdapter(
                        child: _buildCenteredHeader(profile),
                      ),
                      // Statistiques
                      SliverToBoxAdapter(
                        child: _buildStats(profile),
                      ),
                      // Bouton d'action
                      SliverToBoxAdapter(
                        child: _buildActionButton(),
                      ),
                      // Barre d'onglets collante (Sticky Tabs)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          const TabBar(
                            indicatorColor: Colors.orangeAccent,
                            indicatorWeight: 3,
                            labelColor: Colors.orangeAccent,
                            unselectedLabelColor: Colors.grey,
                            tabs: [
                              Tab(text: "Produits"),
                              Tab(text: "Avis"),
                              Tab(text: "Infos"),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    children: [
                      _buildProductsGrid(productsAsync),
                      _buildReviewsList(profile),
                      _buildStoreInfo(profile),
                    ],
                  ),
                ),
                // Bouton retour avec effet glassmorphism
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  child: _buildGlassBackButton(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGETS DE CONSTRUCTION ---

  Widget _buildGlassBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 32.5,
        height: 32.5,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16.25),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const Center(
              child: Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenteredHeader(SellerProfile profile) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 70, 20, 20),
      color: Colors.black,
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: profile.avatarUrl != null 
                ? NetworkImage(profile.avatarUrl!) 
                : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                profile.shopName ?? profile.name,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 8),
                const Icon(Icons.verified, color: Colors.blueAccent, size: 20),
              ],
              if (profile.accountType == 'entreprise' || profile.hasCertifiedShop) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "PRO",
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Membre depuis ${profile.joinedAt != null ? DateFormat('yyyy').format(profile.joinedAt!) : '2024'}",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(SellerProfile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Ventes", "${profile.totalSales}"),
          _buildStatItem("Note", "${profile.rating} ⭐"),
          _buildStatItem("Fiabilité", "99%"),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text("Envoyer un message"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsGrid(AsyncValue<List<Product>> productsAsync) {
    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            "Erreur lors du chargement des produits",
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (products) {
        if (products.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "Aucun produit en vente.",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          );
        }

        // Group products for different carousels (with safe conversion)
        final allProducts = products;
        final recentProducts = products.length > 10 
            ? products.sublist(0, 10) 
            : products;
        final featuredProducts = products
            .where((p) => p.discountPrice != null && p.discountPrice! > 0)
            .toList();
        
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner Section
              _buildHeroBanner(products[0]),
              
              const SizedBox(height: 20),
              
              // Featured Products Carousel
              if (featuredProducts.isNotEmpty) ...[
                _buildCarouselSection(
                  title: "Promotions",
                  products: featuredProducts,
                ),
                const SizedBox(height: 20),
              ],
              
              // Recent Products Carousel
              _buildCarouselSection(
                title: "Produits Récents",
                products: recentProducts,
              ),
              
              const SizedBox(height: 20),
              
              // All Products Carousel
              _buildCarouselSection(
                title: "Tous les produits",
                products: allProducts,
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroBanner(Product product) {
    return GestureDetector(
      onTap: () {
        // Navigation to product details
      },
      child: Container(
        height: 250,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: product.images.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(product.images[0]),
                  fit: BoxFit.cover,
                )
              : null,
          gradient: product.images.isEmpty
              ? LinearGradient(
                  colors: [
                    Colors.orangeAccent.withOpacity(0.6),
                    Colors.deepOrange.withOpacity(0.8)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.7)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Voir les détails",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselSection({required String title, required List<Product> products}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  "Voir tout",
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return Container(
                width: 160,
                margin: EdgeInsets.only(right: index < products.length - 1 ? 12 : 0),
                child: _buildProductCarouselCard(products[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCarouselCard(Product product) {
    return GestureDetector(
      onTap: () {
        // Navigation to product details
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                image: product.images.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(product.images[0]),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: product.images.isEmpty ? Colors.grey[800] : null,
              ),
              child: product.images.isEmpty
                  ? const Center(
                      child: Icon(Icons.image_not_supported,
                          color: Colors.grey, size: 40),
                    )
                  : null,
            ),
            // Product Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${double.tryParse(product.price)?.toStringAsFixed(2) ?? product.price} USD",
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsList(SellerProfile profile) {
    // Simulation d'une liste d'avis - À remplacer par vos données réelles
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: 5,
      itemBuilder: (context, index) => Card(
        color: const Color(0xFF1E1E1E),
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
          title: const Text("Client Oli", style: TextStyle(color: Colors.white)),
          subtitle: const Text("Super produit, livraison très rapide à Kinshasa !", style: TextStyle(color: Colors.grey)),
          trailing: const Text("5 ⭐", style: TextStyle(color: Colors.orangeAccent)),
        ),
      ),
    );
  }

  Widget _buildStoreInfo(SellerProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("À propos de la boutique", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(profile.description ?? "Aucune description fournie par le vendeur.", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          _buildInfoRow(Icons.location_on, "Localisation", "Gombe, Kinshasa"),
          _buildInfoRow(Icons.access_time, "Délai de réponse", "< 2 heures"),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 15),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ]),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

// Délégué pour la TabBar persistante
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverAppBarDelegate(this.tabBar);
  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.black, child: tabBar);
  }
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
