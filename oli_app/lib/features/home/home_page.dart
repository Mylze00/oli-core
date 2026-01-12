import 'package:flutter/material.dart';

import '../tabs/dashboard/dashboard_view.dart';
import '../tabs/messaging/messaging_view.dart';
import '../tabs/market/market_view.dart';
import '../tabs/profile/profile_wallet_page.dart';
import '../../pages/publish_article_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // Tabs principaux (sans le bouton +)
  late final List<Widget> _pages = [
    MainDashboardView(),
    MessagingView(),
    MarketView(),
    ProfileAndWalletPage(),
  ];

  void _onTabSelected(int index) {
    // Bouton +
    if (index == 2) {
      _openPublishPage();
      return;
    }

    // Décalage d’index après le bouton +
    final adjustedIndex = index > 2 ? index - 1 : index;

    setState(() => _currentIndex = adjustedIndex);
  }

  void _openPublishPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublishArticlePage()),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle, size: 30),
            label: '+',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store_outlined),
            label: 'Marché',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Moi',
          ),
        ],
      ),
    );
  }
}
