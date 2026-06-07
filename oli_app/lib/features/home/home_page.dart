import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../tabs/dashboard/dashboard_view.dart';
import '../chat/conversations_page.dart';
import '../chat/providers/unread_count_provider.dart';
import '../marketplace/presentation/pages/market_view.dart';
import '../tabs/profile/profile_wallet_page.dart';
import '../shop/screens/publish_article_page.dart';
import '../feed/presentation/create_post_page.dart';
import '../search/providers/search_filters_provider.dart';
import '../../app/theme/theme_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  late List<Widget> _pages;
  final _dashboardStateKey = GlobalKey<MainDashboardViewState>();

  @override
  void initState() {
    super.initState();
    _buildPages();
  }

  void _buildPages() {
    _pages = [
      MainDashboardView(
        key: _dashboardStateKey,
        onSwitchToMarket: () => _switchToMarket(),
        onSwitchToProfile: () => _onTabSelected(4), // Profile tab is index 4 (Moi)
        onBecameVisible: () {},
      ),
      const ConversationsPage(),
      MarketView(),
      const ProfileAndWalletPage(),
    ];
  }

  void _switchToMarket() => setState(() => _currentIndex = 2);

  void _onTabSelected(int index) {
    if (index == 2) {
      _showCreateMenu();
      return;
    }
    final adjusted = index > 2 ? index - 1 : index;

    if (adjusted == 1) {
      ref.read(unreadCountProvider.notifier).refresh();
    }

    if (adjusted == 0 && _currentIndex == 0) {
      _dashboardStateKey.currentState?.scrollToTop();
      return;
    }
    setState(() {
      if (adjusted == 0 && _currentIndex != 0) {
        ref.read(searchFiltersProvider.notifier).reset();
      }
      _currentIndex = adjusted;
    });
  }

  void _openPublishPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PublishArticlePage()),
    );
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        final isDark = ref.watch(themeProvider);
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.black.withOpacity(0.55)
                      : Colors.white.withOpacity(0.85),
                  border: Border.all(
                    color: isDark 
                        ? Colors.white.withOpacity(0.15)
                        : Colors.black.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white30 : Colors.black26,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.storefront, color: Colors.blue),
                      ),
                      title: Text('Vendre un produit', style: TextStyle(fontFamily: 'CreatoDisplay', fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      onTap: () {
                        Navigator.pop(context);
                        _openPublishPage();
                      },
                    ),
                    Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12, indent: 64),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.video_library, color: Colors.red),
                      ),
                      title: Text('Publier une vidéo', style: TextStyle(fontFamily: 'CreatoDisplay', fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage()));
                      },
                    ),
                    Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12, indent: 64),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.dynamic_feed, color: Colors.green),
                      ),
                      title: Text('Publier sur Fil', style: TextStyle(fontFamily: 'CreatoDisplay', fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage()));
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadCountProvider);
    final isDark = ref.watch(themeProvider);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'CreatoDisplay'),
      ),
      child: DefaultTextStyle(
        style: DefaultTextStyle.of(context).style.copyWith(fontFamily: 'CreatoDisplay'),
        child: Scaffold(
          backgroundColor: isDark ? Colors.black : const Color(0xFFD9D9D9),
          extendBody: true,
          body: IndexedStack(index: _currentIndex, children: _pages),
          bottomNavigationBar: _OliBottomNav(
            currentIndex: _currentIndex,
            onTap: _onTabSelected,
            unreadMessages: unreadCount,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom bottom nav bar — glassmorphism pill, labels fixes en bas
// ─────────────────────────────────────────────────────────────────────────────

class _OliBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadMessages;
  final bool isDark;

  const _OliBottomNav({
    required this.currentIndex,
    required this.onTap,
    this.unreadMessages = 0,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.home_filled,        label: 'nav.home'.tr(),    barIndex: 0, pageIndex: 0),
      _NavItem(icon: Icons.chat_bubble_outline, label: 'nav.chats'.tr(),   barIndex: 1, pageIndex: 1, badge: unreadMessages),
      _NavItem(icon: null,                     label: 'Vendre',           barIndex: 2, pageIndex: -1, isSell: true),
      _NavItem(icon: Icons.store_outlined,     label: 'nav.market'.tr(),  barIndex: 3, pageIndex: 2),
      _NavItem(icon: Icons.person_outline,     label: 'nav.profile'.tr(), barIndex: 4, pageIndex: 3),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.50)
                    : Colors.white.withOpacity(0.88),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: isDark
                      ? Colors.black.withOpacity(0.30)
                      : Colors.black.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: items.map((item) {
                  if (item.isSell) {
                    return _SellButton(label: item.label, onTap: () => onTap(item.barIndex));
                  }
                  final isSelected = item.pageIndex == currentIndex;
                  return _NavTabItem(
                    item: item,
                    isSelected: isSelected,
                    onTap: () => onTap(item.barIndex),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData? icon;
  final String label;
  final int barIndex;
  final int pageIndex;
  final bool isSell;
  final int badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.barIndex,
    required this.pageIndex,
    this.isSell = false,
    this.badge = 0,
  });
}

// Onglet standard : icône + label fixe en bas
class _NavTabItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTabItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // isDark est passé depuis _OliBottomNav via la nav bar, on le récupère via le contexte parent
    // On utilise une simple heuristique : la couleur de fond du scaffold
    final brightness = Theme.of(context).brightness;
    final isDarkNav = brightness == Brightness.dark;
    final color = isSelected
        ? (isDarkNav ? Colors.white : Colors.black87)
        : (isDarkNav ? Colors.white54 : Colors.black38);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkNav
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône avec badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(item.icon, color: color, size: 22),
                if (item.badge > 0)
                  Positioned(
                    top: -5,
                    right: -8,
                    child: _Badge(count: item.badge),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            // Label toujours visible
            Text(
              item.label,
              style: TextStyle(
                fontFamily: 'CreatoDisplay',
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge vert
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF25D366),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'CreatoDisplay',
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton "Vendre" central — flip 3D stable, sans bordure, label fixe en bas
// ─────────────────────────────────────────────────────────────────────────────

class _SellButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SellButton({required this.label, required this.onTap});

  @override
  State<_SellButton> createState() => _SellButtonState();
}

class _SellButtonState extends State<_SellButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _colorIdx = 0;
  bool _showBack = false;

  static const _colors = [
    Colors.blueAccent,
    Colors.orangeAccent,
    Colors.pinkAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        final back = _ctrl.value >= 0.5;
        if (back != _showBack) setState(() => _showBack = back);
      });
    _startCycle();
  }

  void _startCycle() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      if (_ctrl.isCompleted) {
        _ctrl.reverse();
      } else if (_ctrl.isDismissed) {
        setState(() => _colorIdx = (_colorIdx + 1) % _colors.length);
        _ctrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colors[_colorIdx];

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zone icône fixe 22×22 — on anime SEULEMENT l'icône à l'intérieur
            SizedBox(
              width: 28,
              height: 28,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final angle = _ctrl.value * 3.14159;
                  // L'icône tourne, mais le SizedBox reste fixe → pas de déplacement
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: _showBack
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(3.14159),
                            child: Icon(
                              Icons.sell_outlined,
                              color: color,
                              size: 22,
                            ),
                          )
                        : Icon(Icons.add, color: color, size: 22),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
