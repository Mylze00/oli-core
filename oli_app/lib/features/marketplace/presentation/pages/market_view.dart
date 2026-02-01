import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/market_provider.dart';
import 'product_details_page.dart';
import '../widgets/market_product_card.dart';
import '../widgets/search_product_list_item.dart';
import '../../../../models/product_model.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../tabs/dashboard/widgets/product_sections.dart'; // For TopRankingGrid
import 'dart:math'; // For shuffling

class MarketView extends ConsumerStatefulWidget {
  final String? initialCategoryLabel;
  final String? initialSearchQuery;
  const MarketView({super.key, this.initialCategoryLabel, this.initialSearchQuery});
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
  
  final List<String> _stopWords = ['Paire', 'Lot', 'Set', 'Kit', 'Nouveau', 'Promo', 'Super', 'Pack', 'Mini', 'La', 'Le', 'Les'];

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
    // Si une recherche initiale est fournie
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _isSearching = true;
      _searchCtrl.text = widget.initialSearchQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
         ref.read(marketProductsProvider.notifier).fetchProducts(search: widget.initialSearchQuery!);
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
    // Theme - HOISTED TO TOP
    final isDark = ref.watch(themeProvider);
    final backgroundColor = isDark ? Colors.black : Colors.grey[400];
    final titleColor = isDark ? Colors.white : Colors.black;

    // Filter out OLI products
    bool _shouldShowProduct(Product p) => p.seller.toUpperCase() != 'OLI';

    // 4. SEARCH & FILTER LOGIC
    // Si recherche active, on inclut TOUS les produits (même OLI) pour pouvoir les segmenter
    // Sinon, on masque OLI par défaut
    // 4. SEARCH & FILTER LOGIC
    // Si recherche active, on inclut TOUS les produits (même OLI) pour pouvoir les segmenter
    // Sinon, on masque OLI par défaut (Exclusion stricte demandée sur le "Home" du Market)
    final baseProducts = productsAsync.valueOrNull ?? [];
    
    // FILTRAGE GLOBAL : Pas de produits OLI dans la vue par défaut (hors recherche)
    final validProducts = baseProducts.where(_shouldShowProduct).toList();

    // Logic for Search
    List<Product> searchResults = [];
    List<Product> oliResults = [];
    List<Product> certifiedResults = [];
    List<Product> standardResults = [];

    if (_isSearching) {
      final query = _searchCtrl.text.toLowerCase().trim();
      searchResults = baseProducts.where((p) { // Use baseProducts to find OLI items if searched specifically
        final matchesQuery = p.name.toLowerCase().contains(query) || 
                             p.description.toLowerCase().contains(query);
         
        // Simple category placeholder
        final matchesCategory = _selectedCategory == "Tout" ? true : true; 

        return matchesQuery && matchesCategory;
      }).toList();

      for (var p in searchResults) {
        if (p.seller.toUpperCase() == 'OLI') {
          oliResults.add(p);
        } else if (p.sellerHasCertifiedShop) {
          certifiedResults.add(p);
        } else {
          standardResults.add(p);
        }
      }
    }

