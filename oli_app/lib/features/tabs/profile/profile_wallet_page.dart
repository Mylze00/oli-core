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
import 'widgets/order_status_bar.dart';
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
              // 1. HEADER (Blue Background + Avatar + Info)
              Container(
                padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [oliBlue, oliBlue.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    ProfileHeader(user: user),
                    
                    const SizedBox(height: 24),
                    
                    // Wallet Card (Inserted here to overlap header slightly if needed, but keeping inside for now)
                    const WalletSummaryCard(),
                  ],
                ),
              ),

              // 2. MY ORDERS (Alibaba Row)
              Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OrderStatusBar(cardColor: cardColor, textColor: textColor),
                ),
              ),

              // 2.5 VISITED PRODUCTS SECTION
              const VisitedProductsSection(),
              const SizedBox(height: 16),

              // 3. TOOLS GRID
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ProfileToolsGrid(cardColor: cardColor, textColor: textColor),
              ),
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
