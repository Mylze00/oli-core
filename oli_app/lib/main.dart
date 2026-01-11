import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/screens/login_page.dart'; // Importe votre code avec animations
import 'features/auth/providers/auth_controller.dart';
import 'home/home_page.dart'; // Assurez-vous que ce chemin est correct
import 'theme_provider.dart'; // ✅ Import du provider de thème

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On écoute l'état d'authentification réel de votre contrôleur
    final authState = ref.watch(authControllerProvider);
    // ✅ On écoute le thème persistant
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Oli App',
      debugShowCheckedModeBanner: false,
      // ✅ Thèmes clair et sombre
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF1E7DBA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E7DBA),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1E7DBA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E7DBA),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: themeMode, // ✅ Applique le thème sélectionné
      // LOGIQUE DE ROUTAGE PRINCIPALE
      // Si isAuthenticated est vrai, on va à l'accueil, sinon au Login
      home: authState.isAuthenticated 
          ? const HomePage() 
          : const LoginPage(),
    );
  }
}
