import 'package:oli_app/core/widgets/oli_image.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../core/theme/oli_surface.dart';
import '../../../models/product_model.dart';
import '../../../providers/exchange_rate_provider.dart';
import '../../marketplace/presentation/widgets/market_product_grid.dart';
import '../models/search_filter_model.dart';
import '../providers/search_filters_provider.dart';
import '../providers/search_history_provider.dart';
import '../widgets/search_filters_sheet.dart';
import '../widgets/product_request_widget.dart';

/// Tri des résultats.
enum _Sort {
  priceAsc('Prix croissant', 'price_asc'),
  priceDesc('Prix décroissant', 'price_desc'),
  relevance('Pertinence', null),
  recent('Récents', 'recent');

  final String label;

  /// Tri demandé au serveur (null : ordre du serveur, puis pertinence par lot).
  final String? serverSort;
  const _Sort(this.label, this.serverSort);
}

/// Résultats de recherche (depuis l'accueil, le Marché…).
///
/// Recherche serveur sur tout le catalogue (nom, description, catégorie), par lots
/// de 20 pendant le défilement, sans doublon. Catégorie et prix sont filtrés par le
/// serveur ; vendeur, localisation, stock et boutiques vérifiées sur les résultats chargés.
/// Même design que la validation de commande et le Marché (grille, bleu Oli).
/// Tri par défaut : prix croissant. Images légères pour économiser les données.
class SearchResultsPage extends ConsumerStatefulWidget {
  final String initialQuery;

  const SearchResultsPage({super.key, required this.initialQuery});

