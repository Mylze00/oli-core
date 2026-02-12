import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/seller_orders_provider.dart';
import '../models/seller_order.dart';
import '../../../providers/exchange_rate_provider.dart';
import '../../../core/user/user_provider.dart';
import '../../chat/chat_page.dart';
import '../../orders/screens/order_tracking_page.dart';

/// Page de détails d'une commande pour le vendeur
class SellerOrderDetailsPage extends ConsumerStatefulWidget {
  final int orderId;

  const SellerOrderDetailsPage({super.key, required this.orderId});

  @override
  ConsumerState<SellerOrderDetailsPage> createState() =>
      _SellerOrderDetailsPageState();
}

class _SellerOrderDetailsPageState
    extends ConsumerState<SellerOrderDetailsPage> {
  SellerOrder? _order;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final order = await ref
        .read(sellerOrdersProvider.notifier)
        .getOrderDetails(widget.orderId);

    setState(() {
      _order = order;
      _isLoading = false;
      _error = order == null ? 'Commande non trouvée' : null;
    });
  }

  void _openChat(SellerOrder order) {
    final user = ref.read(userProvider).value;
    if (user == null) return;

    // Use the first product in the order as context for the chat
    final firstItem = order.items.isNotEmpty ? order.items.first : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          myId: user.id.toString(),
          otherId: order.userId.toString(),
          otherName: order.buyerName ?? 'Acheteur',
          productId: firstItem?.productId,
          productName: firstItem?.productName,
          productImage: firstItem?.productImageUrl,
          productPrice: firstItem?.price,
        ),
      ),
    );
  }

  Future<void> _callBuyer(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le téléphone')),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const oliBlue = Color(0xFF1E7DBA);
    // Watch pour rebuild quand devise/taux change
    ref.watch(exchangeRateProvider);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Commande #${widget.orderId}'),
        backgroundColor: oliBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrder,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildContent(),
      bottomNavigationBar: _order != null && _order!.allowedTransitions.isNotEmpty
          ? _buildBottomActions()
          : null,
    );
  }

  Widget _buildContent() {
    final order = _order!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          _buildStatusCard(order, cardColor, textColor),
          const SizedBox(height: 12),

          // Bouton Suivi de commande
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => OrderTrackingPage(orderId: order.id)),
              ),
              icon: const Icon(Icons.timeline, size: 18),
              label: const Text('Voir le suivi de commande'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Buyer Info
          _buildSection(
            'Informations Acheteur',
            Icons.person_outline,
            cardColor,
            [
              _buildInfoRow('Nom', order.buyerName ?? 'Non renseigné'),
              _buildInfoRow('Téléphone', order.buyerPhone ?? 'Non renseigné'),
              _buildInfoRow('Adresse', order.deliveryAddress ?? 'Non renseignée'),
              const SizedBox(height: 12),
              // Contact buyer buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openChat(order),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Envoyer un message'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E7DBA),
                        side: const BorderSide(color: Color(0xFF1E7DBA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (order.buyerPhone != null) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => _callBuyer(order.buyerPhone!),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Icon(Icons.phone, size: 18),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Order Items
          _buildSection(
            'Produits (${order.items.length})',
            Icons.inventory_2_outlined,
            cardColor,
            order.items.map((item) => _buildItemRow(item)).toList(),
          ),
          const SizedBox(height: 16),

          // Order Summary
          _buildSection(
            'Résumé',
            Icons.receipt_outlined,
            cardColor,
            [
              _buildInfoRow(
                'Sous-total',
                exchangeNotifier.formatProductPrice(order.totalAmount - order.deliveryFee),
              ),
              _buildInfoRow(
                'Livraison',
                exchangeNotifier.formatProductPrice(order.deliveryFee),
              ),
              const Divider(),
              _buildInfoRow(
                'Total',
                exchangeNotifier.formatProductPrice(order.totalAmount),
                isBold: true,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Shipping Info (if shipped)
          if (order.trackingNumber != null || order.carrier != null)
            _buildSection(
              'Expédition',
              Icons.local_shipping_outlined,
              cardColor,
              [
                if (order.carrier != null)
                  _buildInfoRow('Transporteur', order.carrier!),
                if (order.trackingNumber != null)
                  _buildInfoRowWithAction(
                    'N° de suivi',
                    order.trackingNumber!,
                    Icons.copy,
                    () => _copyToClipboard(order.trackingNumber!),
                  ),
                if (order.shippedAt != null)
                  _buildInfoRow('Expédié le', _formatDateTime(order.shippedAt!)),
                if (order.estimatedDelivery != null)
                  _buildInfoRow(
                    'Livraison estimée',
                    _formatDateTime(order.estimatedDelivery!),
                  ),
              ],
            ),

          // Dates
          _buildSection(
            'Dates',
            Icons.calendar_today_outlined,
            cardColor,
            [
              _buildInfoRow('Créée le', _formatDateTime(order.createdAt)),
              if (order.updatedAt != null)
                _buildInfoRow('Mise à jour', _formatDateTime(order.updatedAt!)),
              if (order.deliveredAt != null)
                _buildInfoRow('Livrée le', _formatDateTime(order.deliveredAt!)),
            ],
          ),

          const SizedBox(height: 80), // Space for bottom bar
        ],
      ),
    );
  }

  Widget _buildStatusCard(SellerOrder order, Color cardColor, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStatusIcon(order.status),
          const SizedBox(height: 12),
          Text(
            order.statusLabel,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getStatusDescription(order.status),
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;

    switch (status) {
      case 'paid':
        icon = Icons.payment;
        color = Colors.orange;
        break;
      case 'processing':
        icon = Icons.inventory_2;
        color = Colors.blue;
        break;
      case 'ready':
        icon = Icons.check_box;
        color = Colors.teal;
        break;
      case 'shipped':
        icon = Icons.local_shipping;
        color = Colors.purple;
        break;
      case 'delivered':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'cancelled':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        icon = Icons.pending;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 40, color: color),
    );
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'paid':
        return 'Le client a payé. Préparez la commande.';
      case 'processing':
        return 'En cours de préparation.';
      case 'ready':
        return 'Prête ! En attente du livreur ou du retrait client.';
      case 'shipped':
        return "En route vers le client.";
      case 'delivered':
        return 'Commande livrée avec succès !';
      case 'cancelled':
        return 'Cette commande a été annulée.';
      default:
        return 'En attente de paiement.';
    }
  }

  Widget _buildSection(
    String title,
    IconData icon,
    Color cardColor,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1E7DBA)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithAction(
    String label,
    String value,
    IconData actionIcon,
    VoidCallback onAction,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAction,
                child: Icon(actionIcon, size: 16, color: const Color(0xFF1E7DBA)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(SellerOrderItem item) {
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: item.productImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.productImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.image, color: Colors.grey[400]),
                    ),
                  )
                : Icon(Icons.inventory_2, color: Colors.grey[400]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${exchangeNotifier.formatProductPrice(item.price)} × ${item.quantity}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            exchangeNotifier.formatProductPrice(item.price * item.quantity),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final order = _order!;
    final nextStatus = order.allowedTransitions.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: () => _handleStatusChange(nextStatus),
          icon: Icon(_getActionIcon(nextStatus)),
          label: Text(_getActionLabel(nextStatus)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E7DBA),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getActionIcon(String status) {
    switch (status) {
      case 'processing':
        return Icons.inventory_2_outlined;
      case 'ready':
        return Icons.check_box_outlined;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.check_circle_outline;
      default:
        return Icons.arrow_forward;
    }
  }

  String _getActionLabel(String status) {
    switch (status) {
      case 'processing':
        return 'Commencer la préparation';
      case 'ready':
        return 'Marquer comme prête';
      case 'shipped':
        return 'Marquer comme expédiée';
      case 'delivered':
        return 'Confirmer la livraison';
      default:
        return 'Action suivante';
    }
  }

  Future<void> _handleStatusChange(String newStatus) async {
    if (newStatus == 'shipped') {
      _showShippingDialog();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer'),
        content: Text(
          'Passer la commande en "${SellerOrder.statusLabels[newStatus]}" ?',
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
      final success = await ref
          .read(sellerOrdersProvider.notifier)
          .updateOrderStatus(widget.orderId, newStatus);

      if (success) {
        _loadOrder();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut mis à jour: ${SellerOrder.statusLabels[newStatus]}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showShippingDialog() {
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
              final success = await ref
                  .read(sellerOrdersProvider.notifier)
                  .updateOrderStatus(
                    widget.orderId,
                    'shipped',
                    trackingNumber: trackingController.text.isNotEmpty
                        ? trackingController.text
                        : null,
                    carrier: carrierController.text.isNotEmpty
                        ? carrierController.text
                        : null,
                  );

              if (success) {
                _loadOrder();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Commande expédiée !'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copié dans le presse-papier')),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
