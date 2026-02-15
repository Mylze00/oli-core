import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/delivery_service.dart';
import '../../services/location_service.dart';
import 'qr_scanner_page.dart';

class OrderDetailsPage extends ConsumerStatefulWidget {
  final int orderId;
  const OrderDetailsPage({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends ConsumerState<OrderDetailsPage> {
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  bool _isAccepting = false;
  bool _isDelivering = false;
  bool _isPickingUp = false;
  double? _distanceKm;
  bool _gpsAvailable = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    // Auto-refresh toutes les 10s pour refléter les changements de statut
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Refresh silencieux (pas de loader visible)
  Future<void> _silentRefresh() async {
    final service = ref.read(deliveryServiceProvider);
    final available = await service.getAvailableOrders();
    var order = available.firstWhere(
      (o) => (o['id'] == widget.orderId || o['order_id'] == widget.orderId),
      orElse: () => null,
    );
    if (order == null) {
      final tasks = await service.getMyTasks();
      order = tasks.firstWhere(
        (o) => (o['id'] == widget.orderId || o['order_id'] == widget.orderId),
        orElse: () => null,
      );
    }
    if (mounted && order != null) {
      setState(() => _order = order);
    }
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(deliveryServiceProvider);

      // Chercher dans les disponibles ET dans mes tâches
      final available = await service.getAvailableOrders();
      var order = available.firstWhere(
        (o) => (o['id'] == widget.orderId || o['order_id'] == widget.orderId),
        orElse: () => null,
      );

      if (order == null) {
        final tasks = await service.getMyTasks();
        order = tasks.firstWhere(
          (o) => (o['id'] == widget.orderId || o['order_id'] == widget.orderId),
          orElse: () => null,
        );
      }

      setState(() {
        _order = order;
        _isLoading = false;
      });

      // Calculer la distance si possible
      if (_order != null) {
        _updateDistance();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateDistance() async {
    final lat = _order?['delivery_lat'] ?? _order?['lat'];
    final lng = _order?['delivery_lng'] ?? _order?['lng'];

    if (lat == null || lng == null) return;

    final position = await LocationService.getCurrentPosition();
    if (position != null && mounted) {
      final destLat = (lat is String) ? double.tryParse(lat) ?? 0.0 : (lat as num).toDouble();
      final destLng = (lng is String) ? double.tryParse(lng) ?? 0.0 : (lng as num).toDouble();

      setState(() {
        _distanceKm = LocationService.distanceBetween(
          position.latitude,
          position.longitude,
          destLat,
          destLng,
        );
        _gpsAvailable = true;
      });
    }
  }

  Future<void> _acceptOrder() async {
    setState(() => _isAccepting = true);

    // Obtenir la position GPS au moment de l'acceptation
    final position = await LocationService.getCurrentPosition();

    final success = await ref.read(deliveryServiceProvider).acceptOrder(widget.orderId);
    setState(() => _isAccepting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Commande acceptée !' : 'Erreur lors de l\'acceptation'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) {
        // Envoyer la position initiale si disponible
        if (position != null) {
          await ref.read(deliveryServiceProvider).updateStatus(
            widget.orderId,
            'assigned',
            lat: position.latitude,
            lng: position.longitude,
          );
        }
        _loadOrder();
      }
    }
  }

  /// Vérifier le code de livraison fourni par l'acheteur
  Future<void> _verifyDeliveryCode() async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Code de livraison'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez le code de réception fourni par le client pour confirmer la livraison.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'CODE',
                counterText: '',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.length == 6) Navigator.pop(ctx, v);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (code == null || !mounted) return;

    setState(() => _isDelivering = true);

    // _order['id'] = delivery_orders.id (attendu par POST /delivery/:id/verify)
    final deliveryOrderId = _order?['id'] ?? widget.orderId;
    final success = await ref.read(deliveryServiceProvider).verifyDeliveryCode(
      deliveryOrderId,
      code,
    );

    setState(() => _isDelivering = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Livraison confirmée !' : '❌ Code invalide, réessayez.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) {
        context.go('/dashboard');
      }
    }
  }

  Future<void> _openMaps() async {
    final address = _order?['delivery_address'];
    if (address == null) return;

    final encodedAddress = Uri.encodeComponent(address);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir Maps')),
      );
    }
  }

  Future<void> _callCustomer() async {
    final phone = _order?['customer_phone'];
    if (phone == null) return;

    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _scanQR() async {
    // _order['id'] = delivery_orders.id (attendu par POST /delivery/:id/verify)
    final deliveryOrderId = _order?['id'] ?? widget.orderId;
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QrScannerPage(orderId: deliveryOrderId),
      ),
    );

    if (verified == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ QR vérifié ! Livraison confirmée.'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/dashboard');
    }
  }

  /// Vérifier le code de retrait chez le vendeur (pickup)
  Future<void> _verifyPickup() async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Code de retrait'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez le code de retrait fourni par le vendeur pour confirmer la récupération du colis.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'CODE',
                counterText: '',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.length == 6) Navigator.pop(ctx, v);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (code == null || !mounted) return;

    setState(() => _isPickingUp = true);

    final realOrderId = _order?['order_id'] ?? widget.orderId;
    final success = await ref.read(deliveryServiceProvider).verifyPickupCode(
      realOrderId,
      code,
    );

    setState(() => _isPickingUp = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Colis récupéré ! En route vers le client.' : '❌ Code invalide, réessayez.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) _loadOrder();
    }
  }

  /// Scanner QR pour le retrait chez le vendeur
  Future<void> _scanPickupQR() async {
    final realOrderId = _order?['order_id'] ?? widget.orderId;
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QrScannerPage(
          orderId: realOrderId,
          isPickup: true,
        ),
      ),
    );

    if (verified == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Pickup vérifié ! Colis récupéré.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadOrder();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détails commande')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détails commande')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Commande non trouvée'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadOrder,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final status = _order!['status'] ?? 'pending';
    final orderStatus = _order!['order_status'] ?? _order!['status'] ?? 'pending';
    final isAccepted = status == 'assigned' || status == 'shipped' ||
        status == 'picked_up' || status == 'in_transit' ||
        status == 'ready';

    return Scaffold(
      appBar: AppBar(
        title: Text('Commande #${_order!['order_id'] ?? _order!['id']}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrder,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📦 Statut
            _buildStatusCard(status),
            const SizedBox(height: 16),

            // 🗺️ Navigation & GPS
            _buildMapSection(),
            const SizedBox(height: 16),

            // 💰 Montant
            _buildInfoCard(
              icon: Icons.attach_money,
              title: 'Montant total',
              value: '\$${_order!['total_amount'] ?? 0}',
              color: Colors.green,
            ),
            const SizedBox(height: 16),

            // 👤 Client
            _buildCustomerCard(),
            const SizedBox(height: 16),

            // 📋 Articles
            if (_order!['items'] != null) ...[
              _buildItemsCard(),
              const SizedBox(height: 24),
            ],

            // 🔘 Actions selon la phase
            if (!isAccepted) ...[
              // Phase 1 : Pas encore acceptée
              ElevatedButton.icon(
                onPressed: _isAccepting ? null : _acceptOrder,
                icon: _isAccepting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle),
                label: const Text('ACCEPTER LA LIVRAISON'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ] else if (status == 'assigned' || status == 'ready') ...[
              // Phase 2 : Acceptée → doit récupérer le colis chez le vendeur
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.storefront, color: Colors.orange.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Récupérer le colis', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                          const SizedBox(height: 2),
                          Text('Rendez-vous chez le vendeur et entrez le code de retrait', style: TextStyle(fontSize: 12, color: Colors.orange.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isPickingUp ? null : _verifyPickup,
                      icon: _isPickingUp
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.dialpad),
                      label: const Text('ENTRER CODE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _scanPickupQR,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('SCANNER QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E7DBA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Phase 3 : Colis récupéré → en route vers le client
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.blue.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Livraison en cours', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                          const SizedBox(height: 2),
                          Text('Dirigez-vous vers le client et confirmez la livraison', style: TextStyle(fontSize: 12, color: Colors.blue.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _scanQR,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('SCANNER QR CLIENT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E7DBA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isDelivering ? null : _verifyDeliveryCode,
                icon: _isDelivering
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.dialpad),
                label: const Text('ENTRER CODE CLIENT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── MAP & NAVIGATION SECTION ───────────────────────────────

  Widget _buildMapSection() {
    final address = _order?['delivery_address'] ?? 'Adresse inconnue';

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Adresse + distance
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Destination',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            address,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_distanceKm != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E7DBA).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.straighten, size: 14, color: Color(0xFF1E7DBA)),
                            const SizedBox(width: 4),
                            Text(
                              _distanceKm! < 1
                                  ? '${(_distanceKm! * 1000).toInt()} m'
                                  : '${_distanceKm!.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                color: Color(0xFF1E7DBA),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Boutons de navigation
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openMaps,
                    icon: const Icon(Icons.navigation, size: 20),
                    label: const Text('Naviguer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E7DBA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _updateDistance();
                      if (mounted && _distanceKm != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Distance: ${_distanceKm!.toStringAsFixed(1)} km',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('GPS indisponible ou pas de coordonnées'),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      _gpsAvailable ? Icons.gps_fixed : Icons.gps_not_fixed,
                      size: 20,
                    ),
                    label: const Text('Position'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E7DBA),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: const BorderSide(color: Color(0xFF1E7DBA)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CUSTOMER CARD ─────────────────────────────────────────

  Widget _buildCustomerCard() {
    final name = _order?['customer_name'];
    final phone = _order?['customer_phone'];

    if (name == null && phone == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF1E7DBA),
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Client',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    name ?? 'Client',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (phone != null)
                    Text(
                      phone,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                ],
              ),
            ),
            if (phone != null)
              IconButton(
                onPressed: _callCustomer,
                icon: const Icon(Icons.phone, color: Colors.green),
                tooltip: 'Appeler le client',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.withOpacity(0.1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── ITEMS CARD ────────────────────────────────────────────

  Widget _buildItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.list_alt, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Articles',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...(_order!['items'] as List).map<Widget>((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item['quantity']}x ${item['product_name'] ?? 'Produit'}',
                      ),
                    ),
                    Text('\$${item['price'] ?? 0}'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── STATUS & INFO CARDS ───────────────────────────────────

  Widget _buildStatusCard(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'assigned':
        color = Colors.blue;
        label = 'Assignée';
        icon = Icons.assignment_ind;
        break;
      case 'shipped':
        color = Colors.blue;
        label = 'En cours de livraison';
        icon = Icons.local_shipping;
        break;
      case 'picked_up':
        color = Colors.orange;
        label = 'Colis récupéré';
        icon = Icons.inventory;
        break;
      case 'in_transit':
        color = Colors.purple;
        label = 'En route';
        icon = Icons.directions_bike;
        break;
      case 'processing':
        color = Colors.orange;
        label = 'En préparation';
        icon = Icons.hourglass_top;
        break;
      case 'delivered':
        color = Colors.green;
        label = 'Livrée';
        icon = Icons.check_circle;
        break;
      default:
        color = Colors.grey;
        label = 'En attente';
        icon = Icons.pending;
    }

    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
