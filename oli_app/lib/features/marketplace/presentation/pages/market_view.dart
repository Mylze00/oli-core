import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/market_provider.dart';
import 'product_details_page.dart';
import '../widgets/market_product_card.dart';
import '../../../../models/product_model.dart';

class MarketView extends ConsumerStatefulWidget {
  final String? initialCategoryLabel;
  const MarketView({super.key, this.initialCategoryLabel});
  @override
  ConsumerState<MarketView> createState() => _MarketViewState();
}

class _MarketViewState extends ConsumerState<MarketView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = "Tout";
  // Catégories disponibles (Liste enrichie)
  final Map<String, String> _categories = {
    "Tout": "",
    "Industrie": "Industrie",
    "Maison": "Maison",
    "Véhicules": "Véhicules",
    "Mode": "Mode",
    "Électronique": "Électronique",
    "Sports": "Sports",
    "Beauté": "Beauté",
    "Jouets": "Jouets",
    "Santé": "Santé",
    "Construction": "Construction",
    "Outils": "Outils",
    "Bureau": "Bureau",
    "Jardin": "Jardin",
    "Animaux": "Animaux",
    "Bébé": "Bébé",
    "Alimentation": "Alimentation", 
    "Sécurité": "Sécurité",
    "Autres": "Autres",
  };

  @override
  void initState() {
    super.initState();
    // Si une catégorie initiale est fournie
    if (widget.initialCategoryLabel != null && _categories.containsKey(widget.initialCategoryLabel)) {
      _selectedCategory = widget.initialCategoryLabel!;
      // Utiliser addPostFrameCallback pour lancer le fetch après le build initial du provider si besoin
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final categoryValue = _categories[_selectedCategory] ?? "";
        if (categoryValue.isNotEmpty) {
           ref.read(marketProductsProvider.notifier).fetchProducts(category: categoryValue);
        }
      });
    }
  }

  bool _isSearching = false;

  void _onSearch(String value) {
    setState(() {
      _isSearching = value.trim().isNotEmpty;
    });
    if (value.trim().isEmpty) {
      ref.read(marketProductsProvider.notifier).fetchProducts();
    } else {
      ref.read(marketProductsProvider.notifier).fetchProducts(search: value.trim());
    }
  }

  void _onCategorySelected(String label) {
    setState(() => _selectedCategory = label);
    final categoryValue = _categories[label] ?? "";
    if (categoryValue.isEmpty) {
      ref.read(marketProductsProvider.notifier).fetchProducts();
    } else {
      ref.read(marketProductsProvider.notifier).fetchProducts(category: categoryValue);
    }
  }

  void _navigateToProduct(Product product) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)));
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(marketProductsProvider);
    final products = productsAsync.valueOrNull ?? []; // Handle AsyncValue

    final topSellers = ref.watch(topSellersProvider);
    final verifiedShopsProducts = ref.watch(verifiedShopsProductsProvider);
    final featuredProducts = ref.watch(featuredProductsProvider);
    
    // Mélanger l'ordre des produits pour affichage aléatoire
    final shuffledProducts = List<Product>.from(products)..shuffle();

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // 1. APP BAR AVEC RECHERCHE
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
                  hintText: 'Rechercher dans le marché...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.blueAccent, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _searchCtrl.clear();
                          _onSearch("");
                          setState(() => _isSearching = false);
                        },
                      )
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.white),
                onPressed: () => _showFilterBottomSheet(),
              ),
            ],
          ),

          // 2. CATÉGORIES TABS
          if (!_isSearching)
            SliverToBoxAdapter(
              child: Container(
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _categories.keys.map((label) {
                    final isSelected = _selectedCategory == label;
                    return GestureDetector(
                      onTap: () => _onCategorySelected(label),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blueAccent : Colors.grey[900],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[400],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // 3. WIDGET: MEILLEURS VENDEURS
          if (!_isSearching)
            SliverToBoxAdapter(
              child: _buildHorizontalSection(
                title: "⭐ Meilleurs Vendeurs",
                subtitle: "Les plus populaires",
                products: topSellers,
                gradient: [Colors.orange.shade900, Colors.orange.shade700],
                badgeText: "TOP",
                badgeColor: Colors.orange,
              ),
            ),

          // 4. WIDGET: PRODUITS SPONSORISÉS
          if (!_isSearching)
            SliverToBoxAdapter(
              child: _buildHorizontalSection(
                title: "🎯 Produits Sponsorisés",
                subtitle: "Sélection premium",
                products: featuredProducts,
                gradient: [Colors.purple.shade900, Colors.purple.shade600],
                badgeText: "PROMO",
                badgeColor: Colors.purple,
              ),
            ),

          // 5. WIDGET: MAGASINS CERTIFIÉS
          if (!_isSearching)
            SliverToBoxAdapter(
              child: _buildHorizontalSection(
                title: "🏪 Magasins Certifiés",
                subtitle: "Boutiques vérifiées",
                products: verifiedShopsProducts,
                gradient: [Colors.blue.shade900, Colors.blue.shade600],
                badgeText: "VÉRIFIÉ",
                badgeColor: Colors.green,
                showVerifiedBadge: true,
              ),
            ),

          // 6. HEADER INFO - Tous les produits
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tous les produits (${shuffledProducts.length})",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Tous vendeurs",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // 7. GRILLE PRODUITS 3 COLONNES
          shuffledProducts.isEmpty
            ? SliverToBoxAdapter(
                child: Container(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 50, color: Colors.grey[700]),
                        const SizedBox(height: 12),
                        Text("Aucun produit trouvé", style: TextStyle(color: Colors.grey[500])),
                        TextButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _selectedCategory = "Tout";
                              _isSearching = false;
                            });
                            ref.read(marketProductsProvider.notifier).fetchProducts();
                          },
                          child: const Text("Réinitialiser"),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, 
                    childAspectRatio: 0.95, // Hauteur réduite de ~25%
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildCompactProductCard(shuffledProducts[index]),
                    childCount: shuffledProducts.length,
                  ),
                ),
              ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  /// Section horizontale réutilisable pour les widgets
  Widget _buildHorizontalSection({
    required String title,
    required String subtitle,
    required List<Product> products,
    required List<Color> gradient,
    required String badgeText,
    required Color badgeColor,
    bool showVerifiedBadge = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                ],
              ),
              if (showVerifiedBadge)
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
                      Text("Certifié", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: products.isEmpty 
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: products.length,
                  itemBuilder: (context, index) => _buildSectionCard(
                    products[index], 
                    badgeText, 
                    badgeColor,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  /// Carte pour les sections horizontales
  Widget _buildSectionCard(Product product, String badgeText, Color badgeColor) {
    return GestureDetector(
      onTap: () => _navigateToProduct(product),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 8),
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
                  Text("\$${product.price}", style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  /// Carte compacte pour la grille 3 colonnes (Refactored using MarketProductCard)
  Widget _buildCompactProductCard(Product product) {
    return MarketProductCard(product: product);
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Filtres", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text("Prix", style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFilterChip("< \$10", false),
                  _buildFilterChip("\$10 - \$50", false),
                  _buildFilterChip("> \$50", false),
                ],
              ),
              const SizedBox(height: 16),
              const Text("Localisation", style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFilterChip("Kinshasa", false),
                  _buildFilterChip("Lubumbashi", false),
                  _buildFilterChip("Goma", false),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Appliquer"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey[400], fontSize: 12)),
        selected: selected,
        onSelected: (val) {},
        backgroundColor: Colors.grey[900],
        selectedColor: Colors.blueAccent,
        checkmarkColor: Colors.white,
      ),
    );
  }
}