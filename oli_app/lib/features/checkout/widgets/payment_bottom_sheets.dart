import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import '../../../models/order_model.dart';
import '../../../providers/exchange_rate_provider.dart';
import '../../../core/storage/secure_storage_service.dart';

// --- STYLES COMMUNS ---
final _sheetShape = const RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
);
const _sheetBgColor = Color(0xFF141414);

// ---------------------------------------------------------
// 1. CONFIRMATION SHEET (Dernière lecture avant validation)
// ---------------------------------------------------------
/// Dernière lecture avant de payer, façon Apple Pay : moyen de paiement, numéro,
/// adresse puis montant exact. Suit le mode clair ou sombre de l'app.
Future<bool?> showPaymentConfirmationSheet({
  required BuildContext context,
  required double amountFC,
  required String paymentMethod,
  required double walletBalanceFC,
  required String mobileMoneyPhone,
  required double mobileMoneyFeeFC,
  required String deliveryLabel,
  required String Function(num) formatFc,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sheetColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
  final rowColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
  final text = isDark ? Colors.white : const Color(0xFF111418);
  final secondary = isDark ? const Color(0xFF9A9AA0) : const Color(0xFF6B7280);
  final tile = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFF1F3F6);
  final accent = isDark ? const Color(0xFF3B8EF0) : const Color(0xFF1A5DE6);
  final isMobileMoney = paymentMethod == 'mobile_money';

  Widget row({required IconData icon, required String label, required String value, String? detail}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: rowColor, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: text, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: secondary, fontSize: 13)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w500)),
                if (detail != null)
                  Text(detail, style: TextStyle(color: secondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: sheetColor,
    shape: _sheetShape,
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Oli Pay', style: TextStyle(color: text, fontSize: 24, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.pop(ctx, false),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: tile, shape: BoxShape.circle),
                      child: Icon(Icons.close, color: secondary, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isMobileMoney)
                row(
                  icon: Icons.phone_android_rounded,
                  label: 'Mobile Money',
                  value: mobileMoneyPhone,
                  detail: 'Validez la demande reçue sur ce téléphone',
                )
              else
                row(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Wallet Oli',
                  value: 'Solde ${formatFc(walletBalanceFC)}',
                  detail: 'Après paiement : ${formatFc(walletBalanceFC - amountFC)}',
                ),
              row(
                icon: Icons.home_outlined,
                label: deliveryLabel == 'Retrait en boutique' ? 'Retrait' : 'Livrer à',
                value: deliveryLabel.isEmpty ? '—' : deliveryLabel,
              ),
              if (isMobileMoney && mobileMoneyFeeFC > 0)
                row(
                  icon: Icons.receipt_long_outlined,
                  label: 'Frais Mobile Money (opérateur et Oli)',
                  value: '+${formatFc(mobileMoneyFeeFC)}',
                ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(color: rowColor, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payer OLI', style: TextStyle(color: secondary, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      formatFc(amountFC),
                      style: TextStyle(color: text, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: Text(
                    isMobileMoney ? 'Envoyer la demande de paiement' : 'Confirmer le paiement',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------
// 2. PENDING SHEET (Attente et Polling 60 secondes)
// ---------------------------------------------------------
enum PaymentResult { success, failed, timeout, cancelled }

Future<PaymentResult?> showPaymentPendingSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String oliOrderId,
  required String phoneNumber,
  required String providerName,
}) {
  return showModalBottomSheet<PaymentResult>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: _sheetBgColor,
    shape: _sheetShape,
    builder: (ctx) {
      return _PaymentPendingWidget(
        oliOrderId: oliOrderId,
        phoneNumber: phoneNumber,
        providerName: providerName,
      );
    },
  );
}

class _PaymentPendingWidget extends ConsumerStatefulWidget {
  final String oliOrderId;
  final String phoneNumber;
  final String providerName;

  const _PaymentPendingWidget({
    required this.oliOrderId,
    required this.phoneNumber,
    required this.providerName,
  });

  @override
  ConsumerState<_PaymentPendingWidget> createState() => _PaymentPendingWidgetState();
}

class _PaymentPendingWidgetState extends ConsumerState<_PaymentPendingWidget> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _statusTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 60; // 60 secondes max
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startTimers();
  }

  void _startTimers() {
    // Compte à rebours
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _handleResult(PaymentResult.timeout);
        }
      });
    });

    // Polling toutes les 4 secondes
    _statusTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isChecking) _checkPaymentStatus();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPaymentStatus() async {
    _isChecking = true;
    try {
      final apiBase = const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://oli-core.onrender.com');
      final storage = ref.read(secureStorageProvider);
      final token = await storage.getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$apiBase/api/unipesa/status/${widget.oliOrderId}'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final status = data['status'] as String?;

        if (status == 'success') {
          _handleResult(PaymentResult.success);
        } else if (status == 'failed' || status == 'cancelled') {
          _handleResult(PaymentResult.failed);
        } else if (status == 'timeout') {
          _handleResult(PaymentResult.timeout);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erreur polling statut: $e');
    } finally {
      _isChecking = false;
    }
  }

  void _handleResult(PaymentResult result) {
    if (!mounted) return;
    _statusTimer?.cancel();
    _countdownTimer?.cancel();
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, child) => Transform.scale(scale: _pulseAnimation.value, child: child),
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.15),
                border: Border.all(color: Colors.orange.withOpacity(0.5), width: 2),
              ),
              child: const Icon(Icons.phone_android_rounded, color: Colors.orange, size: 40),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'En attente de validation',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Veuillez valider le paiement sur votre téléphone\n${widget.phoneNumber}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          // Compte à rebours
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Text(
                '00:${_secondsLeft.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _handleResult(PaymentResult.cancelled),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54, fontSize: 16)),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 3. SUCCESS SHEET
// ---------------------------------------------------------
void showPaymentSuccessSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Order order,
  required VoidCallback onDone,
}) {
  // Petit retour haptique (vibration douce)
  HapticFeedback.mediumImpact();
  
  // Jouer le son de succès
  final player = AudioPlayer();
  player.play(AssetSource('images/kaching.mp3'));

  final ex = ref.read(exchangeRateProvider.notifier);
  
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: _sheetBgColor,
    shape: _sheetShape,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(0.15),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Paiement Réussi',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Votre commande #${order.id} est confirmée',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 20),
            Text(
              ex.formatProductPrice(order.totalAmount),
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onDone();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Terminer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------
// 4. FAILED SHEET (Avec option de Réessayer)
// ---------------------------------------------------------
void showPaymentFailedSheet({
  required BuildContext context,
  required PaymentResult reason,
  required VoidCallback onRetry,
  required VoidCallback onCancel,
}) {
  String title = 'Paiement échoué';
  String message = 'Votre paiement n\'a pas pu être traité.';
  
  if (reason == PaymentResult.timeout) {
    title = 'Temps écoulé';
    message = 'Vous n\'avez pas validé le paiement à temps.';
  } else if (reason == PaymentResult.cancelled) {
    title = 'Paiement annulé';
    message = 'Vous avez annulé la transaction.';
  }

  showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: _sheetBgColor,
    shape: _sheetShape,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.15),
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onCancel();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[800]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Fermer', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onRetry();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Réessayer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      );
    },
  );
}
