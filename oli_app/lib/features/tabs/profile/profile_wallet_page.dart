import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/theme_provider.dart';
import '../../auth/providers/auth_controller.dart';
import '../../user/providers/profile_controller.dart';
import '../../user/providers/user_activity_provider.dart';
import '../../user/widgets/edit_name_dialog.dart';
import '../../user/widgets/visited_products_section.dart';
import '../../user/screens/addresses_page.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../wallet/screens/wallet_screen.dart';

// Imports des pages (Legacy - à migrer progressivement si nécessaire)
import '../../../pages/publish_article_page.dart';
import '../../../pages/purchases_page.dart';
import '../../../pages/favorites_page.dart';
import '../../../pages/settings_page.dart';
import '../../../pages/help_page.dart';
import '../../../pages/about_page.dart';
import '../../../pages/payment_methods_page.dart';

class ProfileAndWalletPage extends ConsumerWidget {
  const ProfileAndWalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final walletState = ref.watch(walletProvider);
    final isDarkMode = ref.watch(themeProvider);
    final user = authState.userData ?? {};
    
    // Oli Blue Branding
    const oliBlue = Color(0xFF1E7DBA);
    final bgColor = isDarkMode ? Colors.black : const Color(0xFFF5F5F5);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    // Load wallet data and visited products
    ref.listen(authControllerProvider, (prev, next) {
      if (next.isAuthenticated) {
        Future.microtask(() {
          ref.read(walletProvider.notifier).loadWalletData();
          ref.read(userActivityProvider.notifier).fetchVisitedProducts();
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
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // 1. HEADER AMÉLIORÉ avec Wallet Ultra-Visible
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
                    Row(
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: () => ref.read(profileControllerProvider.notifier).updateAvatar(),
                          child: Stack(
                            children: [
                              Container(
                                width: 70, height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  image: user['avatar_url'] != null
                                      ? DecorationImage(
                                          image: NetworkImage(user['avatar_url']),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: user['avatar_url'] == null
                                    ? const Icon(Icons.person, color: Colors.white, size: 40)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 12, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // User Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user["name"] ?? "Utilisateur Oli",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => EditNameDialog(
                                          currentName: user["name"] ?? "Utilisateur Oli",
                                        ),
                                      );
                                    },
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Badges Row
                              Row(
                                children: [
                                  _buildBadge(
                                    user['is_admin'] == true ? 'ADMIN' : (user['is_seller'] == true ? 'Vendeur' : 'Membre'),
                                    Colors.white24,
                                  ),
                                  if (user['is_verified'] == true) ...[ 
                                    const SizedBox(width: 8),
                                    _buildBadge('Certifié', Colors.greenAccent.withOpacity(0.2), Colors.greenAccent),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Settings Icon
                        IconButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
                          icon: const Icon(Icons.settings, color: Colors.white),
                        ),
                      ],
                    ),
                    
                    // WALLET ULTRA-VISIBLE
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet, color: Colors.white.withOpacity(0.9), size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                'Solde Wallet',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${walletState.balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: oliBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              elevation: 4,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const WalletScreen()),
                              );
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text(
                              'Recharger',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),


            // 2. MY ORDERS (Alibaba Row)
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Mes Commandes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesPage())),
                            child: Row(
                              children: [
                                Text("Tout voir", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[600]),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildOrderIcon(Icons.payment, "Non Payé", textColor),
                          _buildOrderIcon(Icons.inventory_2_outlined, "À expédier", textColor),
                          _buildOrderIcon(Icons.local_shipping_outlined, "À recevoir", textColor),
                            _buildOrderIcon(Icons.rate_review_outlined, "À noter", textColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2.5 VISITED PRODUCTS SECTION
            const VisitedProductsSection(),
            const SizedBox(height: 16),

            // 3. WALLET & TOOLS GRID
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Services Grid
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Padding(
                           padding: const EdgeInsets.only(left: 16, bottom: 12),
                           child: Text("Mes Outils", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                         ),
                        Wrap(
                          spacing: 0,
                          runSpacing: 20,
                          children: [
                            _buildGridItem(Icons.favorite_border, "Favoris", textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage()))),
                            _buildGridItem(Icons.add_circle_outline, "Vendre", textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishArticlePage()))),
                            _buildGridItem(Icons.credit_card, "Cartes", textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsPage()))),
                            _buildGridItem(Icons.location_on_outlined, "Adresses", textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesPage()))), 
                            _buildGridItem(Icons.help_outline, "Aide", textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpPage()))),
                            _buildGridItem(Icons.info_outline, "À propos", textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()))),
                            _buildGridItem(Icons.logout, "Déconnexion", Colors.redAccent, () async {
                              await ref.read(authControllerProvider.notifier).logout();
                              // Navigation handled by auth state change usually, or simple push
                              if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

  Widget _buildBadge(String text, Color bgColor, [Color textColor = Colors.white]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildOrderIcon(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 28, color: color.withOpacity(0.7)),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.7))),
      ],
    );
  }
  
  Widget _buildGridItem(IconData icon, String label, Color color, VoidCallback onTap) {
    // 4 items par ligne (width / 4)
    return LayoutBuilder(
      builder: (context, constraints) {
        // Largeur approx
        final width = MediaQuery.of(context).size.width / 4 - 10;
        return GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}
