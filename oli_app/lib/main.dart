import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/screens/login_page.dart'; 
import 'features/auth/providers/auth_controller.dart';
import 'home/home_page.dart'; 
import 'theme_provider.dart'; 

// --- CHEMINS CORRIGÉS SELON VOS RÉSULTATS FIND ---
import 'chat/socket_service.dart'; 
import 'core/user/user_provider.dart'; 

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

    // --- LOGIQUE DE CONNEXION SOCKET ---
    ref.listen(userProvider, (previous, next) {
      // Utilisation de whenData pour une gestion propre de l'AsyncValue
      next.whenData((user) {
        if (user != null) {
          debugPrint("🚀 Utilisateur détecté (${user.id}), connexion au Socket...");
          ref.read(socketServiceProvider).connect(user.id.toString());
        } else {
          debugPrint("🔌 Déconnexion du Socket (Utilisateur null)");
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
      home: authState.isAuthenticated 
          ? const HomePage() 
          : const LoginPage(),
    );
  }
}