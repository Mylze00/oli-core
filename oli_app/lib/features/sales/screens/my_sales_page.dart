import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/seller_orders_provider.dart';
import '../models/seller_order.dart';
import '../widgets/seller_order_card.dart';
import 'seller_order_details_page.dart';

/// Page "Mes Ventes" - Gestion des commandes en tant que vendeur
class MySalesPage extends ConsumerStatefulWidget {
  const MySalesPage({super.key});

  @override
  ConsumerState<MySalesPage> createState() => _MySalesPageState();
}

class _MySalesPageState extends ConsumerState<MySalesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _tabs = [
    {'label': 'Tout', 'status': null},
    {'label': 'À traiter', 'status': 'paid'},
    {'label': 'En préparation', 'status': 'processing'},
    {'label': 'Expédiées', 'status': 'shipped'},
    {'label': 'Livrées', 'status': 'delivered'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Charger les données au démarrage
    Future.microtask(() {
      ref.read(sellerOrdersProvider.notifier).loadAll();
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final status = _tabs[_tabController.index]['status'] as String?;
      ref.read(sellerOrdersProvider.notifier).fetchOrders(status: status);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerOrdersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const oliBlue = Color(0xFF1E7DBA);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mes Ventes'),
        backgroundColor: oliBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(sellerOrdersProvider.notifier).loadAll(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _tabs.map((tab) {
            final status = tab['status'] as String?;
            final count = status != null ? (state.statusCounts[status] ?? 0) : state.orders.length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab['label']),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          // Stats bar
          if (state.stats != null) _buildStatsBar(state.stats!),

          // Error message
          if (state.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        ref.read(sellerOrdersProvider.notifier).clearError(),
                  ),
                ],
              ),
            ),

          // Orders list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.orders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(sellerOrdersProvider.notifier).loadAll(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.orders.length,
                          itemBuilder: (context, index) {
                            final order = state.orders[index];
                            return SellerOrderCard(
                              order: order,
                              onTap: () => _openOrderDetails(order),
                              onStatusAction: order.allowedTransitions.isNotEmpty
                                  ? () => _quickStatusChange(order)
                                  : null,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(SellerOrderStats stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1E7DBA).withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.notifications_active,
            '${stats.toProcess}',
            'À traiter',
            Colors.orange,
          ),
          _buildStatItem(
            Icons.inventory_2,
            '${stats.processing}',
            'En prépa',
            Colors.blue,
          ),
          _buildStatItem(
            Icons.local_shipping,
            '${stats.shipped}',
            'Expédiées',
            Colors.purple,
          ),
          _buildStatItem(
            Icons.check_circle,
            '${stats.delivered}',
            'Livrées',
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sell_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucune vente',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos commandes clients apparaîtront ici',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  void _openOrderDetails(SellerOrder order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerOrderDetailsPage(orderId: order.id),
      ),
    );
  }

  Future<void> _quickStatusChange(SellerOrder order) async {
    final nextStatus = order.allowedTransitions.first;

    // Pour "shipped", demander le numéro de suivi
    if (nextStatus == 'shipped') {
      _showShippingDialog(order);
      return;
    }

    // Confirmation rapide pour les autres transitions
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer'),
        content: Text(
          'Passer la commande #${order.id} en "${SellerOrder.statusLabels[nextStatus]}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E7DBA),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(sellerOrdersProvider.notifier)
          .updateOrderStatus(order.id, nextStatus);
    }
  }

  void _showShippingDialog(SellerOrder order) {
    final trackingController = TextEditingController();
    final carrierController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Expédier la commande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: carrierController,
              decoration: const InputDecoration(
                labelText: 'Transporteur',
                hintText: 'Ex: DHL, Chronopost...',
                prefixIcon: Icon(Icons.local_shipping),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: trackingController,
              decoration: const InputDecoration(
                labelText: 'Numéro de suivi',
                hintText: 'Ex: 1234567890',
                prefixIcon: Icon(Icons.qr_code),
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
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(sellerOrdersProvider.notifier).updateOrderStatus(
                    order.id,
                    'shipped',
                    trackingNumber: trackingController.text.isNotEmpty
                        ? trackingController.text
                        : null,
                    carrier: carrierController.text.isNotEmpty
                        ? carrierController.text
                        : null,
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E7DBA),
            ),
            child: const Text('Expédier'),
          ),
        ],
      ),
    );
  }
}
