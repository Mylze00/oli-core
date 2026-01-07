import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'login_page.dart'; // Importe votre code avec animations
import 'auth_controller.dart';
import 'home/home_page.dart'; // Assurez-vous que ce chemin est correct

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

    return MaterialApp(
      title: 'Oli App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF1E7DBA),
      ),
      // LOGIQUE DE ROUTAGE PRINCIPALE
      // Si isAuthenticated est vrai, on va à l'accueil, sinon au Login
      home: authState.isAuthenticated 
          ? const HomePage() 
          : const LoginPage(),
    );
  }
}