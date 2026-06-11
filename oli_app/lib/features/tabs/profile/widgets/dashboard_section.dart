import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../orders/providers/orders_provider.dart';
import '../../../orders/screens/purchases_page.dart';
import '../../../favorites/screens/favorites_page.dart';
import '../../../sales/providers/seller_orders_provider.dart';
import '../../../sales/screens/my_sales_page.dart';
import '../../../shop/screens/publish_article_page.dart';
import '../../../shop/screens/my_shops_screen.dart';
import '../../../wallet/screens/wallet_screen.dart';
import '../../../notifications/screens/notifications_view.dart';
import '../../../notifications/providers/notification_provider.dart';
import '../../../settings/screens/settings_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashboardSection — MON TABLEAU DE BORD
// ─────────────────────────────────────────────────────────────────────────────
class DashboardSection extends ConsumerStatefulWidget {
  const DashboardSection({super.key});

  @override
  ConsumerState<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends ConsumerState<DashboardSection>
    with SingleTickerProviderStateMixin {
  // 0 = Acheteur, 1 = Vendeur
  int _selectedTab = 0;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (_selectedTab == index) return;
    _controller.reset();
    setState(() => _selectedTab = index);
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carte glassmorphism — hauteur augmentée de 20% (240px)
        SizedBox(
          height: 240,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ── Toggle Acheteur / Vendeur ──────────────────────────
                    _GlassToggle(
                      selectedTab: _selectedTab,
                      onTabChanged: _switchTab,
                    ),
                    // ── Grille d'icônes ────────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: _selectedTab == 0
                              ? _BuyerGrid(context: context, ref: ref)
                              : _SellerGrid(context: context, ref: ref),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle Acheteur / Vendeur — style glassmorphism iOS
// ─────────────────────────────────────────────────────────────────────────────
class _GlassToggle extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const _GlassToggle({required this.selectedTab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          _ToggleItem(
            icon: Icons.shopping_cart_outlined,
            label: 'Acheteur',
            isActive: selectedTab == 0,
            onTap: () => onTabChanged(0),
          ),
          _ToggleItem(
            icon: Icons.storefront_outlined,
            label: 'Vendeur',
            isActive: selectedTab == 1,
            onTap: () => onTabChanged(1),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF1E7DBA).withOpacity(0.85)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF1E7DBA).withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : Colors.white54,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white54,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grille Acheteur
// ─────────────────────────────────────────────────────────────────────────────
class _BuyerGrid extends StatelessWidget {
  final BuildContext context;
  final WidgetRef ref;

  const _BuyerGrid({required this.context, required this.ref});

  @override
  Widget build(BuildContext wCtx) {
    final ordersAsync = ref.watch(ordersProvider);
    final notificationState = ref.watch(notificationProvider);

    int total = 0;
    int inProgress = 0;
    int delivered = 0;

    ordersAsync.whenData((orders) {
      total = orders.length;
      inProgress = orders
          .where((o) =>
              ['paid', 'processing', 'shipped'].contains(o.status))
          .length;
      delivered =
          orders.where((o) => o.status == 'delivered').length;
    });

    return _IconGrid(items: [
      _DashItem(
        icon: Icons.receipt_long_outlined,
        label: 'Mes\nCommandes',
        count: total,
        countColor: const Color(0xFF1E7DBA),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PurchasesPage())),
      ),
      _DashItem(
        icon: Icons.local_shipping_outlined,
        label: 'En Cours',
        count: inProgress,
        countColor: const Color(0xFFF59E0B),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PurchasesPage())),
      ),
      _DashItem(
        icon: Icons.check_circle_outline,
        label: 'Livrées',
        count: delivered,
        countColor: const Color(0xFF22C55E),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PurchasesPage())),
      ),
      _DashItem(
        icon: Icons.favorite_border_rounded,
        label: 'Mes Favoris',
        heartBadge: true,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const FavoritesPage())),
      ),
      _DashItem(
        icon: Icons.notifications_outlined,
        label: 'Alertes',
        count: notificationState.unreadCount,
        countColor: Colors.red,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NotificationsView())),
      ),
      _DashItem(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Portefeuille',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WalletScreen())),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grille Vendeur
// ─────────────────────────────────────────────────────────────────────────────
class _SellerGrid extends StatelessWidget {
  final BuildContext context;
  final WidgetRef ref;

  const _SellerGrid({required this.context, required this.ref});

  @override
  Widget build(BuildContext wCtx) {
    final sellerState = ref.watch(sellerOrdersProvider);

    final pending = sellerState.statusCounts['paid'] ?? 0;
    final processing = sellerState.statusCounts['processing'] ?? 0;
    final shipped = sellerState.statusCounts['shipped'] ?? 0;

    return _IconGrid(items: [
      _DashItem(
        icon: Icons.inbox_outlined,
        label: 'Commandes\nReçues',
        count: pending,
        countColor: const Color(0xFFF59E0B),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MySalesPage())),
      ),
      _DashItem(
        icon: Icons.inventory_2_outlined,
        label: 'En\nTraitement',
        count: processing,
        countColor: const Color(0xFF1E7DBA),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MySalesPage())),
      ),
      _DashItem(
        icon: Icons.local_shipping_outlined,
        label: 'Expédiées',
        count: shipped,
        countColor: const Color(0xFF22C55E),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MySalesPage())),
      ),
      _DashItem(
        icon: Icons.add_box_outlined,
        label: 'Publier\nArticle',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const PublishArticlePage())),
      ),
      _DashItem(
        icon: Icons.storefront_outlined,
        label: 'Ma Boutique',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MyShopsScreen())),
      ),
      _DashItem(
        icon: Icons.settings_outlined,
        label: 'Paramètres',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SettingsPage())),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout grille 3 colonnes x N lignes
