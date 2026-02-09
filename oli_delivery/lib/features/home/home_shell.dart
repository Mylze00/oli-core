import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/push_notification_service.dart';
import '../../services/socket_service.dart';
import '../auth/providers/auth_controller.dart';
import '../dashboard/dashboard_page.dart';
import '../profile/profile_page.dart';
import '../tasks/my_tasks_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;

  static const _titles = ['Livraisons Disponibles', 'Mes Tâches', 'Mon Profil'];

  final _pages = const [
    DashboardPage(),
    MyTasksPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initServices());
  }

  void _initServices() {
    final authState = ref.read(authControllerProvider);
    if (authState.isAuthenticated && authState.userData != null) {
      final phone = authState.userData!['phone'];
      if (phone != null) {
        ref.read(socketServiceProvider).connect(phone.toString());
      }
      // Init FCM push notifications
      ref.read(pushNotificationServiceProvider).init();
    }
  }

  @override
  void dispose() {
    final socketService = ref.read(socketServiceProvider);
    socketService.off('new_delivery_available');
    socketService.disconnect();
    super.dispose();
  }

  void _logout() async {
    // Unregister FCM token before logout
    await ref.read(pushNotificationServiceProvider).unregister();
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Disponibles',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Mes Tâches',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
