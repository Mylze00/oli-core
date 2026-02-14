import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../orders/providers/orders_provider.dart';
import '../../../orders/screens/purchases_page.dart';
import '../../../../providers/exchange_rate_provider.dart';

/// Résumé compact de l'historique des transactions sur le profil
class TransactionSummaryCard extends ConsumerWidget {
  final Color cardColor;
  final Color textColor;

  const TransactionSummaryCard({
    super.key,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Historique Transactions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesPage())),
                child: Row(
                  children: [
                    Text('Tout voir', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[600]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats
          ordersAsync.when(
            loading: () => const Center(child: SizedBox(height: 40, child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) => Text('Données indisponibles', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            data: (orders) {
              final total = orders.length;
              final delivered = orders.where((o) => o.status == 'delivered').length;
              final inProgress = orders.where((o) => ['paid', 'processing', 'shipped'].contains(o.status)).length;
              final cancelled = orders.where((o) => o.status == 'cancelled').length;
              final totalSpent = orders
                  .where((o) => o.status != 'cancelled')
                  .fold<double>(0, (sum, o) => sum + o.totalAmount);

              return Column(
                children: [
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCircle(total.toString(), 'Total', const Color(0xFF1E7DBA)),
                      _buildStatCircle(inProgress.toString(), 'En cours', Colors.orange),
                      _buildStatCircle(delivered.toString(), 'Livrées', Colors.green),
                      _buildStatCircle(cancelled.toString(), 'Annulées', Colors.red),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Total spent
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E7DBA).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total dépensé',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                        ),
                        Text(
                          exchangeNotifier.formatProductPrice(totalSpent),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E7DBA),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Last 2 orders preview
                  if (orders.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...orders.take(2).map((order) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _statusColor(order.status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_statusIcon(order.status), size: 18, color: _statusColor(order.status)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Commande #${order.id}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                                ),
                                Text(
                                  '${order.items.length} article${order.items.length > 1 ? 's' : ''} · ${order.statusLabel}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            exchangeNotifier.formatProductPrice(order.totalAmount),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ],
                      ),
                    )),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCircle(String value, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered': return Colors.green;
      case 'shipped': return Colors.blue;
      case 'processing': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'delivered': return Icons.check_circle;
      case 'shipped': return Icons.local_shipping;
      case 'processing': return Icons.inventory_2;
      case 'cancelled': return Icons.cancel;
      default: return Icons.receipt_long;
    }
  }
}
