import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_controller.dart';
import 'package:oli_app/features/home/home_page.dart';

class OtpPage extends ConsumerStatefulWidget {
  final String phone;
  final String? otpCode; // Code OTP reçu du serveur (mode dev)
  const OtpPage({super.key, required this.phone, this.otpCode});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage>
    with TickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();

  late AnimationController _fadeController;
  late AnimationController _breatheController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _breatheScale;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 🎬 Fade-in + Slide du contenu (pas du logo — le Hero s'en charge)
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    // 🫁 Breathing animation pour le logo (continu)
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

    // Démarrer les animations après le Hero
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _fadeController.forward();
        _breatheController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _fadeController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: const Text('Entrez le code')),
      );
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(
          phone: widget.phone,
          otpCode: otp,
        );

    if (!mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
        (_) => false,
      );
    } else {
      final error = ref.read(authControllerProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
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
          // 🎨 FOND — CustomPainter (même style que login)
          CustomPaint(
            size: size,
            painter: _OtpBackgroundPainter(),
          ),

          // 📱 CONTENU
          SafeArea(
            child: SizedBox(
              width: size.width,
              height: size.height - MediaQuery.of(context).padding.top,
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // 🔵 LOGO avec Hero (transition depuis login) + Breathing
                  AnimatedBuilder(
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
                        height: 100,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 📝 Titre "Vérification"
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'Vérification',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // 📱 FORMULAIRE (fade-in avec slide)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          // Message
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Entrez le code envoyé au\n${widget.phone}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color.fromRGBO(255, 255, 255, 0.9),
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // 🔢 Champ OTP
                          Container(
                            width: 220,
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
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 6,
                                color: Color(0xFF0B1727),
                              ),
                              maxLength: 6,
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white,
                                hintText: '••••••',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 24,
                                  letterSpacing: 6,
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

                          const SizedBox(height: 32),

                          // 🔘 BOUTON GLASSMORPHISM
                          _GlassButton(
                            label: 'VÉRIFIER',
                            isLoading: authState.isLoading,
                            isEnabled: !authState.isLoading,
                            onPressed: authState.isLoading ? null : _verify,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ✨ SLOGAN — Police LetterMagic
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 32,
                      left: 24,
                      right: 24,
                    ),
                    child: Text(
                      'Simple, Rapide, Sûr',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'LetterMagic',
                        fontSize: 36,
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
// 🎨 CUSTOM PAINTER — Fond avec ovale bleu marine (même style que login)
// ─────────────────────────────────────────────────────────────────────────────

class _OtpBackgroundPainter extends CustomPainter {
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
    final ovalHeight = size.height * 0.75;

    ovalPath.moveTo(-size.width * 0.15, 0);
    ovalPath.lineTo(size.width * 1.15, 0);
    ovalPath.lineTo(size.width * 1.15, ovalHeight - 80);

    // Courbe douce en bas de l'ovale
    ovalPath.quadraticBezierTo(
      size.width * 0.5,
      ovalHeight + 50,
      -size.width * 0.15,
      ovalHeight - 80,
    );

    ovalPath.close();
    canvas.drawPath(ovalPath, darkPaint);

    // 3. Subtile lueur
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
              width: 220,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
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
