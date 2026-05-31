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
          _buildAnimatedLiveActionCard(context, isDark, "Live", () {
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

  Widget _buildAnimatedLiveActionCard(BuildContext context, bool isDark, String title, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 1.0, end: 1.15),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              onEnd: () {
                // To make it loop, we'd need a StatefulWidget. 
                // But a simple TweenAnimationBuilder doesn't loop natively without rebuilding.
                // For a proper loop without converting QuickActionsRow to stateful:
              },
              child: _LivePulseIcon(isDark: isDark),
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
                  fontWeight: FontWeight.bold), // Bold for Live
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePulseIcon extends StatefulWidget {
  final bool isDark;
  const _LivePulseIcon({required this.isDark});

  @override
  State<_LivePulseIcon> createState() => _LivePulseIconState();
}

class _LivePulseIconState extends State<_LivePulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.06),
        shape: BoxShape.circle,
      ),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: const Icon(Icons.live_tv, color: Colors.redAccent, size: 24),
      ),
    );
  }
}

