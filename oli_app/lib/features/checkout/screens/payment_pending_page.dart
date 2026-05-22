import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order_model.dart';
import '../../../providers/exchange_rate_provider.dart';
import 'payment_failed_page.dart';
import 'order_success_page.dart';

/// Page affichee pendant l'attente de validation USSD Mobile Money (Unipesa C2B)
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
  ConsumerState<PaymentPendingPage> createState() => _PaymentPendingPageState();
}

class _PaymentPendingPageState extends ConsumerState<PaymentPendingPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  Timer? _statusTimer;
  Timer? _timeoutTimer;
  Timer? _dotTimer;
  int _elapsed = 0;
  int _dotCount = 0;
  static const int _maxSec = 180;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() => _dotCount = (_dotCount + 1) % 4);
    });
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkStatus();
      setState(() => _elapsed += 5);
    });
    _timeoutTimer = Timer(const Duration(seconds: _maxSec), () => _toFailed('timeout'));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _dotTimer?.cancel();
    _statusTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    // TODO: interroger le backend pour le statut du paiement
    // final status = await ref.read(orderServiceProvider).checkPaymentStatus(widget.order.id);
    // if (status == 'paid') _toSuccess();
    // if (status == 'failed') _toFailed('rejected');
  }

  void _toSuccess() {
    if (!mounted) return;
    _statusTimer?.cancel();
    _timeoutTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OrderSuccessPage(order: widget.order)),
    );
  }

  void _toFailed(String reason) {
    if (!mounted) return;
    _statusTimer?.cancel();
    _timeoutTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PaymentFailedPage(order: widget.order, reason: reason)),
    );
  }

  int get _minsLeft => ((_maxSec - _elapsed) / 60).ceil().clamp(0, 99);
  String get _dotsStr => '.' * _dotCount;

  String get _providerIcon {
    final n = widget.providerName.toLowerCase();
    if (n.contains('orange')) return 'O';
    if (n.contains('mpesa') || n.contains('vodacom')) return 'M';
    if (n.contains('airtel')) return 'A';
    if (n.contains('africell')) return 'AF';
    return 'MM';
  }

  Color get _providerColor {
    final n = widget.providerName.toLowerCase();
    if (n.contains('orange')) return const Color(0xFFFF6600);
    if (n.contains('mpesa') || n.contains('vodacom')) return const Color(0xFFE60000);
    if (n.contains('airtel')) return const Color(0xFF0047AB);
    return Colors.green;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // Icone animee
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Transform.scale(scale: _pulse.value, child: child),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withOpacity(0.08),
                    border: Border.all(color: Colors.orange.withOpacity(0.4), width: 2),
                  ),
                  child: const Icon(Icons.phone_android_rounded, color: Colors.orange, size: 56),
                ),
              ),

              const SizedBox(height: 36),

              Text(
                'En attente\',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Validez le paiement sur votre telephone',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                widget.phoneNumber,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.orange, fontSize: 15, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 32),

              // Card instructions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header operateur
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _providerColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _providerColor.withOpacity(0.3)),
                          ),
                          child: Center(
                            child: Text(
                              _providerIcon,
                              style: TextStyle(color: _providerColor, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.providerName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(widget.phoneNumber,
                                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('En cours',
                              style: TextStyle(color: Colors.orange[300], fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF222222)),
                    const SizedBox(height: 16),

                    // Etapes
                    _buildStep('1', 'Verifiez votre telephone', 'Une notification USSD a ete envoyee', Colors.orange),
                    const SizedBox(height: 16),
                    _buildStep('2', 'Entrez votre code PIN', 'PIN de votre compte \', Colors.orange),
                    const SizedBox(height: 16),
                    _buildStep('3', 'Confirmez le montant',
                        ex.formatProductPrice(widget.order.totalAmount), Colors.green),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Montant et timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF222222)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Commande #\',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(ex.formatProductPrice(widget.order.totalAmount),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, color: Colors.grey[600], size: 14),
                        const SizedBox(width: 4),
                        Text('\ min',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
                  onPressed: () => _toFailed('cancelled'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: Colors.grey[800]!),
                  ),
                  child: const Text('Annuler le paiement', style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String title, String subtitle, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Center(
            child: Text(number, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
