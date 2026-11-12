import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../orders/providers/orders_provider.dart';
import '../../../orders/screens/purchases_page.dart';
import '../../../user/providers/favorites_provider.dart';
import '../../../favorites/screens/favorites_page.dart';
import '../../../sales/providers/seller_orders_provider.dart';
import '../../../sales/screens/my_sales_page.dart';
import '../../../shop/screens/publish_article_page.dart';
import '../../../shop/screens/my_shops_screen.dart';
import '../../../wallet/screens/wallet_screen.dart';
import '../../../cart/screens/cart_page.dart';
import '../../../cart/providers/cart_provider.dart';
import '../../../settings/screens/settings_page.dart';
import '../../../../core/theme/oli_surface.dart';
import '../../../../providers/exchange_rate_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashboardSection — MON TABLEAU DE BORD
// Toutes les opérations de l'utilisateur, côté acheteur et côté vendeur :
// résumé chiffré, puis accès direct à chaque liste. Même langage visuel que la
// validation de commande, touches de bleu Oli.
// ─────────────────────────────────────────────────────────────────────────────
class DashboardSection extends ConsumerStatefulWidget {
  const DashboardSection({super.key});

  @override
  ConsumerState<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends ConsumerState<DashboardSection> {
  // 0 = Acheteur, 1 = Vendeur
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    // Compteurs à jour à chaque ouverture (avant, ceux du vendeur restaient à 0
    // tant que la page des ventes n'avait pas été ouverte)
    Future.microtask(() {
      if (!mounted) return;
      ref.invalidate(ordersProvider);
      ref.read(sellerOrdersProvider.notifier).loadAll();
    });
  }

