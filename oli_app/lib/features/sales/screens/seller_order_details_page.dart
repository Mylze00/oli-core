import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/exchange_rate_provider.dart';
import '../../../core/user/user_provider.dart';
import '../models/seller_order.dart';
import '../providers/seller_orders_provider.dart';
import '../../chat/chat_page.dart';
import '../../orders/widgets/order_progress_bar.dart';

/// Page de détails d'une commande vendeur
class SellerOrderDetailsPage extends ConsumerStatefulWidget {
  final int orderId;
  final SellerOrder? initialOrder;

  const SellerOrderDetailsPage({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  ConsumerState<SellerOrderDetailsPage> createState() =>
      _SellerOrderDetailsPageState();
}

class _SellerOrderDetailsPageState
    extends ConsumerState<SellerOrderDetailsPage> {
  SellerOrder? _order;
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _loadDetails();
    // Auto-refresh toutes les 10s
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Refresh silencieux (sans loader)
  Future<void> _silentRefresh() async {
    final order = await ref
        .read(sellerOrdersProvider.notifier)
        .getOrderDetails(widget.orderId);
    if (mounted && order != null) {
      setState(() => _order = order);
    }
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final order = await ref
        .read(sellerOrdersProvider.notifier)
        .getOrderDetails(widget.orderId);

    if (mounted) {
      setState(() {
        if (order != null) {
          _order = order;
        } else if (_order == null) {
          _error = 'Impossible de charger la commande';
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const oliBlue = Color(0xFF1E7DBA);
    ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Commande #${widget.orderId}'),
        backgroundColor: oliBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetails,
          ),
        ],
      ),
      body: _isLoading && _order == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _order == null
              ? _buildErrorState()
              : _order == null
                  ? _buildErrorState()
                  : RefreshIndicator(
                      onRefresh: _loadDetails,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status header
                            _buildStatusHeader(),
                            const SizedBox(height: 16),

                            // Progress bar
                            _buildSection(
                              child: OrderProgressBar(status: _order!.status),
                            ),
                            const SizedBox(height: 16),

                            // Pickup code (prominent)
                            if ((_order!.status == 'processing' ||
                                    _order!.status == 'ready') &&
                                _order!.pickupCode != null)
                              _buildPickupCodeSection(),

                            // Delivery code for buyer (visible to seller)
                            if ((_order!.status == 'ready' ||
                                    _order!.status == 'shipped') &&
                                _order!.deliveryCode != null)
                              _buildDeliveryCodeSection(),

                            // Buyer section
                            _buildBuyerSection(),
                            const SizedBox(height: 16),

                            // Items section
                            _buildItemsSection(exchangeNotifier),
                            const SizedBox(height: 16),

                            // Delivery info
                            _buildDeliverySection(),
                            const SizedBox(height: 16),

                            // Order summary
                            _buildSummarySection(exchangeNotifier),
                            const SizedBox(height: 16),

                            // Action buttons
                            _buildActionButtons(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Erreur inconnue',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDetails,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    String? title,
    required Widget child,
    Color? backgroundColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ??
            (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildSection(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commande #${_order!.id}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Créée le ${_formatFullDate(_order!.createdAt)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
          _buildStatusChip(_order!.status),
        ],
      ),
    );
  }

  Widget _buildPickupCodeSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade100, Colors.amber.shade50],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade400, width: 2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.key, color: Colors.orange.shade800, size: 22),
                const SizedBox(width: 8),
                Text(
                  'CODE POUR LE LIVREUR',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                _order!.pickupCode!,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: Colors.orange.shade900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Communiquez ce code au livreur quand il arrive',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryCodeSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade100, Colors.teal.shade50],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade400, width: 2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user, color: Colors.green.shade800, size: 22),
                const SizedBox(width: 8),
                Text(
                  'CODE POUR L\'ACHETEUR',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // QR Code
            Container(
              width: 130,
              height: 130,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(
                data: _order!.deliveryCode!,
                version: QrVersions.auto,
                size: 114,
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Text(
                _order!.deliveryCode!,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: Colors.green.shade900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'L\'acheteur présentera ce code au livreur',
              style: TextStyle(fontSize: 12, color: Colors.green.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyerSection() {
    return _buildSection(
      title: '👤 ACHETEUR',
      child: Column(
        children: [
          // Buyer name
          Row(
            children: [
              Icon(Icons.person, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _order!.buyerName ?? 'Acheteur inconnu',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          // Phone
          if (_order!.buyerPhone != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _callBuyer(_order!.buyerPhone!),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 20, color: Colors.green),
                  const SizedBox(width: 10),
                  Text(
                    _order!.buyerPhone!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E7DBA),
                    side: const BorderSide(color: Color(0xFF1E7DBA)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (_order!.buyerPhone != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callBuyer(_order!.buyerPhone!),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Appeler'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(ExchangeRateNotifier exchangeNotifier) {
    return _buildSection(
      title: '📦 ARTICLES (${_order!.items.length})',
      child: Column(
        children: _order!.items
            .map((item) => _buildItemRow(item, exchangeNotifier))
            .toList(),
      ),
    );
  }

  Widget _buildItemRow(
      SellerOrderItem item, ExchangeRateNotifier exchangeNotifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[300],
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
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${exchangeNotifier.formatProductPrice(item.price)} × ${item.quantity}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Subtotal
          Text(
            exchangeNotifier.formatProductPrice(item.price * item.quantity),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E7DBA),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    final hasDeliveryInfo = _order!.deliveryMethodId != null ||
        _order!.deliveryAddress != null ||
        _order!.trackingNumber != null ||
        _order!.carrier != null;

    if (!hasDeliveryInfo) return const SizedBox.shrink();

    return _buildSection(
      title: '🚚 LIVRAISON',
      child: Column(
        children: [
          if (_order!.deliveryMethodId != null)
            _buildInfoRow(Icons.route, 'Mode',
                _formatDeliveryMethod(_order!.deliveryMethodId!)),
          if (_order!.deliveryAddress != null)
            _buildInfoRow(
                Icons.location_on, 'Adresse', _order!.deliveryAddress!),
          if (_order!.carrier != null)
            _buildInfoRow(
                Icons.local_shipping, 'Transporteur', _order!.carrier!),
          if (_order!.trackingNumber != null)
            _buildInfoRow(
                Icons.qr_code, 'N° de suivi', _order!.trackingNumber!),
          if (_order!.estimatedDelivery != null)
            _buildInfoRow(Icons.schedule, 'Livraison prévue',
                _formatFullDate(_order!.estimatedDelivery!)),
          if (_order!.shippedAt != null)
            _buildInfoRow(Icons.flight_takeoff, 'Expédiée le',
                _formatFullDate(_order!.shippedAt!)),
          if (_order!.deliveredAt != null)
            _buildInfoRow(Icons.check_circle, 'Livrée le',
                _formatFullDate(_order!.deliveredAt!)),
        ],
      ),
    );
  }

  Widget _buildSummarySection(ExchangeRateNotifier exchangeNotifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildSection(
      title: '💰 RÉSUMÉ',
      child: Column(
        children: [
          _buildSummaryRow(
            'Sous-total',
            exchangeNotifier.formatProductPrice(
                _order!.totalAmount - _order!.deliveryFee),
            isDark,
          ),
          if (_order!.deliveryFee > 0) ...[
            const SizedBox(height: 6),
            _buildSummaryRow(
              'Frais de livraison',
              exchangeNotifier.formatProductPrice(_order!.deliveryFee),
              isDark,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                exchangeNotifier.formatProductPrice(_order!.totalAmount),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E7DBA),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildActionButtons() {
    final buttons = <Widget>[];

    // Pick & Go: seller verifies pickup_code when ready
    if (_order!.deliveryMethodId == 'pick_go' &&
        _order!.status == 'ready') {
      buttons.add(_buildFullWidthButton(
        icon: Icons.qr_code_scanner,
        label: 'Vérifier le code client (Pick & Go)',
        color: Colors.green,
        onPressed: _showPickupCodeDialog,
      ));
    }
    // Hand Delivery: seller confirms with delivery_code when processing
    else if (_order!.deliveryMethodId == 'hand_delivery' &&
        _order!.status == 'processing') {
      buttons.add(_buildFullWidthButton(
        icon: Icons.handshake,
        label: 'Confirmer la remise en main propre',
        color: Colors.teal,
        onPressed: _showDeliveryCodeDialog,
      ));
    }

    // Standard transitions
    for (final nextStatus in _order!.allowedTransitions) {
      buttons.add(_buildFullWidthButton(
        icon: _getActionIcon(nextStatus),
        label: _getActionLabel(nextStatus),
        color: const Color(0xFF1E7DBA),
        onPressed: () => _handleStatusChange(nextStatus),
      ));
    }

    if (buttons.isEmpty) {
      return _buildSection(
        child: Text(
          _getStatusMessage(_order!.status),
          style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: buttons
          .map((b) => Padding(padding: const EdgeInsets.only(bottom: 10), child: b))
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
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ------  Dialogs  ------

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
                  .verifyPickupCode(_order!.id, code);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Commande remise au client ✅'
                        : 'Code invalide ❌'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
                if (success) _loadDetails();
              }
            },
            child:
                const Text('Valider', style: TextStyle(color: Colors.white)),
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
            const Text(
                'Entrez le code de livraison donné par l\'acheteur :'),
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
                  .verifyDeliveryCode(_order!.id, code);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Remise confirmée ✅'
                        : 'Code invalide ❌'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
                if (success) _loadDetails();
              }
            },
            child: const Text('Confirmer',
                style: TextStyle(color: Colors.white)),
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
          'Passer la commande #${_order!.id} en "${SellerOrder.statusLabels[newStatus]}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E7DBA)),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(sellerOrdersProvider.notifier)
          .updateOrderStatus(_order!.id, newStatus);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Statut mis à jour: ${SellerOrder.statusLabels[newStatus]}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDetails();
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
                    _order!.id,
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
                _loadDetails();
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E7DBA)),
            child: const Text('Expédier'),
          ),
        ],
      ),
    );
  }

  void _openChat() {
    final user = ref.read(userProvider).value;
    if (user == null || _order == null) return;

    final firstItem = _order!.items.isNotEmpty ? _order!.items.first : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          myId: user.id.toString(),
          otherId: _order!.userId.toString(),
          otherName: _order!.buyerName ?? 'Acheteur',
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

  // ------  Helpers  ------

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        SellerOrder.statusLabels[status] ?? status,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(String status) {
    switch (status) {
      case 'processing':
        return Icons.inventory;
      case 'ready':
        return Icons.check_circle_outline;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.done_all;
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
        return 'Mettre à jour';
    }
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'delivered':
        return '✅ Commande livrée avec succès';
      case 'cancelled':
        return '❌ Commande annulée';
      case 'shipped':
        return '📦 En cours de livraison...';
      default:
        return 'Aucune action requise';
    }
  }

  String _formatFullDate(DateTime date) {
    const months = [
      '', 'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${date.day} ${months[date.month]} ${date.year}, '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDeliveryMethod(String methodId) {
    switch (methodId) {
      case 'oli_express':
        return 'Oli Express';
      case 'oli_standard':
        return 'Oli Standard';
      case 'pick_go':
        return 'Pick & Go';
      case 'hand_delivery':
        return 'Remise en main propre';
      default:
        return methodId;
    }
  }
}
