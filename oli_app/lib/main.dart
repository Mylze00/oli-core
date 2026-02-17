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
    return SplashWrapper(authState: state);
  }
}

/// Splash Screen affiché à chaque démarrage
class SplashWrapper extends StatefulWidget {
  final AuthState authState;
  const SplashWrapper({super.key, required this.authState});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper>
    with SingleTickerProviderStateMixin {
  bool _minDelayPassed = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _minDelayPassed = true);
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  bool get _readyToLeave =>
      _minDelayPassed && !widget.authState.isCheckingSession;

  @override
  Widget build(BuildContext context) {
    if (!_readyToLeave) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(
            children: [
              // Spinner centré
              const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white24),
                  ),
                ),
              ),
              // Logo Oli en bas de page
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 80,
                      height: 80,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Simple, Rapide, Congolais',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Splash terminé
    if (widget.authState.isAuthenticated) {
      return const HomePage();
    }
    return const LoginPage();
  }
}