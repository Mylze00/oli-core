import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_controller.dart';
import 'otp_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with TickerProviderStateMixin {
  final TextEditingController _phoneController =
      TextEditingController(text: '+243');

  String? _operator;
  bool _isValid = false;
  bool _hasPrefixError = false;

  // Animation controllers
  late AnimationController _shakeController;
  late AnimationController _logoController;
  late AnimationController _breatheController;
  late AnimationController _contentController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _breatheScale;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);

    // 🔄 Shake animation (erreur préfixe)
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // 🎬 Logo entrance animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // 🫁 Logo breathing animation (continu)
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _breatheScale = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(
        parent: _breatheController,
        curve: Curves.easeInOut,
      ),
    );

    // 📝 Content fade-in (champs, boutons)
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: Curves.easeOut,
      ),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Séquence d'animations
    _logoController.forward().then((_) {
      _breatheController.repeat(reverse: true);
      _contentController.forward();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _shakeController.dispose();
    _logoController.dispose();
    _breatheController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  void _onPhoneChanged() {
    final text = _phoneController.text;

    if (!text.startsWith('+243')) {
      _phoneController.text = '+243';
      _phoneController.selection =
          const TextSelection.collapsed(offset: 4);
      return;
    }

    if (text.length < 4) return;

    final digits = text.substring(4);
    final isComplete = digits.length == 9;

    String? detectedOperator;
    bool prefixError = false;

    if (digits.length >= 2) {
      final prefix = digits.substring(0, 2);

      if (['97', '99', '98'].contains(prefix)) {
        detectedOperator = 'Airtel';
      } else if (['81', '82', '83'].contains(prefix)) {
        detectedOperator = 'Vodacom';
      } else if (['84', '85', '89'].contains(prefix)) {
        detectedOperator = 'Orange';
      } else if (['90', '80', '88', '86'].contains(prefix)) {
        detectedOperator = 'Africell';
      } else if (isComplete) {
        prefixError = true;
        if (!_hasPrefixError) _triggerShake();
      }
    }

    setState(() {
      _operator = detectedOperator;
      _hasPrefixError = prefixError;
      _isValid = isComplete && detectedOperator != null;
    });
  }

  String _getOperatorIcon(String operatorName) {
    switch (operatorName.toLowerCase()) {
      case 'vodacom':
        return 'assets/images/operators/mpesa.png';
      case 'airtel':
        return 'assets/images/operators/airtel_money.png';
      case 'orange':
        return 'assets/images/operators/orange_money.png';
      case 'africell':
        return 'assets/images/operators/afrimoney.png';
      default:
        return 'assets/images/operators/mpesa.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF2196C8),
      body: Stack(
        children: [
          // 🎨 FOND — CustomPainter (ovale bleu marine + courbe)
          CustomPaint(
            size: size,
            painter: _BackgroundPainter(),
          ),

          // 📱 CONTENU
          SafeArea(
            child: SizedBox(
              width: size.width,
              height: size.height - MediaQuery.of(context).padding.top,
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // 🔵 LOGO avec Hero + Breathing
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: AnimatedBuilder(
                        animation: _breatheController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _breatheScale.value,
                            child: child,
                          );
                        },
                        child: Hero(
                          tag: 'oli_logo',
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 180,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // 📝 FORMULAIRE (fade-in avec slide)
                  FadeTransition(
                    opacity: _contentFade,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: Column(
                        children: [
                          // Label
                          const Text(
                            'N° Téléphone',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 📞 Champ téléphone avec shake
                          AnimatedBuilder(
                            animation: _shakeController,
                            builder: (context, child) {
                              final sineValue = math.sin(
                                _shakeController.value * math.pi * 4,
                              );
                              return Transform.translate(
                                offset: Offset(
                                  sineValue * 10 * (1 - _shakeController.value),
                                  0,
                                ),
                                child: child,
                              );
                            },
                            child: Container(
                              width: 300,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                maxLength: 13,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0B1727),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\+243\d*'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: '+243',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 18,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(32),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(32),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(32),
                                    borderSide: const BorderSide(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 📡 Opérateur / Erreur
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _hasPrefixError
                                ? const Text(
                                    'Préfixe non reconnu',
                                    key: ValueKey('error'),
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  )
                                : _operator != null
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                            _getOperatorIcon(_operator!),
                                            height: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Opérateur : $_operator',
                                            key: ValueKey(_operator),
                                            style: const TextStyle(
                                              color: Color.fromRGBO(255, 255, 255, 0.9),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox(
                                        height: 24,
                                        key: ValueKey('empty'),
                                      ),
                          ),

                          const SizedBox(height: 28),

                          // 🔘 BOUTON GLASSMORPHISM
                          _GlassButton(
                            label: 'Se connecter',
                            isLoading: authState.isLoading,
                            isEnabled: _isValid && !authState.isLoading,
                            onPressed: (_isValid && !authState.isLoading)
                                ? () async {
                                    final phone = _phoneController.text;
                                    final success = await ref
                                        .read(authControllerProvider.notifier)
                                        .sendOtp(phone);

                                    if (success && mounted) {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          transitionDuration:
                                              const Duration(milliseconds: 500),
                                          reverseTransitionDuration:
                                              const Duration(milliseconds: 400),
                                          pageBuilder: (context, animation,
                                              secondaryAnimation) {
                                            return OtpPage(
                                              phone: phone,
                                            );
                                          },
                                          transitionsBuilder: (context,
                                              animation,
                                              secondaryAnimation,
                                              child) {
                                            return SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(1.0, 0.0),
                                                end: Offset.zero,
                                              ).animate(CurvedAnimation(
                                                parent: animation,
                                                curve: Curves.easeOutCubic,
                                              )),
                                              child: FadeTransition(
                                                opacity: animation,
                                                child: child,
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          ),

                          // ❌ Erreur auth
                          if (authState.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                authState.error!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ✨ SLOGAN en bas — Police LetterMagic
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
                    child: Text(
                      'Simple, Rapide, Sûr',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'LetterMagic',
                        fontSize: 24,
                        color: const Color.fromRGBO(255, 255, 255, 0.95),
                        letterSpacing: 1.5,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎨 CUSTOM PAINTER — Fond avec ovale bleu marine
// ─────────────────────────────────────────────────────────────────────────────

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fond teal complet
    final tealPaint = Paint()..color = const Color(0xFF2196C8);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      tealPaint,
    );

    // 2. Grand ovale bleu marine foncé
    final darkPaint = Paint()..color = const Color(0xFF0B1727);

    final ovalPath = Path();
    final ovalHeight = size.height * 0.78;

    ovalPath.moveTo(-size.width * 0.15, 0);
    ovalPath.lineTo(size.width * 1.15, 0);
    ovalPath.lineTo(size.width * 1.15, ovalHeight - 80);

    // Courbe douce en bas de l'ovale
    ovalPath.quadraticBezierTo(
      size.width * 0.5,   // point de contrôle X (centre)
      ovalHeight + 60,     // point de contrôle Y (plus bas pour l'arrondi)
      -size.width * 0.15,  // fin X
      ovalHeight - 80,     // fin Y
    );

    ovalPath.close();
    canvas.drawPath(ovalPath, darkPaint);

    // 3. Subtile lueur en haut de l'ovale
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.5),
        radius: 0.8,
        colors: [
          const Color(0xFF1A3A5C).withOpacity(0.4),
          const Color(0xFF0B1727).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, ovalHeight));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, ovalHeight),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 🔘 GLASSMORPHISM BUTTON — Effet verre dépoli style iOS
// ─────────────────────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool isEnabled;
  final VoidCallback? onPressed;

  const _GlassButton({
    required this.label,
    required this.isLoading,
    required this.isEnabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isEnabled ? 1.0 : 0.5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: 230,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: Colors.white.withOpacity(0.2),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
