import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/delivery_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    try {
      final orders = await ref.read(deliveryServiceProvider).getAvailableOrders();
      final order = orders.firstWhere(
        (o) => o['id'] == widget.orderId,
        orElse: () => null,
      );
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptOrder() async {
    setState(() => _isAccepting = true);
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
        _loadOrder(); // Refresh order data
      }
    }
  }

  Future<void> _markAsDelivered() async {
    setState(() => _isDelivering = true);
    final success = await ref.read(deliveryServiceProvider).markAsDelivered(widget.orderId);
    setState(() => _isDelivering = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Commande livrée !' : 'Erreur lors de la mise à jour'),
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
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir Maps')),
        );
      }
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
        body: const Center(child: Text('Commande non trouvée')),
      );
    }

    final status = _order!['status'] ?? 'pending';
    final isAccepted = status == 'shipped' || status == 'processing';

    return Scaffold(
      appBar: AppBar(
        title: Text('Commande #${_order!['id']}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📦 Statut
            _buildStatusCard(status),
            const SizedBox(height: 16),

            // 💰 Montant
            _buildInfoCard(
              icon: Icons.attach_money,
              title: 'Montant total',
              value: '\$${_order!['total_amount'] ?? 0}',
              color: Colors.green,
            ),
            const SizedBox(height: 16),

            // 📍 Adresse
            _buildAddressCard(),
            const SizedBox(height: 16),

            // 👤 Client
            if (_order!['customer_name'] != null || _order!['customer_phone'] != null)
              _buildInfoCard(
                icon: Icons.person,
                title: 'Client',
                value: _order!['customer_name'] ?? _order!['customer_phone'] ?? 'Inconnu',
                color: Colors.blue,
              ),
            const SizedBox(height: 16),

            // 📋 Articles
            if (_order!['items'] != null) ...[
              Card(
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
              ),
              const SizedBox(height: 24),
            ],

            // 🔘 Actions
            if (!isAccepted) ...[
              ElevatedButton.icon(
                onPressed: _isAccepting ? null : _acceptOrder,
                icon: _isAccepting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
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
            ] else ...[
              ElevatedButton.icon(
                onPressed: _openMaps,
                icon: const Icon(Icons.navigation),
                label: const Text('NAVIGUER VERS L\'ADRESSE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E7DBA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isDelivering ? null : _markAsDelivered,
                icon: _isDelivering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.done_all),
                label: const Text('MARQUER COMME LIVRÉE'),
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

  Widget _buildStatusCard(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'shipped':
        color = Colors.blue;
        label = 'En cours de livraison';
        icon = Icons.local_shipping;
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    return Card(
      child: InkWell(
        onTap: _openMaps,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adresse de livraison',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      _order!['delivery_address'] ?? 'Adresse inconnue',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
