import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
import '../../../../widgets/verification_badge.dart';
import 'dynamic_search_bar.dart';
import '../../../../widgets/currency_selector_widget.dart';
import '../../../notifications/providers/notification_provider.dart';
import '../../../notifications/screens/notifications_view.dart';
import '../../../../models/product_model.dart';
import '../providers/shops_provider.dart';
import '../../../../app/theme/theme_provider.dart';

class HomeAppBar extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final Function(String) onSearch;
  final List<Product> allProducts;
  final List<Product> verifiedShopsProducts;

  final bool isScrolled;

  const HomeAppBar({
    super.key,
    required this.searchCtrl,
    required this.onSearch,
    required this.allProducts,
    required this.verifiedShopsProducts,
    this.isScrolled = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: Colors.black,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AutoRefreshAvatar(
            avatarUrl: authState.userData?['avatar_url'],
            size: 32,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              authState.userData?['name'] ?? 'Utilisateur',
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Badge de certification
          if (authState.userData != null && VerificationBadge.fromUser(authState.userData!) != null) ...[
            const SizedBox(width: 4),
            VerificationBadge(
              type: VerificationBadge.fromUser(authState.userData!)!,
              size: 16,
            ),
          ],
        ],
      ),
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient de base
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue, Colors.black],
              ),
            ),
          ),
          // Effet glass iOS au scroll
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isScrolled ? 1.0 : 0.0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                ),
              ),
            ),
          ),
          // Logo toujours visible
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 46,
                ),
              ),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: DynamicSearchBar(
          controller: searchCtrl,
          onSubmitted: onSearch,
          allProducts: allProducts,
        ),
      ),
      actions: [
        const Padding(
          padding: EdgeInsets.only(right: 8.0),
          child: CurrencySelectorWidget(),
        ),
        // Bouton bascule thème clair / sombre
        Consumer(
          builder: (context, ref, _) {
            final isDark = ref.watch(themeProvider);
            return IconButton(
              tooltip: isDark ? 'Passer en mode clair' : 'Passer en mode sombre',
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => RotationTransition(turns: anim, child: child),
                child: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  key: ValueKey(isDark),
                  color: Colors.white,
                  size: 22,
                ),
              ),
              onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            );
          },
        ),
        Consumer(
          builder: (context, ref, child) {
            final notificationState = ref.watch(notificationProvider);
            final unreadCount = notificationState.unreadCount;

            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => NotificationsView()),
                    );
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
