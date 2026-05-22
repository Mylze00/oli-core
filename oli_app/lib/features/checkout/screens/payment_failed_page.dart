import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order_model.dart';
import '../../../providers/exchange_rate_provider.dart';
import '../../orders/screens/purchases_page.dart';
import 'checkout_page.dart';

/// Page affichee quand le paiement Mobile Money echoue, expire ou est annule.
class PaymentFailedPage extends ConsumerWidget {
  final Order order;

  /// 'rejected'  - solde insuffisant ou refus
  /// 'timeout'   - delai depasse (3 min)
  /// 'cancelled' - annule par l'utilisateur
  final String reason;

  const PaymentFailedPage({super.key, required this.order, required this.reason});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

              // Icone echec animee
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, value, child) => Transform.scale(scale: value, child: child),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.08),
                    border: Border.all(color: Colors.red.withOpacity(0.35), width: 2),
                  ),
                  child: Icon(_iconData, color: Colors.red[400], size: 54),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                _title,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 15, height: 1.6),
              ),

              const SizedBox(height: 36),

              // Card details commande
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF222222)),
                ),
                child: Column(
                  children: [
                    _buildRow('Commande', '#\', Colors.grey[300]!),
                    const SizedBox(height: 12),
                    _buildRow('Montant', ex.formatProductPrice(order.totalAmount), Colors.white,
                        fontSize: 16, bold: true),
                    const SizedBox(height: 12),
                    _buildRow('Statut', _statusLabel, _statusColor, bold: true),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFF222222)),
                    const SizedBox(height: 12),

                    // Conseil contextuel
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.18)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_tip,
                                style: TextStyle(color: Colors.orange[200], fontSize: 13, height: 1.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Note commande conservee
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.withOpacity(0.18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blueAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Votre commande #\ est conservee. Reessayez le paiement depuis Mes commandes.',
                        style: TextStyle(color: Colors.blue[200], fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Bouton Reessayer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const CheckoutPage()),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Reessayer le paiement',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E7DBA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bouton Voir commandes
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const PurchasesPage()),
                    (route) => route.isFirst,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: Colors.grey[800]!),
                  ),
                  child: const Text('Voir mes commandes', style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _iconData {
    switch (reason) {
      case 'timeout': return Icons.timer_off_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      default: return Icons.error_rounded;
    }
  }

  String get _title {
    switch (reason) {
      case 'timeout': return 'Delai expire';
      case 'cancelled': return 'Paiement annule';
      default: return 'Paiement echoue';
    }
  }

  String get _subtitle {
    switch (reason) {
      case 'timeout': return 'Le delai de confirmation a expire.\nVotre commande est toujours active.';
      case 'cancelled': return 'Vous avez annule le paiement.\nVotre commande reste en attente.';
      default: return 'Le paiement Mobile Money a echoue.\nSolde insuffisant ou refus de confirmation.';
    }
  }

  String get _statusLabel {
    switch (reason) {
      case 'timeout': return 'Expire';
      case 'cancelled': return 'Annule';
      default: return 'Echoue';
    }
  }

  Color get _statusColor {
    switch (reason) {
      case 'timeout': return Colors.orange;
      case 'cancelled': return Colors.grey;
      default: return Colors.red;
    }
  }

  String get _tip {
    switch (reason) {
      case 'timeout': return 'Ayez votre telephone a portee et reessayez.';
      case 'cancelled': return 'Vous pouvez reessayer avec un autre moyen de paiement.';
      default: return 'Verifiez votre solde Mobile Money ou utilisez une autre methode.';
    }
  }

  Widget _buildRow(String label, String value, Color valueColor,
      {double fontSize = 14, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        Text(value,
            style: TextStyle(
              color: valueColor,
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            )),
      ],
    );
  }
}
