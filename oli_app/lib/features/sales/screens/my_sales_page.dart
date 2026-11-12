import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/seller_orders_provider.dart';
import '../widgets/seller_order_card.dart';
import '../../../core/theme/oli_surface.dart';

/// Page "Mes Ventes" - Gestion des commandes en tant que vendeur
class MySalesPage extends ConsumerStatefulWidget {
  final String title;

  /// Statuts affichés ; null affiche toutes les ventes.
  final List<String>? statuses;
  final String emptyMessage;

  const MySalesPage({
    super.key,
    this.title = 'Mes Ventes',
    this.statuses,
    this.emptyMessage = 'Aucune vente',
  });

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
    final statuses = widget.statuses;
    final orders = statuses == null
        ? state.orders
        : state.orders.where((o) => statuses.contains(o.status)).toList();
    final surface = OliSurface.of(context);

    return Scaffold(
      backgroundColor: surface.background,
      appBar: surface.appBar(widget.title, actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: surface.text),
          tooltip: 'Actualiser',
          onPressed: () => ref.read(sellerOrdersProvider.notifier).loadAll(),
        ),
      ]),
      body: Column(
        children: [
          if (state.error != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(color: surface.tile, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: surface.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.error!, style: TextStyle(color: surface.text, fontSize: 13))),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: surface.textSecondary),
                    onPressed: () => ref.read(sellerOrdersProvider.notifier).clearError(),
                  ),
                ],
              ),
            ),
          Expanded(
            child: state.isLoading && orders.isEmpty
                ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: surface.accent))
                : orders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: surface.accent,
                        onRefresh: () => ref.read(sellerOrdersProvider.notifier).loadAll(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: orders.length,
                          itemBuilder: (context, index) => SellerOrderCard(order: orders[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return OliEmptyState(
      icon: Icons.sell_outlined,
      title: widget.emptyMessage,
      subtitle: 'Vos commandes clients apparaîtront ici',
    );
  }
}
