import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../config/api_config.dart';
import '../../../../models/product_model.dart';
import '../../../../core/theme/oli_colors.dart';
import '../../../../core/theme/oli_glass.dart';
import '../../../tabs/dashboard/widgets/product_card_common.dart';
import '../pages/product_details_page.dart';

// ── Mapping catégorie → sous-catégories (FR) ───────────────────────────────
const Map<String, List<Map<String, String>>> kCategorySubcats = {
  'electronics': [
    {'key': 'smartphones',      'label': 'Smartphones'},
    {'key': 'tv',               'label': 'TV & Écrans'},
    {'key': 'audio',            'label': 'Audio & Son'},
    {'key': 'climatisation',    'label': 'Climatisation'},
    {'key': 'electromenager',   'label': 'Électroménager'},
    {'key': 'informatique',     'label': 'Informatique'},
    {'key': 'photo_video',      'label': 'Photo & Vidéo'},
    {'key': 'accessoires_elec', 'label': 'Accessoires'},
  ],
  'fashion': [
    {'key': 'vetements_femme',  'label': 'Femme'},
    {'key': 'vetements_homme',  'label': 'Homme'},
    {'key': 'chaussures',       'label': 'Chaussures'},
    {'key': 'sacs_accessoires', 'label': 'Sacs & Accès.'},
    {'key': 'lingerie',         'label': 'Lingerie'},
    {'key': 'enfants_mode',     'label': 'Enfants'},
  ],
  'home': [
    {'key': 'meubles',          'label': 'Meubles'},
    {'key': 'literie',          'label': 'Literie'},
    {'key': 'cuisine',          'label': 'Cuisine'},
    {'key': 'decoration',       'label': 'Décoration'},
    {'key': 'salle_de_bain',    'label': 'Salle de bain'},
    {'key': 'linge_maison',     'label': 'Linge maison'},
  ],
  'vehicles': [
    {'key': 'voitures',         'label': 'Voitures'},
    {'key': 'motos',            'label': 'Motos'},
    {'key': 'pieces_auto',      'label': 'Pièces auto'},
    {'key': 'bateaux',          'label': 'Bateaux'},
  ],
  'sports': [
    {'key': 'fitness',          'label': 'Fitness'},
    {'key': 'football',         'label': 'Football'},
    {'key': 'basketball',       'label': 'Basketball'},
    {'key': 'natation',         'label': 'Natation'},
    {'key': 'velo',             'label': 'Vélo'},
    {'key': 'arts_martiaux',    'label': 'Arts martiaux'},
    {'key': 'camping',          'label': 'Camping'},
  ],
  'beauty': [
    {'key': 'soins_peau',       'label': 'Soins peau'},
    {'key': 'maquillage',       'label': 'Maquillage'},
    {'key': 'cheveux',          'label': 'Cheveux'},
    {'key': 'parfum',           'label': 'Parfum'},
    {'key': 'ongles',           'label': 'Ongles'},
    {'key': 'rasage',           'label': 'Rasage'},
  ],
  'health': [
    {'key': 'medicaments',      'label': 'Médicaments'},
    {'key': 'medical',          'label': 'Matériel médical'},
    {'key': 'sport_sante',      'label': 'Sport & Santé'},
  ],
  'tools': [
    {'key': 'electrique',       'label': 'Outils élec.'},
    {'key': 'main',             'label': 'Outils manuels'},
    {'key': 'echelle',          'label': 'Échelles'},
    {'key': 'jardinage',        'label': 'Jardinage'},
    {'key': 'soudure',          'label': 'Soudure'},
  ],
  'construction': [
    {'key': 'materiaux',        'label': 'Matériaux'},
    {'key': 'plomberie',        'label': 'Plomberie'},
    {'key': 'electricite_bat',  'label': 'Électricité'},
    {'key': 'peinture',         'label': 'Peinture'},
    {'key': 'toiture',          'label': 'Toiture'},
  ],
  'garden': [
    {'key': 'plantes',          'label': 'Plantes'},
    {'key': 'mobilier_jardin',  'label': 'Mobilier jardin'},
    {'key': 'arrosage',         'label': 'Arrosage'},
  ],
  'office': [
    {'key': 'fournitures',      'label': 'Fournitures'},
    {'key': 'mobilier_bureau',  'label': 'Mobilier bureau'},
    {'key': 'equipements',      'label': 'Équipements'},
  ],
  'industry': [
    {'key': 'machines',         'label': 'Machines'},
    {'key': 'emballage',        'label': 'Emballage'},
    {'key': 'agriculture',      'label': 'Agriculture'},
  ],
  'security': [
    {'key': 'surveillance',     'label': 'Surveillance'},
    {'key': 'serrurerie',       'label': 'Serrurerie'},
    {'key': 'protection',       'label': 'Protection'},
  ],
  'baby': [
    {'key': 'puericulture',     'label': 'Puériculture'},
    {'key': 'alimentation_bebe','label': 'Alimentation'},
    {'key': 'hygiene_bebe',     'label': 'Hygiène'},
    {'key': 'jouets_eveil',     'label': 'Jouets d\'éveil'},
  ],
  'toys': [
    {'key': 'jeux_enfants',         'label': 'Jeux enfants'},
    {'key': 'jeux_electroniques',   'label': 'Jeux élec.'},
    {'key': 'plein_air',            'label': 'Plein air'},
  ],
  'pets': [
    {'key': 'chiens_chats',     'label': 'Animaux'},
    {'key': 'veterinaire',      'label': 'Vétérinaire'},
  ],
  'food': [
    {'key': 'epicerie',         'label': 'Épicerie'},
    {'key': 'boissons',         'label': 'Boissons'},
    {'key': 'condiments',       'label': 'Condiments'},
  ],
};

