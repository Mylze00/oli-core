import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'features/auth/screens/login_page.dart';
import 'features/home/home_page.dart';
import 'features/auth/providers/auth_controller.dart';
import 'core/services/fcm_service.dart';
import 'core/services/hive_cache_service.dart';
import 'app/theme/theme_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'features/chat/call_screen.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

// Ouvrir CallScreen depuis n'importe quel contexte (FCM, Socket)
void openIncomingCallScreen(Map<String, String> callData) {
  final context = globalNavigatorKey.currentContext;
  if (context == null) return;
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => CallScreen(
        otherId:        callData['callerId'] ?? '',
        otherName:      callData['callerName'] ?? 'Utilisateur OLI',
        otherAvatarUrl: callData['callerAvatar'],
        conversationId: callData['conversationId'],
        isVideoCall:    callData['callType'] == 'video',
        isIncoming:     true,
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser le cache hors-ligne
  await HiveCacheService.init(); // [CACHE]
  
  // Initialiser Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Enregistrer le handler pour les messages en arrière-plan
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Brancher le callback d'appel entrant sur le navigateur global
  FcmService().onIncomingCall = openIncomingCallScreen;

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
    final isDark = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Oli App',
      navigatorKey: globalNavigatorKey,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        fontFamily: 'Inter',
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF1E7DBA),
        scaffoldBackgroundColor: const Color(0xFFD9D9D9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E7DBA),
          primary: const Color(0xFF1E7DBA),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        fontFamily: 'Inter',
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1E7DBA),
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E7DBA),
          primary: const Color(0xFF1E7DBA),
          brightness: Brightness.dark,
        ),
      ),
      home: _getHomeWidget(authState),
      routes: {
        '/login': (context) => const LoginPage(),
      },
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
    with TickerProviderStateMixin {
  bool _minDelayPassed = false;
  late AnimationController _breatheCtrl;
  late Animation<double> _breatheAnim;

  late AnimationController _zoomCtrl;
  late Animation<double> _zoomAnim;

  @override
  void initState() {
    super.initState();

    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _breatheAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );
    _breatheCtrl.repeat(reverse: true);

    _zoomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _zoomAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.65).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35.0, // Rétraction pendant ~300ms
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.65, end: 35.0).chain(CurveTween(curve: Curves.easeInExpo)),
        weight: 65.0, // Zoom avant géant
      ),
    ]).animate(_zoomCtrl);

    // Attente de 3 secondes (vérification connexion arrière-plan implicite)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _zoomCtrl.forward().then((_) {
          if (mounted) setState(() => _minDelayPassed = true);
        });
      }
    });
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _zoomCtrl.dispose();
    super.dispose();
  }

  bool get _readyToLeave =>
      _minDelayPassed && !widget.authState.isCheckingSession;

  @override
  Widget build(BuildContext context) {
    if (!_readyToLeave) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Logo centré
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_breatheCtrl, _zoomCtrl]),
                builder: (context, child) {
                  // Si l'animation de transition (zoom) a démarré, elle prend le dessus
                  final scale = _zoomCtrl.isAnimating || _zoomCtrl.isCompleted
                      ? _zoomAnim.value
                      : _breatheAnim.value;
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Hero(
                  tag: 'oli_logo',
                  child: SvgPicture.asset(
                    'assets/images/logo - Copie (1).svg',
                    width: 140,
                    height: 140,
                  ),
                ),
              ),
            ),
            // Texte en bas de page
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _zoomCtrl,
                builder: (context, child) {
                  // Le texte disparait rapidement dès que le zoom démarre
                  double opacity = 1.0 - (_zoomCtrl.value * 2.0);
                  if (opacity < 0) opacity = 0;
                  return Opacity(
                    opacity: opacity,
                    child: child,
                  );
                },
                child: const Text(
                  'Simple, Rapide, Sûr',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'LetterMagic',
                    fontSize: 24,
                    color: Color.fromRGBO(255, 255, 255, 0.8),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
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