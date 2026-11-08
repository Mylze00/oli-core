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
import 'network_status_indicator.dart';
import '../../../../core/theme/oli_colors.dart';

class HomeAppBar extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final Function(String) onSearch;
  final List<Product> allProducts;
  final List<Product> verifiedShopsProducts;
  final bool isScrolled;
  final VoidCallback? onSwitchToProfile;

  const HomeAppBar({
    super.key,
    required this.searchCtrl,
    required this.onSearch,
    required this.allProducts,
    required this.verifiedShopsProducts,
    this.isScrolled = false,
    this.onSwitchToProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isDark = ref.watch(themeProvider);

    return SliverAppBar(
      pinned: true,
      floating: false,
      toolbarHeight: 76, // Augmentation pour éviter le chevauchement
      backgroundColor: isDark ? Colors.black : Colors.white,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Padding(
        padding: const EdgeInsets.only(top: 20.0), // Pousse le contenu vers le bas
        child: Row(
          children: [
            GestureDetector(
              onTap: onSwitchToProfile,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AutoRefreshAvatar(
                    avatarUrl: authState.userData?['avatar_url'],
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 70),
                    child: Text(
                      authState.userData?['name'] ?? 'Utilisateur',
                      style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87, fontSize: 12),
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
            ),
            // Le logo est maintenant dans le même conteneur que le titre et les actions pour éviter tout chevauchement
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 38,
                ),
              ),
            ),
          ],
        ),
      ),
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient de base
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [Colors.blue, Colors.black]
                    : [const Color(0xFF1E7DBA), OliLightColors.background],
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
                  color: isDark
                      ? Colors.black.withOpacity(0.45)
                      : Colors.white.withOpacity(0.80),
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
        Padding(
          padding: const EdgeInsets.only(top: 20.0, right: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              NetworkStatusIndicator(),
              SizedBox(width: 6),
              CurrencySelectorWidget(),
            ],
          ),
        ),
        // Bouton bascule thème clair / sombre
        Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Consumer(
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
                    color: isDark ? Colors.white : Colors.black87,
                    size: 24,
                  ),
                ),
                onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Consumer(
            builder: (context, ref, child) {
              final notificationState = ref.watch(notificationProvider);
              final unreadCount = notificationState.unreadCount;
  
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_outlined,
                        color: isDark ? Colors.white : Colors.black87, size: 24),
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
        ),
      ],
    );
  }
}
