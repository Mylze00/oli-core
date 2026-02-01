import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
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

  const HomeAppBar({
    super.key,
    required this.searchCtrl,
    required this.onSearch,
    required this.allProducts,
    required this.verifiedShopsProducts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return SliverAppBar(
      backgroundColor: Colors.transparent,
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
        ],
      ),
      flexibleSpace: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue, Colors.black],
              ),
            ),
          ),
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
          productNames: [
            ...allProducts.map((p) => p.name),
            ...verifiedShopsProducts.map((p) => p.name)
          ].take(10).toList(),
        ),
      ),
      actions: [
        const Padding(
          padding: EdgeInsets.only(right: 8.0),
          child: CurrencySelectorWidget(),
        ),
        IconButton(
          icon: Icon(
            ref.watch(themeProvider) ? Icons.light_mode : Icons.dark_mode,
            color: Colors.white,
          ),
          onPressed: () {
            ref.read(themeProvider.notifier).toggleTheme();
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
