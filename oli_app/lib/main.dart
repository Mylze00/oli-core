import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/screens/login_page.dart';
import 'features/home/home_page.dart';
import 'features/auth/providers/auth_controller.dart';

void main() {
  runApp(const ProviderScope(child: OliApp()));
}

class OliApp extends ConsumerWidget {
  const OliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Oli App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        useMaterial3: true,
        primaryColor: const Color(0xFF1E7DBA),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E7DBA),
          primary: const Color(0xFF1E7DBA),
        ),
      ),
      home: _getHomeWidget(authState),
    );
  }

  Widget _getHomeWidget(AuthState state) {
    if (state.isAuthenticated) {
      return const HomePage();
    }
    
    // Si on n'est pas authentifié, on montre Login
    // Note: On pourrait ajouter un Splash si state.isLoading est vrai au début
    if (state.isCheckingSession) {
      // Optionnel: Splash screen pendant la vérification du token
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const LoginPage();
  }
}