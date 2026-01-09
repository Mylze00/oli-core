import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/delivery_provider.dart';
import '../models/delivery_order_model.dart';

class DeliveryDashboard extends ConsumerStatefulWidget {
  const DeliveryDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends ConsumerState<DeliveryDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Charger les données au démarrage
    Future.microtask(() => ref.read(deliveryProvider.notifier).loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deliveryState = ref.watch(deliveryProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Espace Livreur', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.read(deliveryProvider.notifier).loadData(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(text: "Disponibles"),
            Tab(text: "Mes Courses"),
          ],
        ),
      ),
      body: deliveryState.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAvailableList(deliveryState.availableOrders),
                _buildMyTasksList(deliveryState.myTasks),
              ],
            ),
    );
  }

  Widget _buildAvailableList(List<DeliveryOrder> orders) {
    if (orders.isEmpty) {
      return const Center(child: Text("Aucune course disponible", style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Course #${order.id}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    Text("${order.deliveryFee} \$", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                _buildAddressRow(Icons.store, "Retrait", order.pickupAddress),
                const SizedBox(height: 8),
                _buildAddressRow(Icons.location_on, "Livraison", order.deliveryAddress),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      ref.read(deliveryProvider.notifier).acceptOrder(order.id);
                      _tabController.animateTo(1); // Switch to My Tasks
                    },
                    child: const Text("ACCEPTER LA COURSE", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyTasksList(List<DeliveryOrder> orders) {
    if (orders.isEmpty) {
      return const Center(child: Text("Aucune course en cours", style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          color: Colors.grey[850], // Slightly lighter
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Course #${order.id}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    _buildStatusBadge(order.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text("Client: ${order.customerName ?? 'Inconnu'}", style: const TextStyle(color: Colors.white)),
                Text("Tél: ${order.customerPhone ?? 'Non renseigné'}", style: const TextStyle(color: Colors.grey)),
                const Divider(color: Colors.grey),
                _buildAddressRow(Icons.store, "Retrait", order.pickupAddress),
                const SizedBox(height: 8),
                _buildAddressRow(Icons.location_on, "Livraison", order.deliveryAddress),
                const SizedBox(height: 16),
                if (order.status != 'delivered' && order.status != 'cancelled')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // Ouvrir Map (Placeholder)
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Carte pas encore disponible")));
                          },
                          child: const Text("Voir Carte"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          onPressed: () => _showStatusDialog(context, order),
                          child: const Text("Mettre à jour"),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddressRow(IconData icon, String label, String address) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(address, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    String label = status;
    switch (status) {
      case 'assigned': color = Colors.blue; label = "Assignée"; break;
      case 'picked_up': color = Colors.orange; label = "Récupérée"; break;
      case 'in_transit': color = Colors.purple; label = "En route"; break;
      case 'delivered': color = Colors.green; label = "Livrée"; break;
      case 'cancelled': color = Colors.red; label = "Annulée"; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: color)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  void _showStatusDialog(BuildContext context, DeliveryOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Mettre à jour le statut", style: TextStyle(color: Colors.white)),
        children: [
          _statusOption(ctx, order, 'picked_up', "Colis Récupéré"),
          _statusOption(ctx, order, 'in_transit', "En route"),
          _statusOption(ctx, order, 'delivered', "Livré (Terminé)"),
          const Divider(color: Colors.grey),
           _statusOption(ctx, order, 'cancelled', "Annuler la course", isDestructive: true),
        ],
      ),
    );
  }

  Widget _statusOption(BuildContext ctx, DeliveryOrder order, String status, String label, {bool isDestructive = false}) {
    return SimpleDialogOption(
      onPressed: () {
        ref.read(deliveryProvider.notifier).updateStatus(order.id, status);
        Navigator.pop(ctx);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(label, style: TextStyle(color: isDestructive ? Colors.red : Colors.white, fontSize: 16)),
      ),
    );
  }
}
