import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_controller.dart';
import 'otp_page.dart';
import '../../../home/home_page.dart';

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

  late AnimationController _shakeController;
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // 🎬 Animation du logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeIn,
      ),
    );

    _logoController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _shakeController.dispose();
    _logoController.dispose();
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

      if (['97', '99'].contains(prefix)) {
        detectedOperator = 'Airtel';
      } else if (['81', '82'].contains(prefix)) {
        detectedOperator = 'Vodacom';
      } else if (['84', '85', '89'].contains(prefix)) {
        detectedOperator = 'Orange';
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1E7DBA),
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              const Spacer(),

              // 🔵 LOGO AGRANDI – SANS OMBRE – LÉGÈREMENT REMONTÉ
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Transform.translate(
                    offset: const Offset(0, -25),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 180, // ≈ 200%
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'N° Téléphone',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 22),

              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final offset = 12 * (1 - _shakeController.value);
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: SizedBox(
                  width: 290,
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 13,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
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
                      hintText: '812345678',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(32),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              if (_hasPrefixError)
                const Text(
                  'Préfixe non reconnu',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (_operator != null)
                Text(
                  'Opérateur : $_operator',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),

              const SizedBox(height: 36),

              SizedBox(
                width: 230,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E7DBA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  onPressed: (_isValid && !authState.isLoading)
                      ? () async {
                          final phone = _phoneController.text;
                          final success = await ref
                              .read(authControllerProvider.notifier)
                              .sendOtp(phone);

                          if (success && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OtpPage(phone: phone),
                              ),
                            );
                          }
                        }
                      : null,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'SE CONNECTER',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              if (authState.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    authState.error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              const Spacer(),

              // 📝 SLOGAN
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  'Acheter et vendez comme jamais auparavant',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