/// Couleurs de la page selon le mode clair ou sombre.
class _CategoryColors {
  final bool isDark;
  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color border;
  final Color accent;
  final Color cardColor;
  final Color cardImageColor;

  factory _CategoryColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return _CategoryColors._(
      isDark: isDark,
      background: isDark ? Colors.black : OliLightColors.background,
      surface: isDark ? const Color(0xFF1A1A1A) : OliLightColors.surface,
      text: isDark ? Colors.white : Colors.black87,
      muted: isDark ? Colors.white60 : OliLightColors.textSecondary,
      border: isDark ? Colors.white12 : Colors.black12,
      accent: isDark ? OliPalette.blueOnDark : OliPalette.blue,
      cardColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      cardImageColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
    );
  }

  const _CategoryColors._({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.border,
    required this.accent,
    required this.cardColor,
    required this.cardImageColor,
  });
}

const _gridColumns = 3;
const _gridLeftPadding = 10.0;
// Chaque carte réserve déjà 7 de marge à droite, comme sur l'accueil
const _gridRightPadding = 3.0;
const _cardRightMargin = 7.0;
const _cardRowHeight = 186.0;

/// Page catégorie : sous-catégories + Sélection OLI + produits tous vendeurs
class CategoryProductsPage extends ConsumerStatefulWidget {
  final String categoryKey;
  final String categoryLabel;
  final IconData? categoryIcon;
  final List<Product> oliProducts;

  const CategoryProductsPage({
    super.key,
    required this.categoryKey,
    required this.categoryLabel,
    this.categoryIcon,
    this.oliProducts = const [],
  });