  @override
  ConsumerState<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends ConsumerState<SearchResultsPage> {
  static const _pageSize = 20;

  late final TextEditingController _searchController = TextEditingController(text: widget.initialQuery);
  final ScrollController _scroll = ScrollController();

  String _query = '';
  /// Par défaut : du moins cher au plus cher, tant que l'utilisateur ne change pas le tri.
  _Sort _sort = _Sort.priceAsc;
  final List<Product> _results = [];
  final Set<String> _seen = {};
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _fuzzyUsed = false;
  String? _suggestedTerm;

  /// Jeton de la recherche en cours : une réponse arrivée trop tard est ignorée.
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Chaque recherche repart sans les filtres de la précédente
    Future.microtask(() {
      if (!mounted) return;
      ref.read(searchFiltersProvider.notifier).reset();
      _search(widget.initialQuery);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _isLoading || _isLoadingMore || !_hasMore) return;
    if (_scroll.position.extentAfter < 1200) _loadPage(append: true);
  }

  /// Nouvelle recherche (nouveaux mots, tri ou filtres serveur).
  Future<void> _search(String query) async {
    final q = query.trim();
    _query = q;
    if (q.isNotEmpty) ref.read(searchHistoryProvider.notifier).add(q);
    setState(() {
      _results.clear();
      _seen.clear();
      _offset = 0;
      _hasMore = q.isNotEmpty;
      _fuzzyUsed = false;
      _suggestedTerm = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (q.isEmpty) return;
    await _loadPage(append: false);
  }

  Future<void> _loadPage({required bool append}) async {
    final token = ++_searchToken;
    setState(() => append ? _isLoadingMore = true : _isLoading = true);
    final filters = ref.read(searchFiltersProvider);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/products').replace(queryParameters: {
        'search': _query,
        'limit': '$_pageSize',
        'offset': '$_offset',
        if (_sort.serverSort != null) 'sort': _sort.serverSort!,
        if (filters.category != null) 'category': filters.category!,
        if (filters.minPrice != null) 'minPrice': '${filters.minPrice}',
        if (filters.maxPrice != null) 'maxPrice': '${filters.maxPrice}',
      });
      final response = await http.get(uri);
      if (token != _searchToken || !mounted) return;
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

      final decoded = jsonDecode(response.body);
      final List<dynamic> data = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> && decoded['products'] is List ? decoded['products'] : const []);
      final batch = <Product>[];
      for (final json in data) {
        try {
          final p = Product.fromJson(json);
          if (_seen.add(p.id)) batch.add(p);
        } catch (_) {}
      }
      if (_sort == _Sort.relevance) _sortByRelevance(batch);

      setState(() {
        _results.addAll(batch);
        _offset += data.length;
        _hasMore = data.length >= _pageSize;
        if (!append && decoded is Map<String, dynamic>) {
          _fuzzyUsed = decoded['fuzzy_used'] == true;
          _suggestedTerm = decoded['suggested_term'] as String?;
        }
      });
    } catch (e) {
      debugPrint('❌ Recherche : $e');
      if (mounted && token == _searchToken) setState(() => _hasMore = false);
    } finally {
      if (mounted && token == _searchToken) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  /// Pertinence (à l'intérieur d'un lot, pour que les produits déjà vus ne bougent pas) :
  /// nom qui commence par la recherche, puis par son premier mot, puis tous les mots
  /// dans le nom, puis popularité.
  void _sortByRelevance(List<Product> list) {
    final q = _query.toLowerCase();
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    int score(Product p) {
      final name = p.name.toLowerCase();
      if (name.startsWith(q)) return 3;
      if (words.isNotEmpty && name.startsWith(words.first)) return 2;
      if (words.every(name.contains)) return 1;
      return 0;
    }

    list.sort((a, b) {
      final diff = score(b) - score(a);
      return diff != 0 ? diff : b.viewCount.compareTo(a.viewCount);
    });
  }

  /// Filtres appliqués aux résultats chargés (vendeur, localisation, stock, vérifiées).
  List<Product> get _visible {
    final f = ref.read(searchFiltersProvider);
    return _results.where((p) {
      if (f.verifiedShopsOnly == true && !(p.shopVerified || p.sellerHasCertifiedShop)) return false;
      if (f.inStockOnly == true && p.quantity <= 0) return false;
      if (f.sellerName != null && p.seller.toLowerCase() != f.sellerName!.toLowerCase()) return false;
      if (f.location != null && !(p.location ?? '').toLowerCase().contains(f.location!.toLowerCase())) return false;
      return true;
    }).toList();
  }

  /// Vendeurs présents dans les résultats, du plus représenté au moins représenté.
  List<({String name, String? avatar, int count, bool verified})> get _sellers {
    final map = <String, ({String name, String? avatar, int count, bool verified})>{};
    for (final p in _results) {
      final name = p.seller.trim();
      if (name.isEmpty || name == 'Anonyme') continue;
      final prev = map[name];
      map[name] = (
        name: name,
        avatar: prev?.avatar ?? p.sellerAvatar,
        count: (prev?.count ?? 0) + 1,
        verified: (prev?.verified ?? false) || p.sellerIsVerified || p.sellerHasCertifiedShop,
      );
    }
    final list = map.values.toList()..sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  Future<void> _openFilters() async {
    String? before(SearchFilters f) => '${f.category}|${f.minPrice}|${f.maxPrice}';
    final previous = before(ref.read(searchFiltersProvider));
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SearchFiltersSheet(
        availableCategories: _results.map((p) => p.category ?? '').where((c) => c.isNotEmpty).toSet().toList()..sort(),
        availableSellers: _sellers.map((s) => s.name).toList(),
        availableLocations:
            _results.map((p) => p.location ?? '').where((l) => l.isNotEmpty).toSet().toList()..sort(),
        maxProductPrice: _maxPrice(),
      ),
    );
    if (!mounted) return;
    // Catégorie ou prix changés : nouvelle recherche serveur ; sinon simple refiltrage
    if (before(ref.read(searchFiltersProvider)) != previous) {
      _search(_query);
    } else {
      setState(() {});
    }
  }

  double _maxPrice() {
    var maxP = 0.0;
    for (final p in _results) {
      final price = double.tryParse(p.price) ?? 0;
      if (price > maxP) maxP = price;
    }
    return maxP <= 0 ? 1000 : (maxP / 100).ceilToDouble() * 100;
  }

  @override
  Widget build(BuildContext context) {
    final surface = OliSurface.of(context);
    final filters = ref.watch(searchFiltersProvider);
    ref.watch(exchangeRateProvider);
    final visible = _visible;

    return Scaffold(
      backgroundColor: surface.background,
      appBar: AppBar(
        backgroundColor: surface.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: surface.text,
        elevation: 0,
        titleSpacing: 0,
        title: _buildSearchField(surface),
        actions: [_buildFilterButton(surface, filters), const SizedBox(width: 4)],
      ),
      body: RefreshIndicator(
        color: surface.accent,
        onRefresh: () => _search(_query),
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(child: _buildSortChips(surface)),
            if (_fuzzyUsed && _suggestedTerm != null && !_isLoading)
              SliverToBoxAdapter(child: _buildFuzzyBanner(surface)),
            if (filters.hasActiveFilters) SliverToBoxAdapter(child: _buildActiveFilters(surface, filters)),
            if (_isLoading && _results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: surface.accent)),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState(surface))
            else ...[
              SliverToBoxAdapter(child: _buildCount(surface, visible.length)),
              if (_sellers.length > 1 && filters.sellerName == null) SliverToBoxAdapter(child: _buildSellers(surface)),
              MarketProductGrid(
                products: visible,
                lowData: true,
                isStoreProduct: (p) => p.sellerAccountType == 'entreprise' || p.sellerHasCertifiedShop,
              ),
              if (_isLoadingMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: surface.accent),
                      ),
                    ),
                  ),
                ),
              if (!_hasMore && visible.length > 6)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('Fin des résultats', style: TextStyle(color: surface.textSecondary, fontSize: 12)),
                    ),
                  ),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // ─── Barre du haut ─────────────────────────────────────────────────

  Widget _buildSearchField(OliSurface surface) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(color: surface.tile, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: surface.text, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Rechercher un produit, une boutique…',
          hintStyle: TextStyle(color: surface.textSecondary, fontSize: 14),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search_rounded, color: surface.textSecondary, size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Icon(Icons.close_rounded, color: surface.textSecondary, size: 18),
                    onPressed: _searchController.clear,
                  ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
        onSubmitted: _search,
      ),
    );
  }

  Widget _buildFilterButton(OliSurface surface, SearchFilters filters) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.tune_rounded, color: surface.text),
          tooltip: 'Filtres',
          onPressed: _openFilters,
        ),
        if (filters.hasActiveFilters)
          Positioned(
            right: 6,
            top: 8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: OliSurface.oliBlue, borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: Text('${filters.activeFiltersCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  // ─── Tri, correction, filtres actifs ───────────────────────────────

  Widget _buildSortChips(OliSurface surface) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        children: [
          for (final sort in _Sort.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  if (_sort == sort) return;
                  setState(() => _sort = sort);
                  _search(_query);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _sort == sort ? OliSurface.oliBlue : surface.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _sort == sort ? OliSurface.oliBlue : surface.border),
                  ),
                  child: Text(
                    sort.label,
                    style: TextStyle(
                      color: _sort == sort ? Colors.white : surface.text,
                      fontSize: 13,
                      fontWeight: _sort == sort ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFuzzyBanner(OliSurface surface) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(color: surface.tile, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.auto_fix_high_rounded, size: 18, color: surface.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Résultats pour ', style: TextStyle(color: surface.textSecondary)),
                TextSpan(
                    text: '« $_suggestedTerm »',
                    style: TextStyle(color: surface.text, fontWeight: FontWeight.w700)),
              ]),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _fuzzyUsed = false;
              _suggestedTerm = null;
            }),
            child: Text('Masquer', style: TextStyle(color: surface.accent, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters(OliSurface surface, SearchFilters f) {
    final ex = ref.read(exchangeRateProvider.notifier);
    final notifier = ref.read(searchFiltersProvider.notifier);
    final chips = <Widget>[
      if (f.category != null) _chip(surface, Icons.category_outlined, f.category!, () {
        notifier.clearCategory();
        _search(_query);
      }),
      if (f.minPrice != null || f.maxPrice != null)
        _chip(
          surface,
          Icons.payments_outlined,
          '${ex.formatProductPrice(f.minPrice ?? 0)} – ${f.maxPrice == null ? '∞' : ex.formatProductPrice(f.maxPrice!)}',
          () {
            notifier.clearPrice();
            _search(_query);
          },
        ),
      if (f.sellerName != null) _chip(surface, Icons.storefront_outlined, f.sellerName!, () {
        notifier.clearSellerName();
        setState(() {});
      }),
      if (f.location != null) _chip(surface, Icons.location_on_outlined, f.location!, () {
        notifier.clearLocation();
        setState(() {});
      }),
      if (f.verifiedShopsOnly == true) _chip(surface, Icons.verified_outlined, 'Boutiques vérifiées', () {
        notifier.clearShopType();
        setState(() {});
      }),
      if (f.inStockOnly == true) _chip(surface, Icons.inventory_2_outlined, 'En stock', () {
        notifier.clearStock();
        setState(() {});
      }),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  Widget _chip(OliSurface surface, IconData icon, String label, VoidCallback onClear) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: OliSurface.oliBlue.withValues(alpha: surface.isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: surface.accent),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: surface.text, fontSize: 12, fontWeight: FontWeight.w600)),
          InkWell(
            onTap: onClear,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 16, color: surface.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Résultats ─────────────────────────────────────────────────────

  Widget _buildCount(OliSurface surface, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$count${_hasMore ? '+' : ''} résultat${count > 1 ? 's' : ''}',
              style: TextStyle(color: surface.text, fontWeight: FontWeight.w700)),
          TextSpan(text: ' pour « $_query »', style: TextStyle(color: surface.textSecondary)),
        ]),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  /// Vendeurs trouvés : toucher un vendeur n'affiche que ses produits.
  Widget _buildSellers(OliSurface surface) {
    final sellers = _sellers.take(12).toList();
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: sellers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final s = sellers[i];
          return GestureDetector(
            onTap: () {
              ref.read(searchFiltersProvider.notifier).setSellerName(s.name);
              setState(() {});
              if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
            },
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: surface.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: s.avatar != null && s.avatar!.isNotEmpty
                            ? OliImage.network(s.avatar!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _initial(s.name))
                            : _initial(s.name),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: OliSurface.oliBlue,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: surface.background, width: 2),
                          ),
                          child: Text('${s.count}',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: surface.text, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      if (s.verified) ...[
                        const SizedBox(width: 2),
                        Icon(Icons.verified_rounded, size: 11, color: surface.accent),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _initial(String name) => Center(
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: OliSurface.oliBlue, fontWeight: FontWeight.w700, fontSize: 18)),
      );

  Widget _buildEmptyState(OliSurface surface) {
    final history = ref.watch(searchHistoryProvider).where((h) => h.toLowerCase() != _query.toLowerCase()).take(6);
    if (_query.isEmpty) {
      return const OliEmptyState(icon: Icons.search_rounded, title: 'Que cherchez-vous ?');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          OliEmptyState(
            icon: Icons.search_off_rounded,
            title: 'Aucun produit pour « $_query »',
            subtitle: 'Essayez un autre mot, ou demandez ce produit aux vendeurs',
          ),
          if (history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in history)
                    ActionChip(
                      label: Text(h, style: TextStyle(color: surface.text, fontSize: 12)),
                      avatar: Icon(Icons.history_rounded, size: 14, color: surface.textSecondary),
                      backgroundColor: surface.card,
                      side: BorderSide(color: surface.border),
                      onPressed: () {
                        _searchController.text = h;
                        _search(h);
                      },
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          ProductRequestWidget(searchQuery: _query),
        ],
      ),
    );
  }
}
