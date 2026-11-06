import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../marketplace/providers/market_provider.dart';
import '../../../marketplace/presentation/pages/product_details_page.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../utils/cloudinary_helper.dart';

const String _kFontFamily = 'CreatoDisplay';

/// Page « Top du classement » — produits des grands magasins locaux vérifiés.
/// Disposition : en-tête, catégorie, onglets (comme la maquette « Top du classement »),
/// grille 2 colonnes avec badge « Vérifié » (comme la maquette « Grands Magasins »), teinte bleue.
class SuperOffresPage extends ConsumerStatefulWidget {
  const SuperOffresPage({super.key});

  @override
  ConsumerState<SuperOffresPage> createState() => _SuperOffresPageState();
}

class _SuperOffresPageState extends ConsumerState<SuperOffresPage> {
  // Palette bleue
  static const Color _bgTop = Color(0xFF0A1A33);
  static const Color _bgBottom = Color(0xFF060D1A);
  static const Color _card = Color(0xFF0F2140);
  static const Color _accent = Color(0xFF1E88E5);
  static const Color _priceBlue = Color(0xFF64B5F6);
  static const Color _muted = Color(0xFF8FA6C8);

  int _selectedTabIndex = 0; // 0 Tous, 1 Ventes à la Une, 2 Les plus populaires
  String _selectedCategory = 'Toutes les catégories';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'Toutes les catégories',
    'Électronique',
    'Mode',
    'Maison',
    'Alimentation',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Mélange mis en cache tant que la source ne change pas (évite un ordre qui bouge à chaque clic)
  List<Product>? _diversifiedCache;
  List<Product>? _diversifiedFrom;

  /// Produits de boutiques certifiées, tirés au hasard et répartis entre les magasins :
  /// un produit par magasin à tour de rôle, dans un ordre aléatoire.
  List<Product> _diversified(List<Product> source) {
    if (identical(source, _diversifiedFrom) && _diversifiedCache != null) {
      return _diversifiedCache!;
    }
    final rnd = Random();
    var certified = source.where((p) => p.shopVerified).toList();
    if (certified.isEmpty) certified = List<Product>.from(source);

    final byStore = <String, List<Product>>{};
    for (final p in certified) {
      final key = p.shopId ?? p.shopName ?? p.sellerId;
      byStore.putIfAbsent(key, () => <Product>[]).add(p);
    }
    for (final group in byStore.values) {
      group.shuffle(rnd);
    }
    final stores = byStore.keys.toList()..shuffle(rnd);

    final out = <Product>[];
    for (var i = 0; ; i++) {
      var added = false;
      for (final store in stores) {
        final group = byStore[store]!;
        if (i < group.length) {
          out.add(group[i]);
          added = true;
        }
      }
      if (!added) break;
    }

    _diversifiedFrom = source;
    _diversifiedCache = out;
    return out;
  }

  List<Product> _filter(List<Product> source) {
    var list = List<Product>.from(_diversified(source));

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(query)).toList();
    }

    if (_selectedCategory != 'Toutes les catégories') {
      list = list.where((p) => (p.category ?? '').toLowerCase().contains(_selectedCategory.toLowerCase())).toList();
    }

    switch (_selectedTabIndex) {
      case 1:
        list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        break;
      case 2:
        list.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final shopProducts = ref.watch(verifiedShopsProductsProvider);
    final products = _filter(shopProducts);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: _kFontFamily),
      ),
      child: Scaffold(
        backgroundColor: _bgBottom,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
              stops: [0.0, 0.35],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildCategoryPicker(),
                _buildTabs(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${products.length} produits',
                        style: const TextStyle(color: _muted, fontSize: 12)),
                  ),
                ),
                Expanded(child: _buildGrid(products, shopProducts.isEmpty)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un produit…',
                      hintStyle: TextStyle(color: _muted),
                      border: InputBorder.none,
                    ),
                  )
                : const Text(
                    'Top du classement',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded, color: Colors.white),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchController.clear();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: PopupMenuButton<String>(
        onSelected: (v) => setState(() => _selectedCategory = v),
        color: _card,
        itemBuilder: (_) => _categories
            .map((c) => PopupMenuItem<String>(
                  value: c,
                  child: Text(c, style: const TextStyle(color: Colors.white)),
                ))
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_selectedCategory, style: const TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down_rounded, color: _priceBlue, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    const labels = ['Tous', 'Ventes à la Une', 'Les plus populaires'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: List.generate(labels.length, (i) {
            final selected = i == _selectedTabIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTabIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? _accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: selected ? Colors.white : _muted,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildGrid(List<Product> products, bool stillLoading) {
    if (products.isEmpty) {
      return Center(
        child: Text(
          stillLoading ? 'Chargement des grands magasins…' : 'Aucun produit trouvé',
          style: const TextStyle(color: _muted),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => _ShopProductCard(product: products[index]),
    );
  }
}

/// Carte produit : visuel (qualité accueil), badge « Vérifié », nom, prix bleu, boutique.
class _ShopProductCard extends ConsumerWidget {
  final Product product;
  const _ShopProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(exchangeRateProvider);
    final price = ref
        .read(exchangeRateProvider.notifier)
        .formatProductPrice(double.tryParse(product.price) ?? 0.0);
    final shopLabel = (product.shopName != null && product.shopName!.isNotEmpty)
        ? product.shopName!
        : 'Boutique Entreprise';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _SuperOffresPageStyle.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  product.images.isEmpty
                      ? const Center(child: Icon(Icons.image, size: 36, color: Colors.grey))
                      : Image.network(
                          CloudinaryHelper.card(product.images.first),
                          fit: BoxFit.cover,
                          cacheWidth: 540,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image, size: 28, color: Colors.grey)),
                        ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 10, color: Colors.white),
                          SizedBox(width: 2),
                          Text('Vérifié', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _SuperOffresPageStyle.priceBlue, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.store, size: 10, color: _SuperOffresPageStyle.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          shopLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _SuperOffresPageStyle.muted, fontSize: 10),
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

/// Couleurs partagées par la carte (la carte est hors de la classe de page).
class _SuperOffresPageStyle {
  static const Color card = Color(0xFF0F2140);
  static const Color priceBlue = Color(0xFF64B5F6);
  static const Color muted = Color(0xFF8FA6C8);
}
