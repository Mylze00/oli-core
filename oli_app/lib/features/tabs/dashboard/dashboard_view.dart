import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_controller.dart';
import '../../../models/product_model.dart';
import '../../../pages/notifications_view.dart';
import '../market/product_details_page.dart';

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
    if (value.trim().isNotEmpty) {
      ref.read(marketProductsProvider.notifier).fetchProducts(search: value);
    } else {
      // Si vide, on reset
      ref.read(marketProductsProvider.notifier).fetchProducts();
    }
  }

  void _onCategorySelected(String label) {
    setState(() => _selectedCategory = label);
    final apiCat = _categories[label];
    // Si apiCat est vide, on envoie null pour tout récupérer, ou "" selon l'implémentation de fetchProducts
    ref.read(marketProductsProvider.notifier).fetchProducts(category: apiCat == "" ? null : apiCat);
  }

  void _navigateToProduct(Product product) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)));
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(marketProductsProvider);
    final authState = ref.watch(authControllerProvider);
    // On ne les utilise pas directement ici mais c'est dispo si besoin
    // final userName = authState.userData?['name'] ?? "Utilisateur";

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // 1. APP BAR AVEC BARRE DE RECHERCHE
          SliverAppBar(
            backgroundColor: Colors.black,
            floating: true,
            pinned: true,
            elevation: 0,
            title: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.orange, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.black54, size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Recherche par image bientôt disponible")));
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsView())),
              ),
            ],
          ),

          // 2. BOUTONS D'ACTION RAPIDE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                   // Exemple: Scroll vers la liste des catégories ou filtre spécifique
                  _buildQuickActionCard("Par Catégorie", Icons.category_outlined, Colors.orange, () {
                     // Pour l'instant, simple feedback visuel ou scroll to tabs
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Filtrez via les onglets ci-dessous")));
                  }),
                  const SizedBox(width: 8),
                  _buildQuickActionCard("Devis", Icons.request_quote_outlined, Colors.blue, null),
                  const SizedBox(width: 8),
                  _buildQuickActionCard("Sur Mesure", Icons.handyman_outlined, Colors.green, null),
                ],
              ),
            ),
          ),

          // 3. HORIZONTAL SCROLL ("Continuer à regarder")
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text("Continuer à regarder", style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: products.isEmpty ? 5 : products.length,
                    itemBuilder: (context, index) {
                      if (products.isEmpty) return _buildPlaceholderCard();
                      return GestureDetector(
                        onTap: () => _navigateToProduct(products[index]),
                        child: _buildHistoryCard(products[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 4. CATEGORY TABS
          SliverToBoxAdapter(
            child: Container(
              height: 50,
              margin: const EdgeInsets.symmetric(vertical: 10),
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
                      itemCount: products.isEmpty ? 3 : products.length,
                      itemBuilder: (context, index) {
                        if (products.isEmpty) return _buildPlaceholderCard();
                        return GestureDetector(
                          onTap: () => _navigateToProduct(products[index]),
                          child: _buildDealCard(products[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. TOP RANKING (Grid 3 Colonnes)
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
                childAspectRatio: 0.55, // Ratio hauteur/largeur ajusté pour 3 colonnes
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (products.isEmpty) return _buildPlaceholderCard();
                  final product = products[index % products.length];
                  return GestureDetector(
                    onTap: () => _navigateToProduct(product),
                    child: _buildProductGridCard(product),
                  );
                },
                childCount: products.isEmpty ? 6 : products.length * 2,
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
        onTap: onTap ?? () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$title bientôt disponible")));
        },
        child: Container(
          height: 80,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Produit
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  product.images.isNotEmpty 
                    ? Image.network(product.images.first, fit: BoxFit.cover, width: double.infinity)
                    : const Center(child: Icon(Icons.image, color: Colors.grey)),
                  // Info Vendeur (Overlay)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 8,
                            backgroundImage: product.sellerAvatar != null 
                                ? NetworkImage(product.sellerAvatar!) 
                                : null,
                            child: product.sellerAvatar == null 
                                ? const Icon(Icons.person, size: 10, color: Colors.white) 
                                : null,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              product.seller,
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11)),
                const SizedBox(height: 2),
                Text("\$${product.price}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text("${product.quantity} vendus", style: TextStyle(color: Colors.grey[500], fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
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
}
