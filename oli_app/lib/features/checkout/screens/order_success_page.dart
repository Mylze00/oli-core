import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order_model.dart';
import '../../orders/screens/purchases_page.dart';
import '../../../providers/exchange_rate_provider.dart';

/// Page de Confirmation de Commande
/// Affichée après un paiement réussi (wallet, mobile money, ou carte)
class OrderSuccessPage extends ConsumerWidget {
  final Order order;

  const OrderSuccessPage({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ✅ Icône succès animée
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: child,
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
                ),
              ),
              const SizedBox(height: 32),

              // Titre
              const Text(
                'Commande Confirmée !',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Votre commande #${order.id} a été créée avec succès',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 15),
              ),
              const SizedBox(height: 32),

              // Récap commande
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Statut', order.statusLabel, Colors.orange),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Montant total',
                      exchangeNotifier.formatProductPrice(order.totalAmount),
                      Colors.white,
                    ),
                    if (order.deliveryFee > 0) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Frais livraison',
                        exchangeNotifier.formatProductPrice(order.deliveryFee),
                        Colors.grey,
                      ),
                    ],
                    if (order.paymentMethod != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Paiement',
                        _getPaymentLabel(order.paymentMethod!),
                        Colors.blueAccent,
                      ),
                    ],
                    if (order.items.isNotEmpty) ...[
                      const Divider(color: Colors.grey, height: 24),
                      ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            // Image produit
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item.imageUrl != null
                                  ? Image.network(
                                      item.imageUrl!,
                                      width: 40, height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 40, height: 40,
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.image, color: Colors.grey, size: 20),
                                      ),
                                    )
                                  : Container(
                                      width: 40, height: 40,
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.image, color: Colors.grey, size: 20),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'x${item.quantity}',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              exchangeNotifier.formatProductPrice(item.total),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Info paiement
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blueAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Le vendeur a été notifié et va préparer votre commande.',
                        style: TextStyle(color: Colors.blue[200], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Bouton Voir mes commandes
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const PurchasesPage()),
                      (route) => route.isFirst,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Voir mes commandes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bouton retour accueil
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: Colors.grey[700]!),
                  ),
                  child: const Text(
                    'Retour à l\'accueil',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _getPaymentLabel(String method) {
    switch (method) {
      case 'wallet': return 'Wallet Oli';
      case 'mobile_money': return 'Mobile Money';
      case 'card': return 'Carte bancaire';
      default: return method;
    }
  }
}
