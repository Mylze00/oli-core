import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/providers/auth_controller.dart';

import '../../../shop/screens/publish_article_page.dart';
import '../../../favorites/screens/favorites_page.dart';
import '../../../settings/screens/help_page.dart';
import '../../../settings/screens/about_page.dart';
import '../../../settings/screens/contact_support_page.dart';
import '../../../checkout/screens/payment_methods_page.dart';
import '../../../user/screens/addresses_page.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../settings/screens/settings_page.dart';

class ProfileToolsGrid extends ConsumerWidget {
  final Color cardColor;
  final Color textColor;

  const ProfileToolsGrid({super.key, required this.cardColor, required this.textColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            GestureDetector(
              onTap: () {
                // Accéder à tous les paramètres (Settings)
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
              child: const Icon(Icons.menu, size: 20, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Boîte Blanche avec les 4 icônes principales
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToolIcon(
                context, 
                Icons.location_on_outlined, 
                "Adresses", 
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesPage())),
              ),
              _buildToolIcon(
                context, 
                Icons.support_agent_outlined, 
                "Service Client", 
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactSupportPage())),
              ),
              _buildToolIcon(
                context, 
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, 
                "Mode Sombre", 
                () => ref.read(themeProvider.notifier).toggleTheme(),
              ),
              _buildToolIcon(
                context, 
                Icons.language_outlined, 
                "Langue/Devise", 
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolIcon(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 75,
        child: Column(
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
