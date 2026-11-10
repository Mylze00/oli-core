import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../models/order_model.dart';
import '../providers/orders_provider.dart';
import '../../../providers/exchange_rate_provider.dart';
import '../widgets/order_progress_bar.dart';
import '../../../core/theme/oli_glass.dart';

/// Filtres de la page « Mes Achats ».
/// Les définitions de statut sont celles des compteurs du profil (dashboard_section.dart),
/// pour que le nombre affiché sur la tuile corresponde à la liste filtrée.
enum PurchaseFilter {
  all('Toutes'),
  inProgress('En cours'),
  delivered('Livrées');

  final String label;
  const PurchaseFilter(this.label);

  static const List<String> inProgressStatuses = ['paid', 'processing', 'ready', 'shipped'];

  bool matches(String status) {
    switch (this) {
      case PurchaseFilter.all:
        return true;
      case PurchaseFilter.inProgress:
        return inProgressStatuses.contains(status);
      case PurchaseFilter.delivered:
        return status == 'delivered';
    }
  }
}

/// Page "Mes Achats" - Historique des commandes (Reel)
class PurchasesPage extends ConsumerStatefulWidget {
  /// Filtre sélectionné à l'ouverture (ex: « En Cours » ou « Livrées » depuis le profil).
  final PurchaseFilter initialFilter;

  const PurchasesPage({super.key, this.initialFilter = PurchaseFilter.all});

  @override
  ConsumerState<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends ConsumerState<PurchasesPage> {
  int? _expandedOrderId;
  Timer? _pollTimer;
  late final PurchaseFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    // Auto-refresh toutes les 10s
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) ref.invalidate(ordersProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);
    ref.watch(exchangeRateProvider);

