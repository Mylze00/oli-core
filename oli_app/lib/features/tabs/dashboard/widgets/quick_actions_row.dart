import 'package:flutter/material.dart';
import '../../../marketplace/presentation/pages/all_categories_page.dart';
import '../../../services/request_product_page.dart';
import '../../../services/services_page.dart';
import '../../../services/miniapps_page.dart';
import '../../../services/live_shopping_page.dart';

class QuickActionsRow extends StatelessWidget {
  final VoidCallback? onCategoryTap;

  const QuickActionsRow({super.key, this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          _buildQuickActionCard(context, "Catégorie", Icons.grid_view, Colors.orange, () {
              if (onCategoryTap != null) {
                onCategoryTap!();
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AllCategoriesPage()));
              }
          }),
          _buildQuickActionCard(context, "Demande", Icons.campaign, Colors.blue, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestProductPage()));
          }),
          _buildQuickActionCard(context, "Service", Icons.public, Colors.green, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesPage()));
          }),
          _buildQuickActionCard(context, "Mini-app", Icons.apps, Colors.purple, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MiniAppsPage()));
          }),
          _buildQuickActionCard(context, "Live", Icons.live_tv, Colors.red, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveShoppingPage()));
          }),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05), // Fond subtil
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
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.normal)
            ),
          ],
        ),
      ),
    );
  }
}
