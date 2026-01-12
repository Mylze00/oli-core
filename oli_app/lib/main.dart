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

    // --- LOGIQUE DE CONNEXION SOCKET ---
    // On écoute le userProvider. Dès qu'un utilisateur est chargé (non null),
    // on lance la connexion au Socket.
    ref.listen(userProvider, (previous, next) {
      final user = next.value; // On récupère la valeur de l'AsyncValue
      if (user != null) {
        debugPrint("🚀 Utilisateur détecté (${user.id}), connexion au Socket...");
        ref.read(socketServiceProvider).connect(user.id.toString());
      }
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