    return Container(
      decoration: const BoxDecoration(gradient: oliBackgroundGradient),
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err', style: const TextStyle(color: Colors.red))),
        data: (orders) {
          // « Mes Commandes » regroupe par état ; « En cours » et « Livrées » n'affichent que le leur.
          final entries = _filter == PurchaseFilter.all
              ? _groupedEntries(orders)
              : orders.where((o) => _filter.matches(o.status)).toList();

          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade700),
                  const SizedBox(height: 16),
                  Text(
                    _emptyMessage(),
                    style: TextStyle(color: OliPalette.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return entry is Order ? _buildOrderCard(entry) : _buildSectionHeader(entry as String);
            },
          );
        },
      ),
      ),
    );
  }

  String get _title {
    switch (_filter) {
      case PurchaseFilter.all:
        return 'Mes commandes';
      case PurchaseFilter.inProgress:
        return 'Commandes en cours';
      case PurchaseFilter.delivered:
        return 'Commandes livrées';
    }
  }

  /// Titres de section et commandes, dans l'ordre d'affichage.
  List<Object> _groupedEntries(List<Order> orders) {
    const sections = <(String, List<String>)>[
      ('En attente de paiement', ['pending']),
      ('En cours', PurchaseFilter.inProgressStatuses),
      ('Livrées', ['delivered']),
      ('Annulées', ['cancelled']),
    ];
    final entries = <Object>[];
    void addSection(String title, Iterable<Order> matching) {
      final list = matching.toList();
      if (list.isEmpty) return;
      entries..add('$title (${list.length})')..addAll(list);
    }

    for (final (title, statuses) in sections) {
      addSection(title, orders.where((o) => statuses.contains(o.status)));
    }
    final known = sections.expand((section) => section.$2).toSet();
    addSection('Autres', orders.where((o) => !known.contains(o.status)));
    return entries;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _emptyMessage() {
    switch (_filter) {
      case PurchaseFilter.all:
        return 'Aucune commande';
      case PurchaseFilter.inProgress:
        return 'Aucune commande en cours';
      case PurchaseFilter.delivered:
        return 'Aucune commande livrée';
    }
  }

  Widget _buildOrderCard(Order order) {
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    final isExpanded = _expandedOrderId == order.id;

    return GestureDetector(
      onTap: () => setState(() {
        _expandedOrderId = isExpanded ? null : order.id;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: oliGlassCardDecoration(highlighted: isExpanded),
        child: Column(
          children: [
            // Header avec date et statut
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: OliPalette.hairline)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('Commande #${order.id}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: OliPalette.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                  _buildStatusChip(order),
                ],
              ),
            ),

            // Items preview (compact: first item only when collapsed)
            if (!isExpanded)
              ...order.items.take(1).map((item) => _buildItemRow(item, exchangeNotifier)),

            // EXPANDED: full detail view
            if (isExpanded) ...[
              // Date de commande
              _buildInfoRow(Icons.calendar_today, 'Date de commande', _formatFullDate(order.createdAt)),

              // Estimation de livraison
              _buildInfoRow(Icons.schedule, 'Livraison estimée', _estimateDelivery(order)),

              // Méthode de paiement
              if (order.paymentMethod != null)
                _buildInfoRow(Icons.payment, 'Paiement', _formatPaymentMethod(order.paymentMethod!)),

              // Adresse de livraison
              if (order.deliveryAddress != null)
                _buildInfoRow(Icons.location_on, 'Adresse', order.deliveryAddress!),

              const Divider(color: Colors.white10, indent: 16, endIndent: 16),

              // Tous les articles avec images
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Articles (${order.items.length})',
                      style: TextStyle(color: OliPalette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              ...order.items.map((item) => _buildDetailedItem(item, exchangeNotifier)),
            ],

            if (!isExpanded && order.items.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '+ ${order.items.length - 1} autre${order.items.length > 2 ? 's' : ''} article${order.items.length > 2 ? 's' : ''} · Cliquez pour détails',
                  style: TextStyle(color: OliPalette.textSecondary, fontSize: 11),
                ),
              ),

            // CODE DE LIVRAISON — visible pour l'acheteur quand la commande est en route
            if (order.deliveryCode != null &&
                (order.status == 'shipped' || order.status == 'processing' || order.status == 'ready'))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.shade900, Colors.green.shade800]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade400, width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.verified_user, color: Colors.green.shade300, size: 20),
                      const SizedBox(width: 8),
                      Text('CODE DE RÉCEPTION',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade300,
                              letterSpacing: 1)),
                    ]),
                    const SizedBox(height: 12),
                    // QR Code scannable par le livreur
                    Container(
                      width: 140,
                      height: 140,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: QrImageView(
                        data: order.deliveryCode!,
                        version: QrVersions.auto,
                        size: 124,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade600),
                      ),
                      child: Text(order.deliveryCode!,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                            color: Colors.white,
                            fontFamily: 'monospace',
                          )),
                    ),
                    const SizedBox(height: 8),
                    Text('Communiquez ce code au livreur quand il arrive',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade400),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),

            // Barre de progression
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: OrderProgressBar(status: order.status),
            ),
              
            const Divider(color: OliPalette.hairline, height: 16),

            // Footer avec Total et Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total : ${exchangeNotifier.formatProductPrice(order.totalAmount)}', style: const TextStyle(color: OliPalette.blueOnDark, fontSize: 17, fontWeight: FontWeight.w800)),
                      if (order.deliveryFee > 0)
                        Text('dont livraison: ${exchangeNotifier.formatProductPrice(order.deliveryFee)}', style: TextStyle(color: OliPalette.textSecondary, fontSize: 11)),
                    ],
                  ),
                  ),
                  const SizedBox(width: 12),
                  if (order.canCancel)
                    OutlinedButton(
                      style: oliSecondaryButtonStyle(color: OliPalette.danger),
                      onPressed: () => _cancelOrder(order.id),
                      child: const Text('Annuler'),
                    ),
                  if (order.isRefundUnderReview)
                    const Text(
                      'Remboursement\nen examen',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    )
                  else if (order.canRequestRefund)
                    OutlinedButton(
                      style: oliSecondaryButtonStyle(color: OliPalette.danger),
                      onPressed: () => _requestRefund(order.id),
                      child: const Text('Remboursement'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(OrderItem item, dynamic exchangeNotifier) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildItemImage(item.imageUrl, 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('x${item.quantity}', style: TextStyle(color: OliPalette.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(exchangeNotifier.formatProductPrice(item.total), style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildDetailedItem(OrderItem item, dynamic exchangeNotifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _buildItemImage(item.imageUrl, 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${exchangeNotifier.formatProductPrice(item.price)} × ${item.quantity}',
                  style: TextStyle(color: OliPalette.textSecondary, fontSize: 12),
                ),
                if (item.sellerName != null)
                  Text(
                    'Vendeur: ${item.sellerName}',
                    style: TextStyle(color: OliPalette.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
          Text(
            exchangeNotifier.formatProductPrice(item.total),
            style: const TextStyle(color: Color(0xFF1E7DBA), fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(String? imageUrl, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(imageUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey, size: 20),
              ),
            )
          : const Icon(Icons.image, color: Colors.grey, size: 20),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: OliPalette.blueOnDark),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(color: OliPalette.textSecondary, fontSize: 12)),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(Order order) {
    Color color;
    IconData icon;

    switch (order.status) {
      case 'pending':
      case 'processing':
        color = Colors.orange;
        icon = Icons.access_time;
        break;
      case 'paid':
      case 'ready':
        color = OliPalette.blueOnDark;
        icon = Icons.check_circle_outline;
        break;
      case 'shipped':
        color = OliPalette.blueOnDark;
        icon = Icons.local_shipping;
        break;
      case 'delivered':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(order.statusLabel, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _estimateDelivery(Order order) {
    if (order.status == 'delivered') return 'Livrée ✅';
    if (order.status == 'cancelled') return 'Annulée';
    // Estimate 3-7 days from creation
    final est = order.createdAt.add(const Duration(days: 5));
    return _formatFullDate(est);
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'wallet': return 'Portefeuille Oli';
      case 'mobile_money': return 'Mobile Money';
      case 'card': return 'Carte bancaire';
      default: return method;
    }
  }

  Future<void> _requestRefund(int orderId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RefundReasonDialog(),
    );
    if (reason == null || !mounted) return;

    final error = await ref.read(orderServiceProvider).requestRefund(orderId, reason);
    if (!mounted) return;
    if (error == null) ref.invalidate(ordersProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Demande envoyée. Un administrateur va l\'examiner.')),
    );
  }

  Future<void> _cancelOrder(int orderId) async {
    final confirm = await showOliConfirmDialog(
      context,
      title: 'Annuler la commande ?',
      message: 'Cette action ne peut pas être annulée.',
      confirmLabel: 'Oui, annuler',
      cancelLabel: 'Non',
      destructive: true,
    );

    if (confirm) {
      final success = await ref.read(orderServiceProvider).cancelOrder(orderId);
      if (success) {
        ref.invalidate(ordersProvider);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commande annulée')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de l\'annulation'), backgroundColor: Colors.red));
      }
    }
  }
}

/// Saisie du motif d'une demande de remboursement
class _RefundReasonDialog extends StatefulWidget {
  const _RefundReasonDialog();

  @override
  State<_RefundReasonDialog> createState() => _RefundReasonDialogState();
}

class _RefundReasonDialogState extends State<_RefundReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Demander un remboursement'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Un administrateur examinera votre demande. La commande reste bloquée pendant cet examen.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Motif de votre demande'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => TextButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, value.text.trim()),
            child: const Text('Envoyer'),
          ),
        ),
      ],
    );
  }
}
