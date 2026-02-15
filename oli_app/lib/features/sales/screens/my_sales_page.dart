import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/seller_orders_provider.dart';
import '../widgets/seller_order_card.dart';

/// Page "Mes Ventes" - Gestion des commandes en tant que vendeur
class MySalesPage extends ConsumerStatefulWidget {
  const MySalesPage({super.key});

  @override
  ConsumerState<MySalesPage> createState() => _MySalesPageState();
}

class _MySalesPageState extends ConsumerState<MySalesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(sellerOrdersProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerOrdersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const oliBlue = Color(0xFF1E7DBA);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mes Ventes 🔑 v2'),
        backgroundColor: oliBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(sellerOrdersProvider.notifier).loadAll(),
          ),
        ],
      ),
      body: Column(
        children: [
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
                            return SellerOrderCard(
                              order: state.orders[index],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
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
}
