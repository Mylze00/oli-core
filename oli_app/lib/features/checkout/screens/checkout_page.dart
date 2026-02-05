import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cart/providers/cart_provider.dart';
import '../../orders/providers/orders_provider.dart';
import 'stripe_payment_page.dart';

/// Page de Checkout / Validation de commande
/// Peut être utilisée avec le panier (défaut) ou avec un achat direct (directPurchaseItem)
class CheckoutPage extends ConsumerStatefulWidget {
  /// Si fourni, utilise cet item au lieu du panier (Achat immédiat)
  final CartItem? directPurchaseItem;
  
  const CheckoutPage({super.key, this.directPurchaseItem});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  String _paymentMethod = 'wallet';
  String _deliveryAddress = '';
  final _addressController = TextEditingController();
  bool _isLoading = false;
  double _deliveryFee = 5.00;

  /// Retourne les items à checkout (achat direct ou panier)
  List<CartItem> get _checkoutItems {
    if (widget.directPurchaseItem != null) {
      return [widget.directPurchaseItem!];
    }
    return ref.watch(cartProvider);
  }

  /// Calcule le sous-total
  double get _subtotal {
    return _checkoutItems.fold(0, (sum, item) => sum + item.total);
  }

  @override
  void initState() {
    super.initState();
    // Si achat direct, utiliser le frais de livraison du produit
    if (widget.directPurchaseItem != null) {
      _deliveryFee = widget.directPurchaseItem!.deliveryPrice;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = _checkoutItems;
    final subtotal = _subtotal;
    final total = subtotal + (widget.directPurchaseItem == null ? _deliveryFee : 0); // Livraison déjà incluse dans directPurchaseItem

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Validation de commande'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- RÉCAP COMMANDE ---
            _buildSectionTitle('Récapitulatif'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ...cartItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('${item.productName} x${item.quantity}', style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
                        Text('\$${item.total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )),
                  const Divider(color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sous-total', style: TextStyle(color: Colors.grey)),
                      Text('\$${subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Livraison', style: TextStyle(color: Colors.grey)),
                      Text('\$${_deliveryFee.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- ADRESSE DE LIVRAISON ---
            _buildSectionTitle('Adresse de livraison'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _addressController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: 123 rue..., Quartier, Ville',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                onChanged: (value) => _deliveryAddress = value,
              ),
            ),

            const SizedBox(height: 24),

            // --- MÉTHODE DE PAIEMENT ---
            _buildSectionTitle('Méthode de paiement'),
            _buildPaymentOption('wallet', 'Wallet OLI', Icons.account_balance_wallet, Colors.green),
            _buildPaymentOption('card', 'Carte bancaire', Icons.credit_card, Colors.blue),
            _buildPaymentOption('mobile_money', 'Mobile Money', Icons.phone_android, Colors.orange),

            const SizedBox(height: 32),

            // --- BOUTON CONFIRMER ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _confirmOrder(total),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Confirmer (\$${total.toStringAsFixed(2)})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon, Color color) {
    final isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
            if (isSelected) Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmOrder(double total) async {
    if (_deliveryAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une adresse de livraison'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final orderService = ref.read(orderServiceProvider);
      
      // Convertir les items (panier ou achat direct) en OrderItems
      final orderItems = _checkoutItems.map((item) => item.toOrderItem()).toList();
      
      final order = await orderService.createOrder(
        items: orderItems,
        deliveryAddress: _deliveryAddress,
        paymentMethod: _paymentMethod,
        deliveryFee: _deliveryFee,
      );

      if (order != null) {
        // Vider le panier SEULEMENT si ce n'était pas un achat direct
        if (widget.directPurchaseItem == null) {
          ref.read(cartProvider.notifier).clearCart();
        }
        
        // Rafraîchir la liste des commandes
        ref.invalidate(ordersProvider);

        if (!mounted) return;

        // SI PAIEMENT CARTE -> Redirection vers écran Stripe
        if (_paymentMethod == 'card') {
           Navigator.pushReplacement(
             context,
             MaterialPageRoute(builder: (_) => StripePaymentPage(order: order)),
           );
           return;
        }

        // SINON (Wallet / Mobile Money) -> Afficher confirmation standard
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Commande créée !', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Commande #${order.id}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Text('Total: \$${order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Paiement en attente. Le vendeur sera notifié.',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Fermer dialog
                  // Retourner à l'accueil
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Erreur de création');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
