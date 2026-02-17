import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../tabs/dashboard/dashboard_view.dart';
import '../chat/conversations_page.dart';
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

  // Tabs principaux (sans le bouton Vendre)
  late List<Widget> _pages;
  int _dashboardKey = 0;
  
  @override
  void initState() {
    super.initState();
    _buildPages();
  }
  
  void _buildPages() {
    _pages = [
      MainDashboardView(
        key: ValueKey(_dashboardKey),
        onSwitchToMarket: () => _switchToMarket(),
        onBecameVisible: () {},
      ),
      ConversationsPage(),
      MarketView(),
      ProfileAndWalletPage(),
    ];
  }
  
  void _switchToMarket() {
    setState(() => _currentIndex = 2);
  }

  void _onTabSelected(int index) {
    // Bouton Vendre (index 2 dans la barre)
    if (index == 2) {
      _openPublishPage();
      return;
    }

    // Décalage d'index après le bouton Vendre
    final adjustedIndex = index > 2 ? index - 1 : index;

    setState(() {
      if (adjustedIndex == 0 && _currentIndex != 0) {
        ref.read(searchFiltersProvider.notifier).reset();
        _dashboardKey++;
        _buildPages();
      }
      
      _currentIndex = adjustedIndex;
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0A0A0A),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex >= 2 ? _currentIndex + 1 : _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _onTabSelected,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_filled),
            label: 'nav.home'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_outlined),
            label: 'nav.chats'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const _AnimatedSellIcon(),
            label: ' ',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.store_outlined),
            label: 'nav.market'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: 'nav.profile'.tr(),
          ),
        ],
      ),
    );
  }
}

/// Bouton animé : flip 3D "page de livre" entre "+" et "Vendre"
/// Change de couleur toutes les 2 secondes
class _AnimatedSellIcon extends StatefulWidget {
  const _AnimatedSellIcon();

  @override
  State<_AnimatedSellIcon> createState() => _AnimatedSellIconState();
}

class _AnimatedSellIconState extends State<_AnimatedSellIcon>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _flipController;
  int _colorIndex = 0;
  bool _showingBack = false;

  static const List<Color> _colors = [
    Colors.blueAccent,
    Colors.orangeAccent,
    Colors.pinkAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
  ];

  @override
  void initState() {
    super.initState();
    
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flipController.addListener(() {
      // À mi-rotation (0.5), on bascule le contenu affiché
      final isBack = _flipController.value >= 0.5;
      if (isBack != _showingBack) {
        setState(() => _showingBack = isBack);
      }
    });

    // Lance le cycle : flip toutes les 2 secondes
    _startFlipCycle();
  }

  void _startFlipCycle() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      
      if (_flipController.isCompleted) {
        // Retourne à "+"
        _flipController.reverse();
      } else if (_flipController.isDismissed) {
        // Change de couleur avant le flip suivant
        setState(() {
          _colorIndex = (_colorIndex + 1) % _colors.length;
        });
        // Va vers "Vendre"
        _flipController.forward();
      }
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colors[_colorIndex];

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
      width: 60,
      height: 30,
      child: AnimatedBuilder(
        animation: _flipController,
        builder: (context, child) {
          final angle = _flipController.value * 3.14159;
          
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: _showingBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.14159),
                    child: Center(
                      child: Text(
                        'Vendre',
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'olive_palm',
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.add,
                      color: color,
                      size: 23,
                    ),
                  ),
          );
        },
      ),
      ),
    );
  }
}

