
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../providers/market_provider.dart';
import '../pages/product_details_page.dart';
import '../widgets/market_product_card.dart';
import '../widgets/market_spotlight_carousel.dart';
import '../widgets/market_secondhand_carousel.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../tabs/dashboard/widgets/verified_shops_carousel.dart';
import '../../../tabs/dashboard/widgets/product_sections.dart';
import '../../../tabs/dashboard/providers/shops_provider.dart';

/// Page Marché - Produits des utilisateurs
class MarketView extends ConsumerStatefulWidget {
  final String? initialCategoryLabel;
  final String? initialSearchQuery;

  const MarketView({
    super.key,
    this.initialCategoryLabel,
    this.initialSearchQuery,
  });

  @override
  ConsumerState<MarketView> createState() => _MarketViewState();
}

class _MarketViewState extends ConsumerState<MarketView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = "Tout";
  String _searchQuery = "";

  // Cache du shuffle : ne recalcule que si les données ou les filtres changent
  List<Product> _cachedFiltered = [];
  String _lastFilterKey = ''; // clé = "searchQuery|category|productIds"

  final Map<String, String> _categories = {
    "Tout": "",
    "Industrie": "industry",
    "Maison": "home",
    "Véhicules": "vehicles",
    "Mode": "fashion",
    "Électronique": "electronics",
    "Sports": "sports",
    "Beauté": "beauty",
    "Jouets": "toys",
    "Santé": "health",
    "Construction": "construction",
    "Outils": "tools",
    "Bureau": "office",
    "Jardin": "garden",
    "Animaux": "pets",
    "Bébé": "baby",
    "Alimentation": "food",
    "Sécurité": "security",
    "Autres": "other",
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchCtrl.text = widget.initialSearchQuery!;
      _searchQuery = widget.initialSearchQuery!;
    }
    if (widget.initialCategoryLabel != null) {
      _selectedCategory = widget.initialCategoryLabel!;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> _filterProducts(List<Product> products) {
    // Clé de cache : si rien n'a changé, on retourne le résultat précédent
    // (le shuffle reste STABLE entre les rebuilds, pas de flashs)
    final ids = products.map((p) => p.id).join(',');
    final key = '$_searchQuery|$_selectedCategory|$ids';
    if (key == _lastFilterKey && _cachedFiltered.isNotEmpty) {
      return _cachedFiltered;
    }

    var filtered = products;

    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains(query) ||
        p.seller.toLowerCase().contains(query) ||
        p.description.toLowerCase().contains(query)
      ).toList();
    }

    // Filtre par catégorie
    if (_selectedCategory != "Tout") {
      final categoryKey = _categories[_selectedCategory] ?? "";
      if (categoryKey.isNotEmpty) {
        filtered = filtered.where((p) =>
          p.category?.toLowerCase() == categoryKey.toLowerCase()
        ).toList();
      }
    }

    // Shuffle + diversification (UNE SEULE FOIS, puis mis en cache)
    final result = _diversify(filtered);
    _cachedFiltered = result;
    _lastFilterKey = key;
    return result;
  }

  /// Mélange les produits et garantit un maximum de diversité vendeur
  /// en tête de liste (au moins 1 produit par vendeur parmi les premiers)
  List<Product> _diversify(List<Product> products) {
    if (products.length <= 1) return products;

    final rng = Random();
    final shuffled = List<Product>.from(products)..shuffle(rng);

    // Construire une tête diversifiée (un produit par vendeur en premier)
    final head = <Product>[];
    final tail = <Product>[];
    final seenSellers = <String>{};

    for (final p in shuffled) {
      final sid = p.sellerId.trim();
      if (sid.isNotEmpty && !seenSellers.contains(sid)) {
        seenSellers.add(sid);
        head.add(p);
      } else {
        tail.add(p);
      }
    }

    // Mélanger aussi la queue
    tail.shuffle(rng);

    return [...head, ...tail];
  }

  void _navigateToProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final backgroundColor = isDark ? Colors.black : Colors.grey[400];
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final productsAsync = ref.watch(marketProductsProvider);
    final verifiedShopsAsync = ref.watch(verifiedShopsProvider);
    final verifiedShops = verifiedShopsAsync.valueOrNull ?? [];
    final verifiedShopsProducts = ref.watch(verifiedShopsProductsProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: productsAsync.when(
        // ── LOADING ──
        loading: () => _buildShell(textColor, isDark, [
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          ),
        ]),
        // ── ERROR ──
        error: (error, _) => _buildShell(textColor, isDark, [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Erreur de chargement', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('$error', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(marketProductsProvider.notifier).fetchProducts(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  ),
                ],
              ),
            ),
          ),
        ]),
        // ── DATA ──
        data: (allProducts) {
          final filtered = _filterProducts(allProducts);

          // Sections — filtered est déjà mélangé et diversifié
          final recentProducts = filtered.take(8).toList();
          final allGridProducts = filtered.length > 8 ? filtered.skip(8).toList() : <Product>[];
          // 3 produits avant Spotlight, puis Seconde Main après le 9e (3+6)
          final gridBefore = allGridProducts.take(3).toList();
          final gridAfterAll = allGridProducts.length > 3 ? allGridProducts.skip(3).toList() : <Product>[];
          // Seconde Main s'insère après 6 produits du gridAfter (3+6 = 9e produit)
          final gridAfterA = gridAfterAll.take(6).toList();
          final gridAfterB = gridAfterAll.length > 6 ? gridAfterAll.skip(6).toList() : <Product>[];



          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(marketProductsProvider.notifier).fetchProducts();
            },
            child: CustomScrollView(
              slivers: [
                // ── 1. APP BAR avec recherche ──
                _buildSearchAppBar(textColor, isDark),

                // ── 2. CATÉGORIES ──
                _buildCategoryChips(isDark),

                // ── 3. BOUTIQUES VÉRIFIÉES ──
                SliverToBoxAdapter(
                  child: VerifiedShopsCarousel(shops: verifiedShops),
                ),

                // ── 4. PRODUITS BOUTIQUES CERTIFIÉES ──
                if (verifiedShopsProducts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: VerifiedShopProductsSection(products: verifiedShopsProducts),
                  ),

                // ── 5. COMPTEUR ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${filtered.length} produit${filtered.length > 1 ? 's' : ''}',
                          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                        ),
                        if (_searchQuery.isNotEmpty || _selectedCategory != "Tout")
                          GestureDetector(
                            onTap: () => setState(() {
                              _searchQuery = "";
                              _searchCtrl.clear();
                              _selectedCategory = "Tout";
                            }),
                            child: Row(
                              children: [
                                Icon(Icons.clear, size: 14, color: Colors.blueAccent),
                                const SizedBox(width: 4),
                                const Text('Effacer filtres', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── 4. SECTION RÉCENTS (carousel horizontal) ──
                if (recentProducts.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Container(width: 3, height: 18, decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text('Récemment ajoutés', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),
                          Text('🔥', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: recentProducts.length,
                        itemBuilder: (context, index) {
                          final product = recentProducts[index];
                          return GestureDetector(
                            onTap: () => _navigateToProduct(product),
                            child: Container(
                              width: 150,
                              margin: const EdgeInsets.only(right: 10),
                              child: MarketProductCard(product: product),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // ── 5. SÉPARATEUR ──
                if (allGridProducts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Container(width: 3, height: 18, decoration: BoxDecoration(color: Colors.tealAccent.shade700, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text('Explorer', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),
                          Text('🛍️', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),

                // ── 6a. GRILLE PRODUITS (6 premiers) ──
                if (gridBefore.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = gridBefore[index];
                          return GestureDetector(
                            onTap: () => _navigateToProduct(product),
                            child: MarketProductCard(product: product),
                          );
                        },
                        childCount: gridBefore.length,
                      ),
                    ),
                  ),

                // ── 7. SPOTLIGHT CAROUSEL ── (produits non encore affichés)
                if (filtered.length >= 4)
                  SliverToBoxAdapter(
                    child: MarketSpotlightCarousel(products: filtered),
                  ),

                // ── 6b. GRILLE (6 produits après Spotlight → total = 9) ──
                if (gridAfterA.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = gridAfterA[index];
                          return GestureDetector(
                            onTap: () => _navigateToProduct(product),
                            child: MarketProductCard(product: product),
                          );
                        },
                        childCount: gridAfterA.length,
                      ),
                    ),
                  ),

                // ── 8. SECONDE MAIN ── après le 9e produit (3 + 6)
                SliverToBoxAdapter(
                  child: MarketSecondhandCarousel(products: allProducts),
                ),

                // ── 6c. GRILLE (reste) ──
                if (gridAfterB.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = gridAfterB[index];
                          return GestureDetector(
                            onTap: () => _navigateToProduct(product),
                            child: MarketProductCard(product: product),
                          );
                        },
                        childCount: gridAfterB.length,
                      ),
                    ),
                  ),

                // ── EMPTY STATE ──
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: textColor.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text('Aucun produit trouvé', style: TextStyle(color: textColor, fontSize: 16)),
                          if (_searchQuery.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'pour "$_searchQuery"',
                                style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Shell pour loading/error (AppBar + contenu)
  Widget _buildShell(Color textColor, bool isDark, List<Widget> slivers) {
    return CustomScrollView(
      slivers: [
        _buildSearchAppBar(textColor, isDark),
        ...slivers,
      ],
    );
  }

  /// AppBar avec barre de recherche intégrée
  Widget _buildSearchAppBar(Color textColor, bool isDark) {
    return SliverAppBar(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      floating: true,
      snap: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 70,
      title: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Rechercher un produit...',
            hintStyle: TextStyle(color: textColor.withOpacity(0.4), fontSize: 14),
            prefixIcon: Icon(Icons.search, color: textColor.withOpacity(0.4), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() {
                    _searchQuery = "";
                    _searchCtrl.clear();
                  }),
                  child: Icon(Icons.close, color: textColor.withOpacity(0.4), size: 18),
                )
              : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
    );
  }

  /// Chips de catégories horizontales
  Widget _buildCategoryChips(bool isDark) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final label = _categories.keys.elementAt(index);
            final isSelected = label == _selectedCategory;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedCategory = label;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blueAccent
                        : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[300]),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected ? null : Border.all(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white.withOpacity(0.7) : Colors.black87),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}