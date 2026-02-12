import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cart/providers/cart_provider.dart';
import '../../orders/providers/orders_provider.dart';
import 'stripe_payment_page.dart';
import 'order_success_page.dart';

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
  String _selectedDeliveryMethod = 'oli_standard';

  /// Méthodes de livraison disponibles
  final List<Map<String, dynamic>> _deliveryMethods = [
    {'id': 'oli_express', 'label': 'Oli Express', 'icon': Icons.flash_on, 'time': '1-2h', 'cost': 8.00, 'color': Colors.amber},
    {'id': 'oli_standard', 'label': 'Oli Standard', 'icon': Icons.local_shipping, 'time': '2-5 jours', 'cost': 5.00, 'color': Colors.blue},
    {'id': 'partner', 'label': 'Livreur Partenaire', 'icon': Icons.delivery_dining, 'time': 'Variable', 'cost': 3.00, 'color': Colors.purple},
    {'id': 'hand_delivery', 'label': 'Remise en Main Propre', 'icon': Icons.handshake, 'time': 'À convenir', 'cost': 0.0, 'color': Colors.teal},
    {'id': 'pick_go', 'label': 'Pick & Go', 'icon': Icons.store, 'time': 'Retrait', 'cost': 0.0, 'color': Colors.green},
    {'id': 'free', 'label': 'Livraison Gratuite', 'icon': Icons.card_giftcard, 'time': '3-7 jours', 'cost': 0.0, 'color': Colors.pink},
  ];

  /// Retourne les items à checkout (achat direct ou panier)
  List<CartItem> get _checkoutItems {
    if (widget.directPurchaseItem != null) {
      return [widget.directPurchaseItem!];
    }
    return ref.watch(cartProvider).where((item) => item.isSelected).toList();
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

            // --- MODE DE LIVRAISON ---
            _buildSectionTitle('Mode de livraison'),
            ..._deliveryMethods.map((method) => _buildDeliveryMethodOption(method)),

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

  Widget _buildDeliveryMethodOption(Map<String, dynamic> method) {
    final isSelected = _selectedDeliveryMethod == method['id'];
    final Color color = method['color'];
    return GestureDetector(
      onTap: () => setState(() {
        _selectedDeliveryMethod = method['id'];
        _deliveryFee = (method['cost'] as num).toDouble();
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Row(
          children: [
            Icon(method['icon'], color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method['label'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  Text(method['time'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
            Text(
              method['cost'] == 0.0 ? 'Gratuit' : '\$${(method['cost'] as num).toStringAsFixed(2)}',
              style: TextStyle(color: method['cost'] == 0.0 ? Colors.green : Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 8),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmOrder(double total) async {
    final needsAddress = _selectedDeliveryMethod != 'hand_delivery' && _selectedDeliveryMethod != 'pick_go';
    if (needsAddress && _deliveryAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une adresse de livraison'), backgroundColor: Colors.red),
      );
      return;
    }

    // #20 — Dialog de confirmation pour wallet et mobile money
    if (_paymentMethod != 'card') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirmer le paiement', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Montant total : ${total.toStringAsFixed(2)} \$',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Méthode : ${_paymentMethod == 'wallet' ? 'Portefeuille Oli' : 'Mobile Money'}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                'Adresse : $_deliveryAddress',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cette action est irréversible.',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E7DBA)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
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
        deliveryMethodId: _selectedDeliveryMethod,
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

        // SINON (Wallet / Mobile Money) -> Redirection vers page de confirmation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => OrderSuccessPage(order: order)),
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
