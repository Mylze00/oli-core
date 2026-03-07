import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../config/api_config.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../utils/cloudinary_helper.dart';
import '../pages/product_details_page.dart';

// ── Mapping catégorie → sous-catégories (FR) ───────────────────────────────
const Map<String, List<Map<String, String>>> kCategorySubcats = {
  'electronics': [
    {'key': 'smartphones',      'label': '📱 Smartphones'},
    {'key': 'tv',               'label': '📺 TV & Écrans'},
    {'key': 'audio',            'label': '🔊 Audio & Son'},
    {'key': 'climatisation',    'label': '❄️ Climatisation'},
    {'key': 'electromenager',   'label': '🍳 Électroménager'},
    {'key': 'informatique',     'label': '💻 Informatique'},
    {'key': 'photo_video',      'label': '📷 Photo & Vidéo'},
    {'key': 'accessoires_elec', 'label': '🔌 Accessoires'},
  ],
  'fashion': [
    {'key': 'vetements_femme',  'label': '👗 Femme'},
    {'key': 'vetements_homme',  'label': '👔 Homme'},
    {'key': 'chaussures',       'label': '👟 Chaussures'},
    {'key': 'sacs_accessoires', 'label': '👜 Sacs & Accès.'},
    {'key': 'lingerie',         'label': '🩱 Lingerie'},
    {'key': 'enfants_mode',     'label': '🧒 Enfants'},
  ],
  'home': [
    {'key': 'meubles',          'label': '🛋️ Meubles'},
    {'key': 'literie',          'label': '🛏️ Literie'},
    {'key': 'cuisine',          'label': '🍽️ Cuisine'},
    {'key': 'decoration',       'label': '🖼️ Décoration'},
    {'key': 'salle_de_bain',    'label': '🚿 Salle de bain'},
    {'key': 'linge_maison',     'label': '🧺 Linge maison'},
  ],
  'vehicles': [
    {'key': 'voitures',         'label': '🚗 Voitures'},
    {'key': 'motos',            'label': '🏍️ Motos'},
    {'key': 'pieces_auto',      'label': '🔧 Pièces auto'},
    {'key': 'bateaux',          'label': '⛵ Bateaux'},
  ],
  'sports': [
    {'key': 'fitness',          'label': '🏋️ Fitness'},
    {'key': 'football',         'label': '⚽ Football'},
    {'key': 'basketball',       'label': '🏀 Basketball'},
    {'key': 'natation',         'label': '🏊 Natation'},
    {'key': 'velo',             'label': '🚴 Vélo'},
    {'key': 'arts_martiaux',    'label': '🥊 Arts martiaux'},
    {'key': 'camping',          'label': '⛺ Camping'},
  ],
  'beauty': [
    {'key': 'soins_peau',       'label': '✨ Soins peau'},
    {'key': 'maquillage',       'label': '💄 Maquillage'},
    {'key': 'cheveux',          'label': '💇 Cheveux'},
    {'key': 'parfum',           'label': '🌸 Parfum'},
    {'key': 'ongles',           'label': '💅 Ongles'},
    {'key': 'rasage',           'label': '🪒 Rasage'},
  ],
  'health': [
    {'key': 'medicaments',      'label': '💊 Médicaments'},
    {'key': 'medical',          'label': '🏥 Matériel médical'},
    {'key': 'sport_sante',      'label': '🩺 Sport & Santé'},
  ],
  'tools': [
    {'key': 'electrique',       'label': '⚡ Outils élec.'},
    {'key': 'main',             'label': '🔨 Outils manuels'},
    {'key': 'echelle',          'label': '🪜 Échelles'},
    {'key': 'jardinage',        'label': '🌿 Jardinage'},
    {'key': 'soudure',          'label': '🔥 Soudure'},
  ],
  'construction': [
    {'key': 'materiaux',        'label': '🧱 Matériaux'},
    {'key': 'plomberie',        'label': '🚰 Plomberie'},
    {'key': 'electricite_bat',  'label': '💡 Électricité'},
    {'key': 'peinture',         'label': '🎨 Peinture'},
    {'key': 'toiture',          'label': '🏗️ Toiture'},
  ],
  'garden': [
    {'key': 'plantes',          'label': '🌱 Plantes'},
    {'key': 'mobilier_jardin',  'label': '🪑 Mobilier jardin'},
    {'key': 'arrosage',         'label': '💧 Arrosage'},
  ],
  'office': [
    {'key': 'fournitures',      'label': '📎 Fournitures'},
    {'key': 'mobilier_bureau',  'label': '🗃️ Mobilier bureau'},
    {'key': 'equipements',      'label': '🖨️ Équipements'},
  ],
  'industry': [
    {'key': 'machines',         'label': '🏭 Machines'},
    {'key': 'emballage',        'label': '📦 Emballage'},
    {'key': 'agriculture',      'label': '🌾 Agriculture'},
  ],
  'security': [
    {'key': 'surveillance',     'label': '📹 Surveillance'},
    {'key': 'serrurerie',       'label': '🔐 Serrurerie'},
    {'key': 'protection',       'label': '🦺 Protection'},
  ],
  'baby': [
    {'key': 'puericulture',     'label': '🍼 Puériculture'},
    {'key': 'alimentation_bebe','label': '🥛 Alimentation'},
    {'key': 'hygiene_bebe',     'label': '🧴 Hygiène'},
    {'key': 'jouets_eveil',     'label': '🧸 Jouets d\'éveil'},
  ],
  'toys': [
    {'key': 'jeux_enfants',         'label': '🎲 Jeux enfants'},
    {'key': 'jeux_electroniques',   'label': '🎮 Jeux élec.'},
    {'key': 'plein_air',            'label': '🛴 Plein air'},
  ],
  'pets': [
    {'key': 'chiens_chats',     'label': '🐾 Animaux'},
    {'key': 'veterinaire',      'label': '🩺 Vétérinaire'},
  ],
  'food': [
    {'key': 'epicerie',         'label': '🛒 Épicerie'},
    {'key': 'boissons',         'label': '🥤 Boissons'},
    {'key': 'condiments',       'label': '🧂 Condiments'},
  ],
};

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

  Future<void> _fetchProducts({bool append = false}) async {
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
      };
      if (widget.categoryKey.isNotEmpty) params['category'] = widget.categoryKey;
      if (_selectedSubcat != null) params['subcategory'] = _selectedSubcat!;

      final uri = Uri.parse('${ApiConfig.baseUrl}/products').replace(
        queryParameters: params,
      );
      final response = await http.get(uri);

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoading = true);
    await _fetchProducts(append: true);
  }

  List<Product> _getSortedProducts() {
    final sorted = List<Product>.from(_products);
    switch (_sortBy) {
      case 'price_asc':
        sorted.sort((a, b) => (double.tryParse(a.price) ?? 0).compareTo(double.tryParse(b.price) ?? 0));
        break;
      case 'price_desc':
        sorted.sort((a, b) => (double.tryParse(b.price) ?? 0).compareTo(double.tryParse(a.price) ?? 0));
        break;
      case 'popular':
        sorted.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        break;
      default: break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final sortedProducts = _getSortedProducts();
    final oliFiltered = _filteredOliProducts;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            if (widget.categoryIcon != null) ...[
              Icon(widget.categoryIcon, size: 20, color: const Color(0xFFFF6B00)),
              const SizedBox(width: 8),
            ],
            Text(widget.categoryLabel,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_selectedSubcat != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 16, color: Colors.white38),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _subcats.firstWhere(
                    (s) => s['key'] == _selectedSubcat,
                    orElse: () => {'label': ''},
                  )['label']!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFFF6B00)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Colors.white70),
            color: const Color(0xFF21262D),
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => [
              _buildSortItem('recent',     'Plus récents',      Icons.access_time),
              _buildSortItem('price_asc',  'Prix croissant',    Icons.arrow_upward),
              _buildSortItem('price_desc', 'Prix décroissant',  Icons.arrow_downward),
              _buildSortItem('popular',    'Plus populaires',   Icons.trending_up),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Chips sous-catégories ──────────────────────────────────────────
          if (_subcats.isNotEmpty) _buildSubcatChips(),

          // ── Contenu (OLI + marketplace) ───────────────────────────────────
          Expanded(
            child: _isLoading && _products.isEmpty && oliFiltered.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
                : _products.isEmpty && oliFiltered.isEmpty
                    ? _buildEmptyState()
                    : CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          // Sélection OLI
                          if (oliFiltered.isNotEmpty)
                            SliverToBoxAdapter(child: _buildOliSection(oliFiltered)),

                          // Compteur marketplace
                          if (_products.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                color: const Color(0xFF161B22),
                                child: Text(
                                  '${_products.length} produit${_products.length > 1 ? 's' : ''} sur le marché',
                                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                                ),
                              ),
                            ),

                          // Grille marketplace
                          SliverPadding(
                            padding: const EdgeInsets.all(10),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.62,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index >= sortedProducts.length) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFFF6B00), strokeWidth: 2),
                                      ),
                                    );
                                  }
                                  return _buildProductCard(sortedProducts[index]);
                                },
                                childCount: sortedProducts.length + (_hasMore ? 1 : 0),
                              ),
                            ),
                          ),

                          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ── Chips sous-catégories ──────────────────────────────────────────────────
  Widget _buildSubcatChips() {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            // Chip "Tout"
            _buildChip(null, '🔍 Tout'),
            ..._subcats.map((s) => _buildChip(s['key'], s['label']!)),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String? key, String label) {
    final selected = _selectedSubcat == key;
    return GestureDetector(
      onTap: () => _selectSubcat(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF6B00) : const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF6B00)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── Section Sélection OLI ──────────────────────────────────────────────────
  Widget _buildOliSection(List<Product> oliProducts) {
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    return Container(
      color: const Color(0xFF0D1117),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFFAA00)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Sélection OLI',
                          style: TextStyle(color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('${oliProducts.length} article${oliProducts.length > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: oliProducts.length,
              itemBuilder: (context, i) {
                final p = oliProducts[i];
                final price = exchangeNotifier
                    .formatProductPrice(double.tryParse(p.price) ?? 0.0);
                return GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ProductDetailsPage(product: p))),
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 10, bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFFF6B00).withOpacity(0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(12)),
                          child: SizedBox(
                            height: 110, width: double.infinity,
                            child: p.images.isNotEmpty
                                ? Image.network(
                                    CloudinaryHelper.thumbnail(p.images.first),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _imgPlaceholder())
                                : _imgPlaceholder(),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white,
                                        fontSize: 11, fontWeight: FontWeight.w600,
                                        height: 1.3)),
                                const Spacer(),
                                Text(price,
                                    style: const TextStyle(
                                        color: Color(0xFFFF6B00), fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                if (p.subcategory != null) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      p.subcategory!.replaceAll('_', ' '),
                                      style: const TextStyle(
                                          color: Colors.white38, fontSize: 9),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
        ],
      ),
    );
  }

  // ── Carte produit marketplace ──────────────────────────────────────────────
  Widget _buildProductCard(Product product) {
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    final formattedPrice =
        exchangeNotifier.formatProductPrice(double.tryParse(product.price) ?? 0.0);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: product.images.isNotEmpty
                    ? Image.network(
                        CloudinaryHelper.thumbnail(product.images.first),
                        fit: BoxFit.cover, width: double.infinity,
                        errorBuilder: (_, __, ___) => _imgPlaceholder())
                    : _imgPlaceholder(),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w600, height: 1.3)),
                    const SizedBox(height: 4),
                    Text(formattedPrice,
                        style: const TextStyle(color: Colors.blueAccent,
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Row(children: [
                      Icon(
                        product.sellerIsVerified ? Icons.verified : Icons.storefront,
                        size: 12,
                        color: product.sellerIsVerified ? Colors.blue : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(product.seller, maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        color: const Color(0xFF21262D),
        child: const Icon(Icons.image, color: Colors.white24, size: 36),
      );

  PopupMenuItem<String> _buildSortItem(String value, String label, IconData icon) {
    final sel = _sortBy == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: sel ? Colors.blueAccent : Colors.white54),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: sel ? Colors.blueAccent : Colors.white,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(widget.categoryIcon ?? Icons.category, size: 64,
            color: Colors.white.withOpacity(0.15)),
        const SizedBox(height: 16),
        Text('Aucun produit dans "${widget.categoryLabel}"',
            style: const TextStyle(color: Colors.white54, fontSize: 16,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        const Text('Les produits apparaîtront ici dès qu\'ils seront ajoutés',
            style: TextStyle(color: Colors.white30, fontSize: 13)),
      ]),
    );
  }
}
