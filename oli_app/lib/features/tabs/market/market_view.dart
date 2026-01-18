import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product_model.dart'; 
import 'product_details_page.dart';

class MarketView extends ConsumerStatefulWidget {
  const MarketView({super.key});
  @override
  ConsumerState<MarketView> createState() => _MarketViewState();
}

class _MarketViewState extends ConsumerState<MarketView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = "Tout";
  
  // Catégories disponibles
  final Map<String, String> _categories = {
    "Tout": "",
    "Électronique": "electronics",
    "Mode": "fashion",
    "Maison": "home",
    "Véhicules": "vehicles",
    "Industrie": "industry",
    "Alimentation": "food",
    "Autres": "other",
  };

  @override
  void initState() {
    super.initState();
    // Charger les produits au démarrage
    Future.microtask(() {
      ref.read(marketProductsProvider.notifier).fetchProducts();
    });
  }

  void _onSearch(String value) {
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
    final products = ref.watch(marketProductsProvider);
    
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
                          _onSearch("");
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

          // 3. HEADER INFO
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${shuffledProducts.length} produits",
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  Text(
                    "Tous les vendeurs",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // 4. GRILLE PRODUITS
          shuffledProducts.isEmpty
            ? SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text(
                        "Aucun produit trouvé",
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _selectedCategory = "Tout");
                          ref.read(marketProductsProvider.notifier).fetchProducts();
                        },
                        child: const Text("Réinitialiser les filtres"),
                      ),
                    ],
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ProductCard(
                      product: shuffledProducts[index],
                      onTap: () => _navigateToProduct(shuffledProducts[index]),
                    ),
                    childCount: shuffledProducts.length,
                  ),
                ),
              ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
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

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  children: [
                    product.images.isEmpty
                      ? const Center(child: Icon(Icons.image, size: 50, color: Colors.grey))
                      : Image.network(
                          product.images[0],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        ),
                    // Badge vendeur si vérifié
                    if (product.shopVerified)
                      Positioned(
                        top: 4, right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.verified, size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name, 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "\$${product.price}", 
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 8,
                        backgroundImage: product.sellerAvatar != null ? NetworkImage(product.sellerAvatar!) : null,
                        child: product.sellerAvatar == null ? const Icon(Icons.person, size: 10) : null,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          product.seller,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}