    // --- LOGIC FOR DEFAULT VIEW (Dynamic Dashboard Style) ---
    // 1. Dynamic Grouping Algorithm (Same as Dashboard but strictly no OLI)
    String selectedKeyword = "";
    List<Product> selectionProducts = [];
    if (!_isSearching) {
      final Map<String, List<Product>> groupedProducts = {};
      
      for (var product in validProducts) {
        final words = product.name.split(' ');
        String focusKW = words.isNotEmpty ? words.first : "";
        
        if (words.length > 1 && (focusKW.length <= 2 || _stopWords.contains(focusKW))) {
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
        selectedKeyword = validKeys.first;
        selectionProducts = groupedProducts[selectedKeyword]!.take(15).toList();
      }
    }

    // 2. Remaining Products for Grid (Deduplicated)
    final remainingProducts = validProducts.where((p) => !selectionProducts.contains(p)).toList();
    
    // Sort for clustering coherence
    remainingProducts.sort((a, b) => a.name.compareTo(b.name));

    // 3. Build Patterned Grid Slivers
    List<Widget> patternedSlivers = [];
    if (!_isSearching) {
      patternedSlivers = _buildPatternedRankingGrid(remainingProducts, titleColor);
    }
    
    // Theme variables were hoisted.


    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // 1. APP BAR (Flottante)
          SliverAppBar(
            backgroundColor: Colors.black,
            floating: true,
            pinned: true,
            elevation: 0,
            title: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Rechercher un produit...",
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                  suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                             _isSearching = false;
                             _selectedCategory = "Tout";
                          });
                          // Refetch default
                          ref.read(marketProductsProvider.notifier).fetchProducts();
                        },
                      )
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    setState(() => _isSearching = true);
                    // On pourrait refetcher côté serveur ici si le filtrage local ne suffit pas
                    ref.read(marketProductsProvider.notifier).fetchProducts(search: val);
                  }
                },
              ),
            ),
            actions: [
               IconButton(
                 icon: const Icon(Icons.tune, color: Colors.white),
                 onPressed: _showFilterBottomSheet,
               ),
            ],
          ),

          // 2. CATEGORIES (Masqué si recherche)
          if (!_isSearching)
            SliverToBoxAdapter(
              child: Container(
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final label = _categories.keys.elementAt(index);
                    final isSelected = _selectedCategory == label;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = label);
                        // TODO: Refetch avec filtre catégorie
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blueAccent : Colors.grey[900],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.grey[800]!),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[400],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // 3. DYNAMIC SELECTION WIDGET
          if (!_isSearching && selectionProducts.isNotEmpty)
             SliverToBoxAdapter(
               child: Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                 child: _buildHorizontalSection(
                   title: "Sélection : $selectedKeyword",
                   subtitle: "Inspiré de vos goûts",
                   products: selectionProducts,
                   gradient: [Colors.black, Colors.black87], // Specific style or use theme
                   badgeText: "NEW",
                   badgeColor: Colors.tealAccent.shade700,
                 ),
               ),
             ),

          // 4. SEARCH RESULTS (SEGMENTÉS)
          if (_isSearching) ...[
             // ... existing search logic ... (kept simple for brevity in replacement if possible, but replace tool needs exact match or full block)
             // I am replacing the existing SEARCH + GRID logic blocks entirely here.
             if (searchResults.isEmpty)
               SliverToBoxAdapter(
                 child: Container(
                   height: 200,
                   margin: const EdgeInsets.only(top: 50),
                   child: Center(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(Icons.search_off, size: 50, color: Colors.grey[700]),
                         const SizedBox(height: 12),
                         Text("Aucun résultat trouvé", style: TextStyle(color: Colors.grey[500])),
                       ],
                     ),
                   ),
                 ),
               )
             else ...[
               if (oliResults.isNotEmpty) ...[
                 _buildSectionHeader("Produits OLI", Icons.verified_user, Colors.orange),
                 SliverList(delegate: SliverChildBuilderDelegate((context, index) => SearchProductListItem(product: oliResults[index]), childCount: oliResults.length)),
               ],
               if (certifiedResults.isNotEmpty) ...[
                 _buildSectionHeader("Magasins Certifiés", Icons.storefront, Colors.blue),
                 SliverList(delegate: SliverChildBuilderDelegate((context, index) => SearchProductListItem(product: certifiedResults[index]), childCount: certifiedResults.length)),
               ],
               if (standardResults.isNotEmpty) ...[
                  _buildSectionHeader("Autres Vendeurs", Icons.person_outline, Colors.grey),
                  SliverList(delegate: SliverChildBuilderDelegate((context, index) => SearchProductListItem(product: standardResults[index]), childCount: standardResults.length)),
               ],
               const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
             ],
          ],

          // 5. PATTERNED GRID RESULTS (Default View)
          if (!_isSearching) ...patternedSlivers,

          if (!_isSearching)
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),

        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const Expanded(child: Divider(color: Colors.grey, indent: 12, endIndent: 0, thickness: 0.5)),
          ],
        ),
      ),
    );
  }

  // --- Patterned Grid Logic ---
  List<Widget> _buildPatternedRankingGrid(List<Product> allProducts, Color textColor) {
    List<Widget> slivers = [];
    int index = 0;

    // Header Global
    if (allProducts.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          sliver: SliverToBoxAdapter(
             child: Text("Explorer", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ),
      );
    }

    while (index < allProducts.length) {
      // 1. Take 3 items for 3-col grid
      if (index < allProducts.length) {
        int take3Cols = 3;
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
      }

      // 2. Take 2 items for 2-col grid
      if (index < allProducts.length) {
        int take2Cols = 2;
        final chunk2Cols = allProducts.skip(index).take(take2Cols).toList();
        
        if (chunk2Cols.isNotEmpty) {
          // Focus Title Check
          final firstProduct = chunk2Cols.first;
          final words = firstProduct.name.split(' ');
          String focusWord = words.isNotEmpty ? words.first : "";

          if (words.length > 1 && (focusWord.length <= 2 || _stopWords.contains(focusWord))) {
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
                       Text("Focus : $focusWord", style: TextStyle(color: textColor.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 14)),
                     ],
                   ),
                 ),
               ),
             );
          }

          slivers.add(
            TopRankingGrid(
              products: chunk2Cols,
              crossAxisCount: 2,
              childAspectRatio: 0.85, 
            )
          );
          slivers.add(const SliverPadding(padding: EdgeInsets.only(top: 8)));
          index += chunk2Cols.length;
        }
      }
    }
    return slivers;
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
                  Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), // Fixed color for card header usually or theme
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
                  Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10)),
                   Consumer(
                    builder: (context, ref, _) {
                      final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
                      // Ensure reactivity by watching the provider if needed, or rely on parent rebuilds. 
                      // Ideally watch the state to rebuild on currency change.
                      ref.watch(exchangeRateProvider);
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