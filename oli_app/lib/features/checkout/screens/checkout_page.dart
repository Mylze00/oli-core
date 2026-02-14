import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../cart/providers/cart_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../../user/providers/address_provider.dart';
import '../../user/models/address_model.dart';
import '../../user/screens/address_management_page.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';
import 'stripe_payment_page.dart';
import 'order_success_page.dart';
import '../../../providers/exchange_rate_provider.dart';

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
  bool _isLoading = false;
  double _deliveryFee = 5.00;
  String _selectedDeliveryMethod = 'oli_standard';

  /// Méthodes de livraison — chargées dynamiquement depuis le backend
  List<Map<String, dynamic>> _deliveryMethods = [];
  bool _methodsLoading = true;

  /// Fallback si l'API échoue
  static const List<Map<String, dynamic>> _fallbackMethods = [
    {'id': 'oli_express', 'label': 'Oli Express', 'icon': 'flash_on', 'time': '1-2h', 'cost': 8.00, 'color': 'amber'},
    {'id': 'oli_standard', 'label': 'Oli Standard', 'icon': 'local_shipping', 'time': '2-5 jours', 'cost': 5.00, 'color': 'blue'},
    {'id': 'partner', 'label': 'Livreur Partenaire', 'icon': 'delivery_dining', 'time': 'Variable', 'cost': 3.00, 'color': 'purple'},
    {'id': 'hand_delivery', 'label': 'Remise en Main Propre', 'icon': 'handshake', 'time': 'À convenir', 'cost': 0.0, 'color': 'teal'},
    {'id': 'pick_go', 'label': 'Pick & Go', 'icon': 'store', 'time': 'Retrait', 'cost': 0.0, 'color': 'green'},
    {'id': 'free', 'label': 'Livraison Gratuite', 'icon': 'card_giftcard', 'time': '3-7 jours', 'cost': 0.0, 'color': 'pink'},
  ];

  /// Mapping d'icônes pour les méthodes de livraison
  static const Map<String, IconData> _methodIcons = {
    'oli_express': Icons.flash_on,
    'oli_standard': Icons.local_shipping,
    'partner': Icons.delivery_dining,
    'hand_delivery': Icons.handshake,
    'pick_go': Icons.store,
    'free': Icons.card_giftcard,
  };

  /// Mapping de couleurs
  static const Map<String, Color> _methodColors = {
    'oli_express': Colors.amber,
    'oli_standard': Colors.blue,
    'partner': Colors.purple,
    'hand_delivery': Colors.teal,
    'pick_go': Colors.green,
    'free': Colors.pink,
  };

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
    // Charger les adresses de l'utilisateur
    Future.microtask(() => ref.read(addressProvider.notifier).loadAddresses());
    // R1: Charger les méthodes de livraison dynamiques
    _loadDeliveryMethods();
  }

  /// R1: Charge les méthodes de livraison depuis le backend
  Future<void> _loadDeliveryMethods() async {
    try {
      final dio = ref.read(dioProvider);
      final items = _checkoutItems;
      
      if (items.isNotEmpty) {
        // Charger les méthodes pour le premier produit
        final productId = items.first.productId;
        final response = await dio.get(
          '${ApiConfig.baseUrl}/api/delivery-methods/product/$productId',
        );
        
        if (response.statusCode == 200) {
          final List<dynamic> methods = response.data is List 
              ? response.data 
              : (response.data['methods'] ?? []);
          
          if (methods.isNotEmpty) {
            setState(() {
              _deliveryMethods = methods.map((m) => {
                'id': m['id']?.toString() ?? '',
                'label': m['label']?.toString() ?? '',
                'icon': _methodIcons[m['id']] ?? Icons.local_shipping,
                'time': m['estimated_time']?.toString() ?? '',
                'cost': double.tryParse(m['cost']?.toString() ?? '0') ?? 0.0,
                'color': _methodColors[m['id']] ?? Colors.grey,
              }).toList();
              // Sélectionner le premier si le sélectionné n'est pas disponible
              final availableIds = _deliveryMethods.map((m) => m['id']).toList();
              if (!availableIds.contains(_selectedDeliveryMethod) && _deliveryMethods.isNotEmpty) {
                _selectedDeliveryMethod = _deliveryMethods.first['id'] as String;
                _deliveryFee = (_deliveryMethods.first['cost'] as double?) ?? 0;
              }
              _methodsLoading = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erreur chargement méthodes livraison: $e');
    }
    
    // Fallback: utiliser les méthodes complètes
    setState(() {
      _deliveryMethods = _fallbackMethods.map((m) => {
        'id': m['id'],
        'label': m['label'],
        'icon': _methodIcons[m['id']] ?? Icons.local_shipping,
        'time': m['time'],
        'cost': m['cost'],
        'color': _methodColors[m['id']] ?? Colors.grey,
      }).toList();
      _methodsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = _checkoutItems;
    final subtotal = _subtotal;
    final total = subtotal + (widget.directPurchaseItem == null ? _deliveryFee : 0); // Livraison déjà incluse dans directPurchaseItem
    ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

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
                        Text(exchangeNotifier.formatProductPrice(item.total), style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )),
                  const Divider(color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sous-total', style: TextStyle(color: Colors.grey)),
                      Text(exchangeNotifier.formatProductPrice(subtotal), style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Livraison', style: TextStyle(color: Colors.grey)),
                      Text(exchangeNotifier.formatProductPrice(_deliveryFee), style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(exchangeNotifier.formatProductPrice(total), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- ADRESSE DE LIVRAISON ---
            _buildSectionTitle('Adresse de livraison'),
            _buildAddressSection(),

            const SizedBox(height: 24),

            // --- MODE DE LIVRAISON ---
            _buildSectionTitle('Mode de livraison'),
            if (_methodsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
              )
            else
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
                    : Text('Confirmer (${exchangeNotifier.formatProductPrice(total)})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildAddressSection() {
    final defaultAddr = ref.watch(defaultAddressProvider);
    
    if (defaultAddr == null) {
      // Pas d'adresse enregistrée — inviter à en ajouter
      return GestureDetector(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressManagementPage()));
          // Recharger les adresses au retour
          ref.read(addressProvider.notifier).loadAddresses();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.add_location_alt, color: Colors.orange[300], size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Aucune adresse enregistrée', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Appuyez pour ajouter une adresse de livraison', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
            ],
          ),
        ),
      );
    }

    // Adresse par défaut trouvée
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(defaultAddr.label, style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressManagementPage()));
                  ref.read(addressProvider.notifier).loadAddresses();
                },
                child: const Text('Modifier', style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            defaultAddr.fullAddress,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          if (defaultAddr.referencePoint != null && defaultAddr.referencePoint!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '📍 ${defaultAddr.referencePoint}',
              style: TextStyle(color: Colors.grey[400], fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
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
              method['cost'] == 0.0 ? 'Gratuit' : ref.read(exchangeRateProvider.notifier).formatProductPrice((method['cost'] as num).toDouble()),
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
    final defaultAddr = ref.read(defaultAddressProvider);
    final needsAddress = _selectedDeliveryMethod != 'hand_delivery' && _selectedDeliveryMethod != 'pick_go';
    if (needsAddress && defaultAddr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter une adresse de livraison'), backgroundColor: Colors.red),
      );
      return;
    }
    final deliveryAddress = defaultAddr?.fullAddress ?? '';

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
                'Montant total : ${ref.read(exchangeRateProvider.notifier).formatProductPrice(total)}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Méthode : ${_paymentMethod == 'wallet' ? 'Portefeuille Oli' : 'Mobile Money'}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                'Adresse : $deliveryAddress',
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
        deliveryAddress: deliveryAddress,
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
