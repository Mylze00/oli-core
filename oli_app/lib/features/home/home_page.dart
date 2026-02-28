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
import '../search/providers/search_filters_provider.dart';

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
        onBecameVisible: () {},
      ),
      const ConversationsPage(),
      MarketView(),
      const ProfileAndWalletPage(),
    ];
  }

  void _switchToMarket() => setState(() => _currentIndex = 2);

  void _onTabSelected(int index) {
    // index 2 = bouton Vendre (central)
    if (index == 2) {
      _openPublishPage();
      return;
    }
    final adjusted = index > 2 ? index - 1 : index;

    // Si l'utilisateur navigue vers l'onglet Messages → refresh des non-lus
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

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _OliBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        unreadMessages: unreadCount,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom bottom nav bar — style glassmorphism pill (WhatsApp-inspired)
// ─────────────────────────────────────────────────────────────────────────────

class _OliBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadMessages;

  const _OliBottomNav({
    required this.currentIndex,
    required this.onTap,
    this.unreadMessages = 0,
  });

  @override
  Widget build(BuildContext context) {
    // barIndex = position dans la barre (0..4)
    // pageIndex = index dans _pages (-1 = bouton Vendre)
    final items = [
      _NavItem(icon: Icons.home_filled,        label: 'nav.home'.tr(),    barIndex: 0, pageIndex: 0),
      _NavItem(icon: Icons.chat_bubble_outline, label: 'nav.chats'.tr(),   barIndex: 1, pageIndex: 1, badge: unreadMessages),
      _NavItem(icon: null,                     label: ' ',                barIndex: 2, pageIndex: -1, isSell: true),
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
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: items.map((item) {
                  if (item.isSell) {
                    return _SellButton(onTap: () => onTap(item.barIndex));
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône avec badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  item.icon,
                  color: isSelected ? Colors.white : Colors.white54,
                  size: isSelected ? 24 : 22,
                ),
                if (item.badge > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: _Badge(count: item.badge),
                  ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: isSelected
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 6),
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge vert avec nombre
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return AnimatedScale(
      scale: count > 0 ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366), // Vert WhatsApp
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton central "Vendre" — flip 3D animé avec couleurs changeantes
// ─────────────────────────────────────────────────────────────────────────────

class _SellButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SellButton({required this.onTap});

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
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final angle = _ctrl.value * 3.14159;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: _showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.14159),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: color.withOpacity(0.5), width: 1),
                      ),
                      child: Text(
                        'Vendre',
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'olive_palm',
                        ),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: color.withOpacity(0.5), width: 1),
                    ),
                    child: Icon(Icons.add, color: color, size: 22),
                  ),
          );
        },
      ),
    );
  }
}