// ─────────────────────────────────────────────────────────────────────────────
class _IconGrid extends StatelessWidget {
  final List<_DashItem> items;
  const _IconGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 3) {
      final rowItems = items.sublist(i, (i + 3).clamp(0, items.length));
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowItems.map((item) => _DashIconWidget(item: item)).toList(),
      ));
      if (i + 3 < items.length) const SizedBox(height: 14);
    }
    return Column(
      children: rows
          .expand((row) => [row, const SizedBox(height: 14)])
          .toList()
        ..removeLast(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modèle de données d'un item du dashboard
// ─────────────────────────────────────────────────────────────────────────────
class _DashItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int count;
  final Color countColor;
  final bool heartBadge;

  const _DashItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count = 0,
    this.countColor = const Color(0xFF1E7DBA),
    this.heartBadge = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget d'une icône du dashboard — style iOS glass
// ─────────────────────────────────────────────────────────────────────────────
class _DashIconWidget extends StatefulWidget {
  final _DashItem item;
  const _DashIconWidget({required this.item});

  @override
  State<_DashIconWidget> createState() => _DashIconWidgetState();
}

class _DashIconWidgetState extends State<_DashIconWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
        lowerBound: 0.0,
        upperBound: 1.0);
    _scale = Tween<double>(begin: 1.0, end: 0.90).animate(
        CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final showBadge = item.count > 0 || item.heartBadge;

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) {
          _press.reverse();
          item.onTap();
        },
        onTapCancel: () => _press.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            children: [
              // Carré glassmorphism avec icône
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          item.icon,
                          size: 18,
                          color: Colors.white.withOpacity(0.88),
                        ),
                      ),
                    ),
                  ),

                  // Badge compteur ou ❤️
                  if (showBadge)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: item.heartBadge
                              ? Colors.redAccent
                              : item.countColor,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: (item.heartBadge
                                      ? Colors.red
                                      : item.countColor)
                                  .withOpacity(0.4),
                              blurRadius: 6,
                            )
                          ],
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Center(
                          child: item.heartBadge
                              ? const Icon(Icons.favorite,
                                  size: 8, color: Colors.white)
                              : Text(
                                  item.count > 99 ? '99+' : '${item.count}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 7),

              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.80),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
