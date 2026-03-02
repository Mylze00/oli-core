import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../marketplace/presentation/pages/all_categories_page.dart';
import '../../../services/request_product_page.dart';
import '../../../services/services_page.dart';
import '../../../services/miniapps_page.dart';
import '../../../oticket/pages/oticket_page.dart';
import '../../../services/live_shopping_page.dart';

import 'service_glass_panel.dart';

class QuickActionsRow extends ConsumerWidget {
  final VoidCallback? onCategoryTap;

  const QuickActionsRow({super.key, this.onCategoryTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          _buildQuickActionCard(context, isDark, "Catégorie", Icons.grid_view, Colors.orange, () {
              if (onCategoryTap != null) {
                onCategoryTap!();
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AllCategoriesPage()));
              }
          }),
          _buildImageActionCard(context, isDark, "Demande", "assets/images/megaphone_icon.png", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestProductPage()));
          }, size: 24.0),
          _buildQuickActionCard(context, isDark, "Service", Icons.public, Colors.blue, () {
            showDialog(
              context: context, 
              builder: (_) => const ServiceGlassPanel(),
            );
          }),
          _buildQuickActionCard(context, isDark, "O-ticket", Icons.confirmation_number, Colors.purple, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OTicketPage()));
          }),
          _buildQuickActionCard(context, isDark, "Live", Icons.live_tv, Colors.red, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveShoppingPage()));
          }),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, bool isDark, String title, IconData icon, Color color, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              title, 
              textAlign: TextAlign.center, 
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.normal)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageActionCard(BuildContext context, bool isDark, String title, String imagePath, VoidCallback? onTap, {double size = 24.0}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                imagePath,
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}