  @override
  ConsumerState<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends ConsumerState<CategoryProductsPage> {
  List<Product> _products = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 30;
  String _sortBy = 'recent';
  String? _selectedSubcat; // null = Tout
  int _fetchGeneration = 0;
  final ScrollController _scrollController = ScrollController();

  List<Map<String, String>> get _subcats =>
      kCategorySubcats[widget.categoryKey] ?? [];

  List<Product> get _filteredOliProducts {
    if (_selectedSubcat == null) return widget.oliProducts;
    return widget.oliProducts
        .where((p) => p.subcategory == _selectedSubcat)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) _loadMore();
    }
  }

  void _selectSubcat(String? key) {
    if (_selectedSubcat == key) return;
    setState(() {
      _selectedSubcat = key;
      _products = [];
      _offset = 0;
      _hasMore = true;
      _isLoading = true;
    });
    _fetchProducts();
  }

  /// Le tri est refait par le serveur pour porter sur toute la catégorie.
  void _changeSort(String sort) {
    if (_sortBy == sort) return;
    setState(() {
      _sortBy = sort;
      _products = [];
      _offset = 0;
      _hasMore = true;
    });
    _fetchProducts();
  }

  Future<void> _fetchProducts({bool append = false}) async {
    // Seule la dernière demande compte quand l'utilisateur change vite de filtre ou de tri
    final generation = ++_fetchGeneration;
    if (!append) {
      setState(() {
        _isLoading = true;
        _offset = 0;
      });
    }
    try {
      final params = <String, String>{
        'limit': '$_pageSize',
        'offset': '$_offset',
        'sort': _sortBy,
      };
      if (widget.categoryKey.isNotEmpty) params['category'] = widget.categoryKey;
      if (_selectedSubcat != null) params['subcategory'] = _selectedSubcat!;

      final uri = Uri.parse('${ApiConfig.baseUrl}/products').replace(
        queryParameters: params,
      );
      final response = await http.get(uri);
      if (generation != _fetchGeneration) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['products'] != null) {
          data = decoded['products'] as List<dynamic>;
          _hasMore = decoded['hasMore'] ?? false;
        } else {
          data = [];
        }

        final products = <Product>[];
        for (final json in data) {
          try { products.add(Product.fromJson(json)); } catch (_) {}
        }

        if (products.length < _pageSize) _hasMore = false;
        _offset += products.length;

        if (mounted) {
          setState(() {
            if (append) {
              _products.addAll(products);
            } else {
              _products = products;
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error fetching category products: $e');
      if (mounted && generation == _fetchGeneration) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoading = true);
    await _fetchProducts(append: true);
  }

  /// Même image que sur le bouton de la catégorie.
  String get _categoryImage => 'assets/images/categories/${widget.categoryKey}.png';

  Widget _buildCategoryImage(double size, _CategoryColors colors) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: colors.border),
      ),
      child: Image.asset(
        _categoryImage,
        fit: BoxFit.contain,
        cacheWidth: 240,
        errorBuilder: (_, __, ___) => Icon(
          widget.categoryIcon ?? Icons.category,
          color: Colors.black54,
          size: size * 0.55,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _CategoryColors.of(context);
    final products = _products;
    final oliFiltered = _filteredOliProducts;
    final selectedSubcatLabel = _selectedSubcat == null
        ? null
        : _subcats.firstWhere(
            (s) => s['key'] == _selectedSubcat,
            orElse: () => {'label': ''},
          )['label'];
    final cardWidth = (MediaQuery.of(context).size.width - _gridLeftPadding - _gridRightPadding) /
            _gridColumns -
        _cardRightMargin;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            _buildCategoryImage(40, colors),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.categoryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.text, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (selectedSubcatLabel != null && selectedSubcatLabel.isNotEmpty)
                    Text(
                      selectedSubcatLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: colors.accent),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Trier les produits',
            icon: Icon(Icons.sort, color: colors.text),
            color: colors.surface,
            onSelected: _changeSort,
            itemBuilder: (_) => [
              _buildSortItem('recent', 'Plus récents', Icons.access_time, colors),
              _buildSortItem('price_asc', 'Prix croissant', Icons.arrow_upward, colors),
              _buildSortItem('price_desc', 'Prix décroissant', Icons.arrow_downward, colors),
              _buildSortItem('popular', 'Plus populaires', Icons.trending_up, colors),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_subcats.isNotEmpty) _buildSubcatChips(colors),
          Expanded(
            child: _isLoading && _products.isEmpty && oliFiltered.isEmpty
                ? Center(child: CircularProgressIndicator(color: colors.accent))
                : _products.isEmpty && oliFiltered.isEmpty
                    ? _buildEmptyState(colors)
                    : CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          if (oliFiltered.isNotEmpty)
                            SliverToBoxAdapter(child: _buildOliSection(oliFiltered, cardWidth, colors)),
                          if (_products.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                                child: Text(
                                  '${_products.length} produit${_products.length > 1 ? 's' : ''} sur le marché',
                                  style: TextStyle(color: colors.text, fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.only(
                              left: _gridLeftPadding,
                              right: _gridRightPadding,
                            ),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _gridColumns,
                                mainAxisSpacing: 8,
                                mainAxisExtent: _cardRowHeight,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index >= products.length) {
                                    return Center(
                                      child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2),
                                    );
                                  }
                                  return _buildProductCard(products[index], cardWidth, colors);
                                },
                                childCount: products.length + (_hasMore ? 1 : 0),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.only(bottom: bottomNavClearance(context)),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ── Chips sous-catégories ──────────────────────────────────────────────────
  Widget _buildSubcatChips(_CategoryColors colors) {
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            _buildChip(null, 'Tout', colors),
            ..._subcats.map((s) => _buildChip(s['key'], s['label']!, colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String? key, String label, _CategoryColors colors) {
    final selected = _selectedSubcat == key;
    return GestureDetector(
      onTap: () => _selectSubcat(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? OliPalette.blue : colors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? OliPalette.blue : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : colors.text,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Section Sélection OLI ──────────────────────────────────────────────────
  Widget _buildOliSection(List<Product> oliProducts, double cardWidth, _CategoryColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
          child: Row(
            children: [
              Icon(Icons.verified, size: 18, color: colors.accent),
              const SizedBox(width: 6),
              Text(
                'Sélection OLI',
                style: TextStyle(color: colors.text, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text(
                '${oliProducts.length} article${oliProducts.length > 1 ? 's' : ''}',
                style: TextStyle(color: colors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(
          height: _cardRowHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: _gridLeftPadding),
            itemCount: oliProducts.length,
            itemBuilder: (context, i) => Align(
              alignment: Alignment.topCenter,
              child: _buildProductCard(oliProducts[i], cardWidth, colors),
            ),
          ),
        ),
      ],
    );
  }

  // ── Carte produit, identique à celle de l'accueil ──────────────────────────
  Widget _buildProductCard(Product product, double width, _CategoryColors colors) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
      ),
      child: DashboardProductCard(
        product: product,
        width: width,
        priceColor: colors.accent,
        priceFontSize: 12,
        badgeText: product.sellerIsVerified ? 'Vérifié' : null,
        badgeColor: product.sellerIsVerified ? Colors.green : null,
        badgeOnRight: true,
        cardColor: colors.cardColor,
        imageBackgroundColor: colors.cardImageColor,
        subtitleWidget: Text(
          product.seller,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.muted, fontSize: 10),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildSortItem(String value, String label, IconData icon, _CategoryColors colors) {
    final selected = _sortBy == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: selected ? colors.accent : colors.muted),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: selected ? colors.accent : colors.text,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ]),
    );
  }

  Widget _buildEmptyState(_CategoryColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCategoryImage(88, colors),
            const SizedBox(height: 16),
            Text(
              'Aucun produit dans "${widget.categoryLabel}"',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.text, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              "Les produits apparaîtront ici dès qu'ils seront ajoutés",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
