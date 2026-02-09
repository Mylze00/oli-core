import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// Firebase disabled for web build (incompatible versions)
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'features/auth/login_page.dart';
import 'features/auth/otp_page.dart';
import 'features/auth/providers/auth_controller.dart';
import 'features/home/home_shell.dart';
import 'features/orders/order_details_page.dart';

/// Handler pour messages FCM en background (doit être top-level)
// Firebase disabled for web build
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   debugPrint('📩 [FCM] Message background: ${message.notification?.title}');
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase disabled for web build
  // await Firebase.initializeApp();
  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const ProviderScope(child: OliDeliveryApp()));
}

/// Bridge entre Riverpod AuthState et GoRouter refreshListenable
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._ref) {
    _ref.listen<AuthState>(authControllerProvider, (_, __) {
      notifyListeners();
    });
  }
  final Ref _ref;
}

/// GoRouter créé UNE SEULE FOIS via Riverpod — plus jamais dans build()
final goRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = AuthNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);

      // Autoriser /otp même si pas connecté
      if (state.matchedLocation == '/otp') return null;

      final isLoggingIn = state.matchedLocation == '/login';

      // En cours de vérification de session
      if (authState.isCheckingSession) return null;

      // Pas connecté et pas sur login → redirige vers login
      if (!authState.isAuthenticated && !isLoggingIn) return '/login';

      // Connecté et sur login → redirige vers dashboard
      if (authState.isAuthenticated && isLoggingIn) return '/dashboard';

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
        builder: (context, state) => const HomeShell(),
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
});

class OliDeliveryApp extends ConsumerWidget {
  const OliDeliveryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

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
