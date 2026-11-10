import 'features/live_shopping/widgets/video_publish_banner.dart';
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
import 'core/services/database_helper.dart'; // SQLite
import 'app/theme/theme_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'features/chat/call_screen.dart';
import 'firebase_options.dart';
import 'core/router/network/dio_provider.dart';
import 'core/theme/oli_colors.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

// Ouvrir CallScreen depuis n'importe quel contexte (FCM, Socket)
void openIncomingCallScreen(Map<String, String> callData) {
  final context = globalNavigatorKey.currentContext;
  final callerId = callData['callerId'] ?? '';
  // Le même appel arrive par la connexion en direct et par la notification
  if (context == null || ActiveCall.peerId != null) return;
  ActiveCall.peerId = callerId;

  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => CallScreen(
        otherId:        callerId,
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

  // Initialiser la base de données SQLite (Migration SharedPreferences incluse)
  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint('⚠️ Erreur critique initialisation SQLite : $e');
  }
  
  
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
      child: ProviderScope(
        // Bug #1 fix: Override forceLogoutCallbackProvider pour que dioProvider
        // puisse déclencher la déconnexion sans dépendance circulaire.
        overrides: [
          forceLogoutCallbackProvider.overrideWith((ref) {
            return () => ref.read(authControllerProvider.notifier).forceLogout();
          }),
        ],
        child: const OliApp(),
      ),
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
      builder: (context, child) => VideoPublishBanner(child: child ?? const SizedBox.shrink()),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        fontFamily: 'CreatoDisplay',
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF1E7DBA),
        scaffoldBackgroundColor: OliLightColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E7DBA),
          primary: const Color(0xFF1E7DBA),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        fontFamily: 'CreatoDisplay',
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
  late AnimationController _breatheCtrl;
  late Animation<double> _breatheAnim;

  late AnimationController _zoomCtrl;
  late Animation<double> _zoomAnim;
  late Animation<double> _sloganOpacityAnim;

  bool _minDelayPassed = false;
  bool _isTransitioning = false;
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();

    // 1. Effet de respiration continu (inchangé)
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _breatheAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );
    _breatheCtrl.repeat(reverse: true);

    // 2. Effet de zoom élastique : anticipation puis explosion vers l'avant (Traversée directe 3-B)
    _zoomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _zoomAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.75).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 28.0, // Phase 1 : Léger recul d'anticipation (~210ms)
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.75, end: 26.0).chain(CurveTween(curve: Curves.easeInQuart)),
        weight: 72.0, // Phase 2 : Explosion continue vers l'avant (~540ms)
      ),
    ]).animate(_zoomCtrl);

    // 3. Disparition rapide du slogan dès le début de l'anticipation
    _sloganOpacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _zoomCtrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    // Respiration du logo pendant 3 secondes avant l'explosion
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        _minDelayPassed = true;
        _checkAndTriggerTransition();
      }
    });

    // Sécurité maximale : après 6 secondes, on débloque quoi qu'il arrive
    Future.delayed(const Duration(milliseconds: 6000), () {
      if (mounted && !_isTransitioning) {
        _triggerZoomAndExit();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SplashWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dès que la session finit d'être vérifiée en arrière-plan, vérifier si on peut lancer la transition
    if (!widget.authState.isCheckingSession) {
      _checkAndTriggerTransition();
    }
  }

  void _checkAndTriggerTransition() {
    if (_minDelayPassed && !widget.authState.isCheckingSession && !_isTransitioning) {
      _triggerZoomAndExit();
    }
  }

  void _triggerZoomAndExit() {
    if (_isTransitioning || !mounted) return;
    _isTransitioning = true;
    _breatheCtrl.stop(); // Stoppe la respiration pour consacrer toute la fluidité au zoom

    _zoomCtrl.forward().then((_) {
      if (mounted) {
        setState(() {
          _splashDone = true;
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

  @override
  Widget build(BuildContext context) {
    final destination = widget.authState.isAuthenticated
        ? const HomePage()
        : const LoginPage();

    if (_splashDone) {
      return destination;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Pré-chargement en arrière-plan de HomePage/LoginPage PENDANT la respiration
          // Élimine totalement le gel de 1 à 2 secondes à la fin du zoom
          if (!widget.authState.isCheckingSession)
            destination,

          // 2. Écran Splash noir avec le logo
          Container(
            color: Colors.black,
            child: Stack(
              children: [
                // Logo centré avec zoom continu sans jamais disparaître
                Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_breatheCtrl, _zoomCtrl]),
                    builder: (context, child) {
                      final scale = _isTransitioning
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

                // Slogan en bas qui s'efface immédiatement dès le début du zoom
                Positioned(
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _zoomCtrl,
                    builder: (context, child) {
                      final opacity = _isTransitioning
                          ? _sloganOpacityAnim.value
                          : 1.0;
                      return Opacity(
                        opacity: opacity,
                        child: child,
                      );
                    },
                    // FittedBox : le slogan s'adapte aux écrans étroits sans déborder
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Tout en un clic',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'LetterMagic',
                            fontSize: 24,
                            color: Color.fromRGBO(255, 255, 255, 0.8),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}