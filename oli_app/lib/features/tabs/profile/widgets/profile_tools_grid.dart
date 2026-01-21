import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/providers/auth_controller.dart';

import '../../../shop/screens/publish_article_page.dart';
import '../../../favorites/screens/favorites_page.dart';
import '../../../settings/screens/help_page.dart';
import '../../../settings/screens/about_page.dart';
import '../../../checkout/screens/payment_methods_page.dart';
import '../../../user/screens/addresses_page.dart';

class ProfileToolsGrid extends ConsumerWidget {
  final Color cardColor;
  final Color textColor;

  const ProfileToolsGrid({super.key, required this.cardColor, required this.textColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
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
              _buildGridItem(context, Icons.favorite_border, "Favoris", textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage()))),
              _buildGridItem(context, Icons.add_circle_outline, "Vendre", textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishArticlePage()))),
              _buildGridItem(context, Icons.credit_card, "Cartes", textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsPage()))),
              _buildGridItem(context, Icons.location_on_outlined, "Adresses", textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesPage()))), 
              _buildGridItem(context, Icons.help_outline, "Aide", textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpPage()))),
              _buildGridItem(context, Icons.info_outline, "À propos", textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()))),
              _buildGridItem(context, Icons.logout, "Déconnexion", Colors.redAccent, () async {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = MediaQuery.of(context).size.width / 4; // Removed -10 to use full width roughly
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
