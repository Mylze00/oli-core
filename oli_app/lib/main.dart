import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/screens/login_page.dart'; // Importe votre code avec animations
import 'features/auth/providers/auth_controller.dart';
import 'home/home_page.dart'; // Assurez-vous que ce chemin est correct
import 'theme_provider.dart'; // ✅ Import du provider de thème
import 'features/chat/socket_service.dart'; // Vérifiez votre chemin réel
import 'features/core/user/user_provider.dart'; // Vérifiez votre chemin réel

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
    final authState = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // --- LOGIQUE DE CONNEXION SOCKET OPTIMISÉE ---
    // On utilise next.whenData pour s'assurer que le code ne s'exécute 
    // que lorsque les données utilisateur sont réellement disponibles.
    ref.listen(userProvider, (previous, next) {
      next.whenData((user) {
        if (user != null) {
          debugPrint("🚀 Utilisateur détecté (${user.id}), connexion au Socket...");
          // On utilise user.id.toString() pour éviter tout mismatch de type
          ref.read(socketServiceProvider).connect(user.id.toString());
        } else {
          // Si l'utilisateur est null (déconnexion), on ferme le socket
          debugPrint("🔌 Aucun utilisateur, déconnexion du Socket...");
          ref.read(socketServiceProvider).disconnect();
        }
      });
    });

    return MaterialApp(
      title: 'Oli App',
      debugShowCheckedModeBanner: false,
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
      themeMode: themeMode,
      // La navigation réagit instantanément à l'état d'authentification
      home: authState.isAuthenticated 
          ? const HomePage() 
          : const LoginPage(),
    );
  }
}