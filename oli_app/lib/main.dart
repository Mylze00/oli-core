import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'features/auth/screens/login_page.dart';
import 'features/home/home_page.dart';
import 'features/auth/providers/auth_controller.dart';
import 'core/services/fcm_service.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Enregistrer le handler pour les messages en arrière-plan
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('fr'), // Français
        Locale('en'), // English
        Locale('ln'), // Lingala
        Locale('sw'), // Swahili
        Locale('kg'), // Kikongo
        Locale('lu'), // Tshiluba
      ],
      path: 'assets/translations',
      startLocale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      child: const ProviderScope(child: OliApp()),
    ),
  );
}

class OliApp extends ConsumerWidget {
  const OliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Oli App',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
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
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E7DBA), Color(0xFF0D4A73)],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Nom de l'app
                Text(
                  'Oli',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Inter',
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Votre marketplace',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 40),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const LoginPage();
  }
}