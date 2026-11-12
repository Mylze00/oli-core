import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../user/providers/favorites_provider.dart';
import '../../marketplace/presentation/widgets/market_product_card.dart';
import '../../../core/theme/oli_surface.dart';

/// Page "Favoris et Suivis"
/// Refactorisée pour utiliser le FavoritesProvider
class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final surface = OliSurface.of(context);

    return Scaffold(
      backgroundColor: surface.background,
      appBar: surface.appBar(
        'Mes favoris',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(color: surface.tile, borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(color: OliSurface.oliBlue, borderRadius: BorderRadius.circular(10)),
              indicatorPadding: const EdgeInsets.all(3),
              labelColor: Colors.white,
              unselectedLabelColor: surface.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: [
                Tab(text: 'Produits (${favorites.length})'),
                const Tab(text: 'Vendeurs'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          favorites.isEmpty
              ? const OliEmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'Aucun favori',
                  subtitle: 'Les produits que vous aimez apparaîtront ici',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) => MarketProductCard(product: favorites[index]),
                ),
          const OliEmptyState(
            icon: Icons.storefront_outlined,
            title: 'Vendeurs suivis',
            subtitle: 'Le suivi des vendeurs arrive bientôt',
          ),
        ],
      ),
    );
  }
}
