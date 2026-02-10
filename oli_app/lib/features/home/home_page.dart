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

  // Tabs principaux (sans le bouton +)
  late List<Widget> _pages; // Removed 'final' to allow reassignment
  int _dashboardKey = 0; // Counter to trigger updates
  
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
        onBecameVisible: () {}, // Callback when visible
      ),
      ConversationsPage(),
      MarketView(),
      ProfileAndWalletPage(),
    ];
  }
  
  void _switchToMarket() {
    setState(() => _currentIndex = 2); // Index 2 = MarketView
  }

  void _onTabSelected(int index) {
    // Bouton +
    if (index == 2) {
      _openPublishPage();
      return;
    }

    // Décalage d'index après le bouton +
    final adjustedIndex = index > 2 ? index - 1 : index;

    setState(() {
      // Réinitialiser les filtres de recherche si retour à l'accueil (index 0)
      if (adjustedIndex == 0 && _currentIndex != 0) {
        ref.read(searchFiltersProvider.notifier).reset();
        // Increment key to force dashboard widget rebuild and clear search bar
        _dashboardKey++;
        _buildPages(); // Rebuild pages list within setState
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_circle, size: 30),
            label: '+',
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
