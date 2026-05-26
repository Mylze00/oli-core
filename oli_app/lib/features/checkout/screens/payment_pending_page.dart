import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../models/order_model.dart';
import '../../../providers/exchange_rate_provider.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'payment_failed_page.dart';
import 'order_success_page.dart';

/// Page "En attente de paiement Mobile Money"
/// Affichée après soumission d'un paiement C2B Unipesa.
/// Le client doit valider sur son téléphone via USSD / notification Push.
class PaymentPendingPage extends ConsumerStatefulWidget {
  final Order order;
  final String phoneNumber;
  final String providerName;

  const PaymentPendingPage({
    super.key,
    required this.order,
    required this.phoneNumber,
    required this.providerName,
  });

  @override
  ConsumerState<PaymentPendingPage> createState() =>
      _PaymentPendingPageState();
}

class _PaymentPendingPageState extends ConsumerState<PaymentPendingPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _dotController;
  late Animation<double> _pulseAnimation;
  Timer? _statusTimer;
  Timer? _timeoutTimer;
  int _secondsElapsed = 0;
  static const int _maxWaitSeconds = 180;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _dotCount = (_dotCount + 1) % 4);
          _dotController.reset();
          _dotController.forward();
        }
      });
    _dotController.forward();

    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkPaymentStatus();
      setState(() => _secondsElapsed += 5);
    });

    _timeoutTimer = Timer(
      const Duration(seconds: _maxWaitSeconds),
      () => _navigateToFailed(reason: 'timeout'),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotController.dispose();
    _statusTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPaymentStatus() async {
    try {
      final apiBase = const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://oli-core.onrender.com',
      );

      // Récupérer l'oliOrderId stocké lors de l'initiation du paiement
      final oliOrderId = widget.order.unipesaOrderId;
      if (oliOrderId == null || oliOrderId.isEmpty) return;

      final token = await _getAuthToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$apiBase/api/unipesa/status/$oliOrderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'] as String?;

        if (status == 'success') {
          _navigateToSuccess();
        } else if (status == 'failed' || status == 'cancelled') {
          _navigateToFailed(reason: 'rejected');
        } else if (status == 'timeout') {
          _navigateToFailed(reason: 'timeout');
        }
        // Si 'pending' → on attend le prochain cycle de polling
      }
    } catch (e) {
      // Erreur réseau non fatale — on réessaie au prochain tick
      debugPrint('⚠️ Erreur polling statut paiement: $e');
    }
  }

  /// Récupère le token JWT de l'utilisateur via SecureStorageService.
  Future<String?> _getAuthToken() async {
    try {
      final storage = ref.read(secureStorageProvider);
      return await storage.getToken();
    } catch (_) {
      return null;
    }
  }

  void _navigateToSuccess() {
    if (!mounted) return;
    _statusTimer?.cancel();
    _timeoutTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OrderSuccessPage(order: widget.order)),
    );
  }

  void _navigateToFailed({required String reason}) {
    if (!mounted) return;
    _statusTimer?.cancel();
    _timeoutTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PaymentFailedPage(order: widget.order, reason: reason),
      ),
    );
  }

  String get _dots => '.' * _dotCount;
  int get _minutesLeft =>
      ((_maxWaitSeconds - _secondsElapsed) / 60).ceil().clamp(0, 99);

  String get _providerIcon {
    final name = widget.providerName.toLowerCase();
    if (name.contains('orange')) return '🟠';
    if (name.contains('mpesa') || name.contains('vodacom')) return '🔴';
    if (name.contains('airtel')) return '🔵';
    if (name.contains('africell')) return '🟢';
    return '📱';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(exchangeRateProvider);
    final ex = ref.read(exchangeRateProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.vertical,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Icône animée pulsante
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, child) =>
                        Transform.scale(scale: _pulseAnimation.value, child: child),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.orange.withOpacity(0.25),
                            Colors.orange.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.phone_android_rounded,
                        color: Colors.orange,
                        size: 56,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  Text(
                    'En attente$_dots',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Validez le paiement sur votre téléphone',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.phoneNumber,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Card instructions
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header provider
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  _providerIcon,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.providerName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  widget.phoneNumber,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'En cours',
                                style: TextStyle(
                                  color: Colors.orange[300],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFF252525)),
                        const SizedBox(height: 16),

                        // Étapes
                        _buildStep(
                          '1',
                          'Vérifiez votre téléphone',
                          'Une notification ou message USSD a été envoyé',
                          Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        _buildStep(
                          '2',
                          'Entrez votre code PIN',
                          'Saisissez le PIN de votre compte ${widget.providerName}',
                          Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        _buildStep(
                          '3',
                          'Confirmez le montant',
                          ex.formatProductPrice(widget.order.totalAmount),
                          Colors.green,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Récap montant
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF252525)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Commande #${widget.order.id}',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ex.formatProductPrice(widget.order.totalAmount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (_minutesLeft > 0)
                          Row(
                            children: [
                              Icon(Icons.timer_outlined,
                                  color: Colors.grey[600], size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '$_minutesLeft min',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Bouton annuler
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _navigateToFailed(reason: 'cancelled'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[400],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: Colors.grey[800]!),
                      ),
                      child: const Text(
                        'Annuler le paiement',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
      String number, String title, String subtitle, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
