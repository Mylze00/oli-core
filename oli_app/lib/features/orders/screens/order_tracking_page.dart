import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/orders_provider.dart';
import '../widgets/order_tracking_widget.dart';
import '../widgets/verification_code_widget.dart';

/// Page de suivi de commande — affiche la timeline + codes de vérification
class OrderTrackingPage extends ConsumerWidget {
  final int orderId;

  const OrderTrackingPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingAsync = ref.watch(orderTrackingProvider(orderId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text('Suivi #$orderId', style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(orderTrackingProvider(orderId)),
          ),
        ],
      ),
      body: trackingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.blue)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text('Erreur: $e', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(orderTrackingProvider(orderId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (tracking) {
          if (tracking == null) {
            return const Center(
              child: Text('Impossible de charger le suivi', style: TextStyle(color: Colors.white70)),
            );
          }

          final status = tracking['current_status'] ?? 'pending';
          final pickupCode = tracking['pickup_code'];
          final deliveryCode = tracking['delivery_code'];

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(orderTrackingProvider(orderId)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Timeline
                  OrderTrackingWidget(tracking: tracking),

                  const SizedBox(height: 20),

                  // Code de livraison (visible par l'acheteur quand colis en route)
                  if (deliveryCode != null && ['shipped'].contains(status))
                    VerificationCodeWidget(
                      code: deliveryCode,
                      title: 'Code de réception',
                      subtitle: 'Montrez ce code au livreur pour confirmer la réception',
                      accentColor: Colors.green,
                      icon: Icons.verified_outlined,
                    ),

                  // Code de pickup (visible par le vendeur pour le livreur)
                  if (pickupCode != null && ['ready'].contains(status))
                    VerificationCodeWidget(
                      code: pickupCode,
                      title: 'Code de retrait',
                      subtitle: 'Le livreur doit présenter ce code pour récupérer le colis',
                      accentColor: Colors.orange,
                      icon: Icons.local_shipping_outlined,
                    ),

                  // Boutons d'action selon le rôle et le statut
                  if (deliveryCode != null && status == 'shipped')
                    _buildDeliveryVerificationButton(context, ref),

                  // Statut livré → succès
                  if (status == 'delivered')
                    _buildDeliveredBanner(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeliveryVerificationButton(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showVerifyDeliveryDialog(context, ref),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.check_circle, color: Colors.white),
          label: const Text('Confirmer la réception', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  void _showVerifyDeliveryDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la livraison', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez le code de livraison pour confirmer la réception du colis.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 4),
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'CODE',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final code = controller.text.trim();
              if (code.length != 6) return;

              Navigator.pop(ctx);

              final service = ref.read(orderServiceProvider);
              final success = await service.verifyDelivery(orderId, code);

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Livraison confirmée ! ✅'), backgroundColor: Colors.green),
                  );
                  ref.invalidate(orderTrackingProvider(orderId));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code invalide, réessayez'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveredBanner() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Commande livrée !', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('La livraison a été confirmée avec succès.', style: TextStyle(color: Colors.green[300], fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
