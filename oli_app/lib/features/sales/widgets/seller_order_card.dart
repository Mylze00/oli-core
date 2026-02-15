import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/exchange_rate_provider.dart';
import '../../../core/user/user_provider.dart';
import '../models/seller_order.dart';
import '../providers/seller_orders_provider.dart';
import '../../chat/chat_page.dart';
import '../../orders/widgets/order_progress_bar.dart';

/// Widget carte pour afficher une commande vendeur avec actions intégrées
class SellerOrderCard extends ConsumerStatefulWidget {
  final SellerOrder order;

  const SellerOrderCard({super.key, required this.order});

  @override
  ConsumerState<SellerOrderCard> createState() => _SellerOrderCardState();
}

class _SellerOrderCardState extends ConsumerState<SellerOrderCard> {
  bool _expanded = false;

  SellerOrder get order => widget.order;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: ID + Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Commande #${order.id}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    _buildStatusChip(order.status),
                  ],
                ),
                const SizedBox(height: 8),

                // Buyer info + contact icons
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.buyerName ?? 'Acheteur',
                        style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Contact buttons
                    _buildContactIcons(),
                  ],
                ),
                const SizedBox(height: 8),

                // Items preview
                if (order.items.isNotEmpty) ...[
                  _buildItemsPreview(exchangeNotifier),
                  const SizedBox(height: 8),
                ],

                // Barre de progression
                OrderProgressBar(status: order.status),
                const SizedBox(height: 8),

                // Pickup code visible sans expandre
                if ((order.status == 'processing' || order.status == 'ready') && order.pickupCode != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.key, color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text('Code livreur : ', style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
                        Text(
                          order.pickupCode!,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            color: Colors.orange.shade900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),

                // Footer: Total + Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exchangeNotifier.formatProductPrice(order.totalAmount),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E7DBA),
                          ),
                        ),
                        Text(
                          _formatDate(order.createdAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    // Expand/collapse indicator
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[500],
                    ),
                  ],
                ),

                // Expanded section: details + action buttons
                if (_expanded) ...[
                  const Divider(height: 20),

                  // Order details
                  _buildInfoRow(Icons.calendar_today, 'Date de commande', _formatFullDate(order.createdAt)),
                  if (order.estimatedDelivery != null)
                    _buildInfoRow(Icons.schedule, 'Livraison prévue', _formatFullDate(order.estimatedDelivery!))
                  else if (order.status == 'delivered' && order.deliveredAt != null)
                    _buildInfoRow(Icons.check_circle, 'Livrée le', _formatFullDate(order.deliveredAt!))
                  else if (order.status == 'shipped' && order.shippedAt != null)
                    _buildInfoRow(Icons.local_shipping, 'Expédiée le', _formatFullDate(order.shippedAt!)),
                  if (order.deliveryMethodId != null)
                    _buildInfoRow(Icons.route, 'Mode livraison', _formatDeliveryMethod(order.deliveryMethodId!)),
                  if (order.deliveryAddress != null)
                    _buildInfoRow(Icons.location_on, 'Adresse', order.deliveryAddress!),

                  // All items with larger images
                  if (order.items.length > 2) ...[
                    const Divider(height: 16, color: Colors.black12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Tous les articles (${order.items.length})',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                      ),
                    ),
                    ...order.items.skip(2).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.grey[200],
                            ),
                            child: item.productImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      item.productImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.grey[400]),
                                    ),
                                  )
                                : Icon(Icons.inventory_2, color: Colors.grey[400]),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('${exchangeNotifier.formatProductPrice(item.price)} × ${item.quantity}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],

                  const Divider(height: 16, color: Colors.black12),
                  _buildActionButtons(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactIcons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _openChat,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.chat_bubble_outline, size: 18, color: const Color(0xFF1E7DBA)),
          ),
        ),
        if (order.buyerPhone != null) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _callBuyer(order.buyerPhone!),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.phone_outlined, size: 18, color: Colors.green),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    final buttons = <Widget>[];

    // Pick & Go: seller verifies pickup_code when ready
    if (order.deliveryMethodId == 'pick_go' && order.status == 'ready') {
      buttons.add(_buildFullWidthButton(
        icon: Icons.qr_code_scanner,
        label: 'Vérifier le code client (Pick & Go)',
        color: Colors.green,
        onPressed: _showPickupCodeDialog,
      ));
    }
    // Hand Delivery: seller confirms with delivery_code when processing
    else if (order.deliveryMethodId == 'hand_delivery' && order.status == 'processing') {
      buttons.add(_buildFullWidthButton(
        icon: Icons.handshake,
        label: 'Confirmer la remise en main propre',
        color: Colors.teal,
        onPressed: _showDeliveryCodeDialog,
      ));
    }

    // Afficher le pickup_code quand la commande est en préparation
    // Le livreur doit saisir ce code pour passer à "en cours de livraison"
    if ((order.status == 'processing' || order.status == 'ready') && order.pickupCode != null) {
      buttons.add(Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.key, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Code de retrait pour le livreur',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                order.pickupCode!,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: Colors.orange.shade800,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Communiquez ce code au livreur quand il arrive',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade600),
            ),
          ],
        ),
      ));
    }

    // Standard transitions (paid→processing uniquement)
    for (final nextStatus in order.allowedTransitions) {
      buttons.add(_buildFullWidthButton(
        icon: _getActionIcon(nextStatus),
        label: _getActionLabel(nextStatus),
        color: const Color(0xFF1E7DBA),
        onPressed: () => _handleStatusChange(nextStatus),
      ));
    }

    // Delivery info if shipped
    if (order.trackingNumber != null || order.carrier != null) {
      buttons.add(Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (order.carrier != null)
              Text('🚚 ${order.carrier}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            if (order.trackingNumber != null && order.carrier != null)
              const SizedBox(height: 4),
            if (order.trackingNumber != null)
              Text('📦 Suivi: ${order.trackingNumber}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
        ),
      ));
    }

    if (buttons.isEmpty) {
      return Text(
        _getStatusMessage(order.status),
        style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      );
    }

    return Column(
      children: buttons
          .map((b) => Padding(padding: const EdgeInsets.only(bottom: 8), child: b))
          .toList(),
    );
  }

  Widget _buildFullWidthButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ------  Dialogs (moved from seller_order_details_page)  ------

  void _showPickupCodeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Code client Pick & Go'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Entrez le code de commande présenté par le client :'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Ex: ABC123',
                border: OutlineInputBorder(),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              final success = await ref
                  .read(sellerOrdersProvider.notifier)
                  .verifyPickupCode(order.id, code);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Commande remise au client ✅' : 'Code invalide ❌'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeliveryCodeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la remise en main propre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Entrez le code de livraison donné par l\'acheteur :'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Ex: XYZ789',
                border: OutlineInputBorder(),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              final success = await ref
                  .read(sellerOrdersProvider.notifier)
                  .verifyDeliveryCode(order.id, code);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Remise confirmée ✅' : 'Code invalide ❌'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
          'Passer la commande #${order.id} en "${SellerOrder.statusLabels[newStatus]}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E7DBA)),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(sellerOrdersProvider.notifier)
          .updateOrderStatus(order.id, newStatus);
      if (mounted && success) {
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
                    order.id,
                    'shipped',
                    trackingNumber: trackingController.text.isNotEmpty
                        ? trackingController.text
                        : null,
                    carrier: carrierController.text.isNotEmpty
                        ? carrierController.text
                        : null,
                  );
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Commande expédiée !'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E7DBA)),
            child: const Text('Expédier'),
          ),
        ],
      ),
    );
  }

  void _openChat() {
    final user = ref.read(userProvider).value;
    if (user == null) return;

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

  // ------  Helper widgets & methods  ------

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'paid':
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case 'processing':
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case 'ready':
        bgColor = Colors.teal.shade100;
        textColor = Colors.teal.shade800;
        break;
      case 'shipped':
        bgColor = Colors.purple.shade100;
        textColor = Colors.purple.shade800;
        break;
      case 'delivered':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'cancelled':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        SellerOrder.statusLabels[status] ?? status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildItemsPreview(ExchangeRateNotifier exchangeNotifier) {
    final displayItems = order.items.take(2).toList();
    final remaining = order.items.length - 2;

    return Column(
      children: [
        ...displayItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.grey[200],
                    ),
                    child: item.productImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              item.productImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.image, color: Colors.grey[400]),
                            ),
                          )
                        : Icon(Icons.inventory_2, color: Colors.grey[400]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${exchangeNotifier.formatProductPrice(item.price)} × ${item.quantity}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
        if (remaining > 0)
          Text(
            '+$remaining autre${remaining > 1 ? 's' : ''} article${remaining > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
      ],
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

  String _getStatusMessage(String status) {
    switch (status) {
      case 'delivered':
        return 'Commande livrée avec succès ✅';
      case 'cancelled':
        return 'Commande annulée';
      case 'shipped':
        return 'En cours de livraison...';
      default:
        return '';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return "Aujourd'hui ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (diff.inDays == 1) {
      return 'Hier';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays} jours';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatFullDate(DateTime date) {
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDeliveryMethod(String methodId) {
    switch (methodId) {
      case 'pick_go': return 'Pick & Go (retrait)';
      case 'hand_delivery': return 'Remise en main propre';
      case 'oli_express': return 'Oli Express';
      case 'oli_standard': return 'Oli Standard';
      case 'oli_partner': return 'Oli Partner';
      default: return methodId;
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF1E7DBA)),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
