import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/login_page.dart';
import 'features/auth/otp_page.dart';
import 'features/auth/providers/auth_controller.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/orders/order_details_page.dart';

void main() {
  runApp(const ProviderScope(child: OliDeliveryApp()));
}

class OliDeliveryApp extends ConsumerWidget {
  const OliDeliveryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✨ OPTIMISATION: On ne regarde QUE si l'état d'auth change
    final isAuthenticated = ref.watch(authControllerProvider.select((s) => s.isAuthenticated));
    final isCheckingSession = ref.watch(authControllerProvider.select((s) => s.isCheckingSession));

    // Router configuration avec auth guard
    final router = GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final isLoggedIn = isAuthenticated;
        
        // Autoriser /otp même si pas connecté
        if (state.matchedLocation == '/otp') return null;
        
        final isLoggingIn = state.matchedLocation == '/login';

        // En cours de vérification de session
        if (isCheckingSession) return null;

        // Pas connecté et pas sur login → redirige vers login
        if (!isLoggedIn && !isLoggingIn) return '/login';

        // Connecté et sur login → redirige vers dashboard
        if (isLoggedIn && isLoggingIn) return '/dashboard';

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/otp',
          builder: (context, state) {
            final phone = state.extra as String? ?? '';
            return OtpPage(phone: phone);
          },
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/order/:id',
          builder: (context, state) {
            final orderId = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
            return OrderDetailsPage(orderId: orderId);
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Oli Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E7DBA),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E7DBA),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      routerConfig: router,
    );
  }
}
