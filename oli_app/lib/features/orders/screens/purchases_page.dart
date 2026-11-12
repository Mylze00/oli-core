import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../models/order_model.dart';
import '../providers/orders_provider.dart';
import '../../../providers/exchange_rate_provider.dart';
import '../../../core/theme/oli_glass.dart';
import 'courier_tracking_page.dart';

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

/// Couleurs de la page, alignées sur la validation de commande (clair ou sombre).
class _OrdersColors {
  final bool isDark;
  final Color background;
  final Color card;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color tile;
  final Color accent;
  final Color success;
  final Color danger;

  const _OrdersColors._(
    this.isDark,
    this.background,
    this.card,
    this.border,
    this.text,
    this.textSecondary,
    this.tile,
    this.accent,
    this.success,
    this.danger,
  );

  factory _OrdersColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const _OrdersColors._(
            true,
            Colors.black,
            Color(0xFF1C1C1E),
            Color(0x1FFFFFFF),
            Colors.white,
            Color(0xFF9A9AA0),
            Color(0x14FFFFFF),
            Color(0xFF3B8EF0),
            Color(0xFF30D158),
            Color(0xFFFF6B6B),
          )
        : const _OrdersColors._(
            false,
            Color(0xFFF5F6F8),
            Colors.white,
            Color(0xFFE6E8EC),
            Color(0xFF111418),
            Color(0xFF5F6673),
            Color(0xFFF1F3F6),
            Color(0xFF1A5DE6),
            Color(0xFF16A34A),
            Color(0xFFE5484D),
          );
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
    final c = _OrdersColors.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.text,
        elevation: 0,
        title: Text(
          _title,
          style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
        ),
      ),
      body: ordersAsync.when(
        loading: () => Center(child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Impossible de charger vos commandes.\n$err',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary),
            ),
          ),
        ),
        data: (orders) {
          // « Mes Commandes » regroupe par état ; « En cours » et « Livrées » n'affichent que le leur.
          final entries = _filter == PurchaseFilter.all
              ? _groupedEntries(orders)
              : orders.where((o) => _filter.matches(o.status)).toList();

          if (entries.isEmpty) return _buildEmpty(c);

          return RefreshIndicator(
            color: c.accent,
            onRefresh: () async => ref.invalidate(ordersProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return entry is Order ? _buildOrderCard(c, entry) : _buildSectionHeader(c, entry as (String, int));
              },
            ),
          );
        },
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

  /// Titres de section (avec leur nombre) et commandes, dans l'ordre d'affichage.
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
      entries
        ..add((title, list.length))
        ..addAll(list);
    }

    for (final (title, statuses) in sections) {
      addSection(title, orders.where((o) => statuses.contains(o.status)));
    }
    final known = sections.expand((section) => section.$2).toSet();
    addSection('Autres', orders.where((o) => !known.contains(o.status)));
    return entries;
  }

  Widget _buildSectionHeader(_OrdersColors c, (String, int) section) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Row(
        children: [
          Text(
            section.$1,
            style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${section.$2}',
              style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(_OrdersColors c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: c.tile, shape: BoxShape.circle),
            child: Icon(Icons.shopping_bag_outlined, size: 38, color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            _emptyMessage(),
            style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('Vos achats apparaîtront ici', style: TextStyle(color: c.textSecondary, fontSize: 14)),
        ],
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

  // ─── Carte de commande ─────────────────────────────────────────────

  Widget _buildOrderCard(_OrdersColors c, Order order) {
    final ex = ref.read(exchangeRateProvider.notifier);
    final isExpanded = _expandedOrderId == order.id;
    final showCode = order.deliveryCode != null && const ['processing', 'ready', 'shipped'].contains(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpanded ? c.accent.withValues(alpha: 0.5) : c.border),
        boxShadow: c.isDark ? null : const [BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête : numéro, date, statut (touchez pour déplier)
          InkWell(
            onTap: () => setState(() => _expandedOrderId = isExpanded ? null : order.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commande n° ${order.id}',
                          style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(_formatFullDate(order.createdAt), style: TextStyle(color: c.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  _buildStatusPill(c, order),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, color: c.textSecondary, size: 22),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: c.border),

          // Articles : le premier replié, tous dépliés
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                for (final item in isExpanded ? order.items : order.items.take(1)) _buildItemRow(c, item, ex),
                if (!isExpanded && order.items.length > 1)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '+ ${order.items.length - 1} autre${order.items.length > 2 ? 's' : ''} article${order.items.length > 2 ? 's' : ''}',
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Détails
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: isExpanded ? _buildDetails(c, order) : const SizedBox(width: double.infinity),
          ),

          // État : paiement attendu, annulée, ou suivi en 4 étapes
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: _buildProgress(c, order)),

          if (const ['processing', 'ready', 'shipped'].contains(order.status)) _buildTrackButton(c, order),

          if (showCode) _buildDeliveryCode(c, order),

          Divider(height: 1, color: c.border),
          _buildFooter(c, order, ex),
        ],
      ),
    );
  }

  /// Pastille de statut neutre : point coloré, texte lisible (jamais orange).
  Widget _buildStatusPill(_OrdersColors c, Order order) {
    final Color dot;
    switch (order.status) {
      case 'paid':
      case 'processing':
      case 'ready':
      case 'shipped':
        dot = c.accent;
        break;
      case 'delivered':
        dot = c.success;
        break;
      case 'cancelled':
      case 'refunded':
        dot = c.danger;
        break;
      default:
        dot = c.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            order.statusLabel,
            style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(_OrdersColors c, OrderItem item, dynamic ex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.tile,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.imageUrl == null
                ? Icon(Icons.shopping_bag_outlined, color: c.textSecondary, size: 22)
                : Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.shopping_bag_outlined, color: c.textSecondary, size: 22),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    'Qté ${item.quantity}',
                    if (item.sellerName != null && item.sellerName!.isNotEmpty) item.sellerName!,
                  ].join(' · '),
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            ex.formatProductPrice(item.total),
            style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(_OrdersColors c, Order order) {
    final rows = <(IconData, String, String)>[
      (Icons.schedule_rounded, 'Livraison estimée', _estimateDelivery(order)),
      if (order.paymentMethod != null)
        (Icons.payments_outlined, 'Paiement', _formatPaymentMethod(order.paymentMethod!)),
      if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
        (Icons.home_outlined, 'Adresse', order.deliveryAddress!),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 44, color: c.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(rows[i].$1, size: 18, color: c.textSecondary),
                  const SizedBox(width: 14),
                  Text(rows[i].$2, style: TextStyle(color: c.textSecondary, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rows[i].$3,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Suivi ─────────────────────────────────────────────────────────

  Widget _buildProgress(_OrdersColors c, Order order) {
    if (order.status == 'pending') {
      return _stateBanner(
        c,
        Icons.hourglass_empty_rounded,
        'En attente de paiement',
        'Le paiement n\'est pas encore confirmé. Annulez la commande si vous ne la payez pas.',
      );
    }
    if (order.status == 'cancelled' || order.status == 'refunded') {
      return _stateBanner(
        c,
        Icons.block_rounded,
        'Commande annulée',
        'Cette commande ne sera pas traitée.',
        iconColor: c.danger,
      );
    }

    final current = _statusToStep(order.status);
    const steps = [
      (Icons.receipt_long_outlined, 'Commandée'),
      (Icons.inventory_2_outlined, 'Préparation'),
      (Icons.local_shipping_outlined, 'En route'),
      (Icons.home_outlined, 'Livrée'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _connector(c, visible: i > 0, done: i <= current),
                      ),
                      _stepDot(
                        c,
                        steps[i].$1,
                        done: i < current || (i == current && order.status == 'delivered'),
                        current: i == current,
                      ),
                      Expanded(
                        child: _connector(c, visible: i < steps.length - 1, done: i < current),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      color: i <= current ? c.text : c.textSecondary,
                      fontSize: 11,
                      fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepDot(_OrdersColors c, IconData icon, {required bool done, required bool current}) {
    final filled = done || current;
    final color = done ? c.success : c.accent;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : c.tile,
        boxShadow: current && !done ? [BoxShadow(color: c.accent.withValues(alpha: 0.35), blurRadius: 8)] : null,
      ),
      child: Icon(done ? Icons.check_rounded : icon, size: 15, color: filled ? Colors.white : c.textSecondary),
    );
  }

  Widget _connector(_OrdersColors c, {required bool visible, required bool done}) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      height: 2,
      decoration: BoxDecoration(color: done ? c.success : c.border, borderRadius: BorderRadius.circular(1)),
    );
  }

  int _statusToStep(String status) {
    switch (status) {
      case 'processing':
      case 'ready':
        return 1;
      case 'shipped':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }

  Widget _stateBanner(_OrdersColors c, IconData icon, String title, String subtitle, {Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: iconColor ?? c.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ouvre la carte de suivi du livreur.
  Widget _buildTrackButton(_OrdersColors c, Order order) {
    final enRoute = order.status == 'shipped';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: enRoute ? c.accent : c.tile,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => CourierTrackingPage(orderId: order.id))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.two_wheeler_rounded, color: enRoute ? Colors.white : c.text, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suivre le livreur',
                        style: TextStyle(
                          color: enRoute ? Colors.white : c.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        enRoute
                            ? 'Voir son parcours en direct sur la carte'
                            : 'Disponible dès qu\'un livreur prend la course',
                        style: TextStyle(
                          color: enRoute ? Colors.white.withValues(alpha: 0.85) : c.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: enRoute ? Colors.white : c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Code de réception : QR et code à montrer au livreur (ou au guichet PickGo).
  Widget _buildDeliveryCode(_OrdersColors c, Order order) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.tile,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 104,
            height: 104,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: QrImageView(data: order.deliveryCode!, version: QrVersions.auto, backgroundColor: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 16, color: c.success),
                    const SizedBox(width: 6),
                    Text(
                      'Code de réception',
                      style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  order.deliveryCode!,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Montrez-le au livreur ou au guichet à la remise du colis',
                  style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(_OrdersColors c, Order order, dynamic ex) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                Text(
                  ex.formatProductPrice(order.totalAmount),
                  style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                if (order.deliveryFee > 0)
                  Text(
                    'dont livraison ${ex.formatProductPrice(order.deliveryFee)}',
                    style: TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (order.canCancel) _footerButton(c, 'Annuler', () => _cancelOrder(order.id)),
          if (order.isRefundUnderReview)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(20)),
              child: Text(
                'Remboursement en examen',
                style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            )
          else if (order.canRequestRefund)
            _footerButton(c, 'Remboursement', () => _requestRefund(order.id)),
        ],
      ),
    );
  }

  Widget _footerButton(_OrdersColors c, String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: c.danger,
        backgroundColor: c.danger.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: const StadiumBorder(),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  String _formatFullDate(DateTime date) {
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _estimateDelivery(Order order) {
    if (order.status == 'delivered') return 'Livrée';
    if (order.status == 'cancelled') return 'Annulée';
    // Estimate 3-7 days from creation
    final est = order.createdAt.add(const Duration(days: 5));
    return _formatFullDate(est);
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'wallet':
        return 'Wallet OLI';
      case 'mobile_money':
        return 'Mobile Money';
      case 'card':
        return 'Carte bancaire';
      default:
        return method;
    }
  }

  Future<void> _requestRefund(int orderId) async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _RefundReasonDialog());
    if (reason == null || !mounted) return;

    final error = await ref.read(orderServiceProvider).requestRefund(orderId, reason);
    if (!mounted) return;
    if (error == null) ref.invalidate(ordersProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Demande envoyée. Un administrateur va l\'examiner.')));
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Erreur lors de l\'annulation'), backgroundColor: Colors.red));
        }
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
          const Text('Un administrateur examinera votre demande. La commande reste bloquée pendant cet examen.'),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => TextButton(
            onPressed: value.text.trim().isEmpty ? null : () => Navigator.pop(context, value.text.trim()),
            child: const Text('Envoyer'),
          ),
        ),
      ],
    );
  }
}
