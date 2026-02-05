import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/delivery_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DeliveryService _deliveryService = DeliveryService();
  late Future<List<dynamic>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _refreshOrders();
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = _deliveryService.getAvailableOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Livraisons'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(child: Text('Aucune livraison disponible'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final address = order['delivery_address'] ?? 'Adresse inconnue';
              final status = order['status'] ?? 'Inconnu';
              final total = order['total_amount'] ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Text('#${order['id']}'),
                  ),
                  title: Text('Commande #${order['id']} - \$$total'),
                  subtitle: Text('Adresse: $address\nStatut: $status'),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: () {
                      // TODO: Navigate to details or accept
                    },
                    child: const Text('Détails'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
