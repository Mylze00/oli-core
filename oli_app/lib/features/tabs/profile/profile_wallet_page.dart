import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/theme_provider.dart';
import '../../auth/providers/auth_controller.dart';
import '../../user/providers/profile_controller.dart';
import '../../user/providers/user_activity_provider.dart';
import '../../user/providers/address_provider.dart';
import '../../wallet/providers/wallet_provider.dart';

// Widgets Refactorisés
import 'widgets/profile_header.dart';
import 'widgets/wallet_summary_card.dart';
import 'widgets/dashboard_section.dart';
import 'widgets/profile_tools_grid.dart';
import '../../user/widgets/visited_products_section.dart';

class ProfileAndWalletPage extends ConsumerWidget {
  const ProfileAndWalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isDarkMode = ref.watch(themeProvider);
    final user = authState.userData ?? {};
    
    // Oli Blue Branding
    const oliBlue = Color(0xFF1E7DBA);
    final bgColor = isDarkMode ? Colors.black : const Color(0xFFF5F5F5);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    // Load wallet data, visited products and addresses
    ref.listen(authControllerProvider, (prev, next) {
      if (next.isAuthenticated) {
        Future.microtask(() {
          ref.read(walletProvider.notifier).loadWalletData();
          ref.read(userActivityProvider.notifier).fetchVisitedProducts();
          final notifier = ref.read(addressProvider.notifier);
          if (notifier.mounted) notifier.loadAddresses();
        });
      }
    });

    if (!authState.isAuthenticated) {
      return _buildLoginPrompt(context, oliBlue);
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authControllerProvider.notifier).fetchUserProfile();
          await ref.read(walletProvider.notifier).loadWalletData();
          await ref.read(userActivityProvider.notifier).fetchVisitedProducts();
          final notifier = ref.read(addressProvider.notifier);
          if (notifier.mounted) await notifier.loadAddresses();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // 1. HEADER (Background Image) & WALLET
              Stack(
                children: [
                  // Image de fond
                  Container(
                    height: 280,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/super_offers_bg.jpg'), // Placeholder en attendant kinshasa_skyline
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                  ),
                  // Dégradé sombre pour la lisibilité
                  Container(
                    height: 280,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.2), bgColor],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Contenu principal (Header + Wallet)
                  Padding(
                    padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 10),
                    child: Column(
                      children: [
                        ProfileHeader(user: user),
                        const SizedBox(height: 24),
                        const WalletSummaryCard(),
                      ],
                    ),
                  ),
                ],
              ),

              // 2. NOUVEAU DASHBOARD (Commandes & Suivi)
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: DashboardSection(),
              ),

              // 3. OUTILS & PARAMÈTRES
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ProfileToolsGrid(cardColor: cardColor, textColor: textColor),
              ),
              const SizedBox(height: 20),

              // 4. RÉCEMMENT CONSULTÉS
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "RÉCEMMENT CONSULTÉS",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const VisitedProductsSection(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context, Color primaryColor) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text("Connectez-vous pour voir votre profil", style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text("Se connecter"),
            ),
          ],
        ),
      ),
    );
  }
}
