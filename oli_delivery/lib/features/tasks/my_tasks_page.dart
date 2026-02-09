import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/delivery_service.dart';

class MyTasksPage extends ConsumerStatefulWidget {
  const MyTasksPage({super.key});

  @override
  ConsumerState<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends ConsumerState<MyTasksPage> {
  late Future<List<dynamic>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = Future.value([]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshTasks());
  }

  Future<void> _refreshTasks() async {
    setState(() {
      _tasksFuture = ref.read(deliveryServiceProvider).getMyTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshTasks,
      child: FutureBuilder<List<dynamic>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erreur: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _refreshTasks,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune tâche en cours',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Acceptez une livraison depuis l\'onglet "Disponibles"',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _refreshTasks,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualiser'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskCard(task);
            },
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final address = task['delivery_address'] ?? 'Adresse inconnue';
    final status = task['status'] ?? 'assigned';
    final total = task['total_amount'] ?? 0;
    final customerName = task['customer_name'] ?? 'Client';
    final customerPhone = task['customer_phone'] ?? '';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'assigned':
        statusColor = Colors.blue;
        statusLabel = 'Assignée';
        statusIcon = Icons.assignment_ind;
        break;
      case 'picked_up':
        statusColor = Colors.orange;
        statusLabel = 'Récupérée';
        statusIcon = Icons.inventory;
        break;
      case 'in_transit':
        statusColor = Colors.purple;
        statusLabel = 'En route';
        statusIcon = Icons.local_shipping;
        break;
      case 'delivered':
        statusColor = Colors.green;
        statusLabel = 'Livrée';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = status;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/order/${task['order_id'] ?? task['id']}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: statusColor,
                        child: Icon(statusIcon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Livraison #${task['order_id'] ?? task['id']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            customerName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Destination
              Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (customerPhone.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      customerPhone,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$$total',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/order/${task['order_id'] ?? task['id']}'),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Gérer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