  void _switchTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    if (index == 1) ref.read(sellerOrdersProvider.notifier).fetchStats();
  }

  @override
  Widget build(BuildContext context) {
    final s = OliSurface.of(context);
    return Container(
      decoration: s.cardDecoration(radius: 20),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentedToggle(selected: _selectedTab, onChanged: _switchTab),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _selectedTab == 0
                ? const _BuyerDashboard(key: ValueKey('buyer'))
                : const _SellerDashboard(key: ValueKey('seller')),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sélecteur Acheteur / Vendeur
// ─────────────────────────────────────────────────────────────────────────────
class _SegmentedToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _SegmentedToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = OliSurface.of(context);
    Widget item(int index, IconData icon, String label) {
      final active = selected == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: 36,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: active ? OliSurface.oliBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: active
                  ? [BoxShadow(color: OliSurface.oliBlue.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))]
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: active ? Colors.white : s.textSecondary),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      color: active ? Colors.white : s.textSecondary,
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: s.tile, borderRadius: BorderRadius.circular(13)),
      child: Row(
        children: [
          item(0, Icons.shopping_bag_outlined, 'Acheteur'),
          item(1, Icons.storefront_outlined, 'Vendeur'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Côté acheteur
// ─────────────────────────────────────────────────────────────────────────────
class _BuyerDashboard extends ConsumerWidget {
  const _BuyerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(exchangeRateProvider);
    final ex = ref.read(exchangeRateProvider.notifier);
    final orders = ref.watch(ordersProvider).valueOrNull ?? const [];
    final cartCount = ref.watch(cartProvider).fold<int>(0, (sum, item) => sum + item.quantity);
    final favoritesCount = ref.watch(favoritesProvider).length;

    final inProgress = orders.where((o) => PurchaseFilter.inProgress.matches(o.status)).length;
    final delivered = orders.where((o) => PurchaseFilter.delivered.matches(o.status)).length;
    final pendingPayment = orders.where((o) => o.status == 'pending').length;
    // Dépensé = commandes payées (en cours ou livrées)
    final spent = orders
        .where((o) => o.status != 'pending' && o.status != 'cancelled')
        .fold<double>(0, (sum, o) => sum + o.totalAmount);

    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryStrip(items: [
          _Stat('${orders.length}', 'Commandes'),
          _Stat('$inProgress', 'En cours'),
          _Stat(ex.formatProductPrice(spent), 'Dépensé'),
        ]),
        const SizedBox(height: 14),
        _TileGrid(items: [
          _Tile(Icons.receipt_long_outlined, 'Mes commandes', count: pendingPayment > 0 ? pendingPayment : 0,
              hint: pendingPayment > 0 ? 'à payer' : null, onTap: () => open(const PurchasesPage())),
          _Tile(Icons.local_shipping_outlined, 'En cours', count: inProgress,
              onTap: () => open(const PurchasesPage(initialFilter: PurchaseFilter.inProgress))),
          _Tile(Icons.check_circle_outline_rounded, 'Livrées', count: delivered,
              onTap: () => open(const PurchasesPage(initialFilter: PurchaseFilter.delivered))),
          _Tile(Icons.favorite_border_rounded, 'Favoris', count: favoritesCount,
              onTap: () => open(const FavoritesPage())),
          _Tile(Icons.shopping_cart_outlined, 'Panier', count: cartCount, onTap: () => open(const CartPage())),
          _Tile(Icons.account_balance_wallet_outlined, 'Portefeuille', onTap: () => open(const WalletScreen())),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Côté vendeur
// ─────────────────────────────────────────────────────────────────────────────
class _SellerDashboard extends ConsumerWidget {
  const _SellerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(exchangeRateProvider);
    final ex = ref.read(exchangeRateProvider.notifier);
    final state = ref.watch(sellerOrdersProvider);
    final stats = state.stats;
    final counts = state.statusCounts;

    final toProcess = stats?.toProcess ?? counts['paid'] ?? 0;
    final processing = stats?.processing ?? ((counts['processing'] ?? 0) + (counts['ready'] ?? 0));
    final shipped = stats?.shipped ?? counts['shipped'] ?? 0;
    final revenue = stats?.deliveredRevenue ?? 0;

    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryStrip(items: [
          _Stat('$toProcess', 'À traiter'),
          _Stat('${processing + shipped}', 'En cours'),
          _Stat(ex.formatProductPrice(revenue), 'Ventes livrées'),
        ]),
        const SizedBox(height: 14),
        _TileGrid(items: [
          _Tile(Icons.inbox_outlined, 'Reçues', count: toProcess, hint: toProcess > 0 ? 'à traiter' : null,
              onTap: () => open(const MySalesPage(
                    title: 'Commandes reçues',
                    statuses: ['paid'],
                    emptyMessage: 'Aucune nouvelle commande',
                  ))),
          _Tile(Icons.inventory_2_outlined, 'En traitement', count: processing,
              onTap: () => open(const MySalesPage(
                    title: 'En traitement',
                    statuses: ['processing', 'ready'],
                    emptyMessage: 'Aucune commande en traitement',
                  ))),
          _Tile(Icons.local_shipping_outlined, 'Expédiées', count: shipped,
              onTap: () => open(const MySalesPage(
                    title: 'Commandes expédiées',
                    statuses: ['shipped'],
                    emptyMessage: 'Aucune commande expédiée',
                  ))),
          _Tile(Icons.add_box_outlined, 'Publier', onTap: () => open(const PublishArticlePage())),
          _Tile(Icons.storefront_outlined, 'Ma boutique', onTap: () => open(const MyShopsScreen())),
          _Tile(Icons.settings_outlined, 'Paramètres', onTap: () => open(const SettingsPage())),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Résumé chiffré
// ─────────────────────────────────────────────────────────────────────────────
class _Stat {
  final String value;
  final String label;
  const _Stat(this.value, this.label);
}

class _SummaryStrip extends StatelessWidget {
  final List<_Stat> items;
  const _SummaryStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    final s = OliSurface.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(color: s.tile, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Container(width: 1, height: 30, color: s.border),
            Expanded(
              child: Column(
                children: [
                  Text(items[i].value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: s.text, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(items[i].label, style: TextStyle(color: s.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grille de raccourcis (3 colonnes)
// ─────────────────────────────────────────────────────────────────────────────
class _Tile {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int count;
  final String? hint;

  const _Tile(this.icon, this.label, {required this.onTap, this.count = 0, this.hint});
}

class _TileGrid extends StatelessWidget {
  final List<_Tile> items;
  const _TileGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 3) {
      if (i > 0) rows.add(const SizedBox(height: 14));
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items.sublist(i, (i + 3).clamp(0, items.length))) Expanded(child: _TileView(item: item)),
        ],
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _TileView extends StatefulWidget {
  final _Tile item;
  const _TileView({required this.item});

  @override
  State<_TileView> createState() => _TileViewState();
}

class _TileViewState extends State<_TileView> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = OliSurface.of(context);
    final item = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        item.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 100),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: OliSurface.oliBlue.withValues(alpha: s.isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, size: 22, color: s.accent),
                ),
                if (item.count > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: OliSurface.oliBlue,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: s.card, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.count > 99 ? '99+' : '${item.count}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(item.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: s.text, fontSize: 12, fontWeight: FontWeight.w600)),
            if (item.hint != null)
              Text(item.hint!, style: TextStyle(color: s.accent, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
