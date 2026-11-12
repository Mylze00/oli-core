import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cart/providers/cart_provider.dart';
import '../widgets/payment_bottom_sheets.dart';
import '../../orders/screens/purchases_page.dart';
import '../../orders/providers/orders_provider.dart';
import '../../user/providers/address_provider.dart';
import '../../user/screens/address_management_page.dart';
import '../../../core/user/user_model.dart';
import '../../../core/user/user_provider.dart';
import '../../../models/order_model.dart';
import '../../../providers/exchange_rate_provider.dart';
import 'order_success_page.dart';
import '../../../core/widgets/mobile_operator.dart';

/// Page de validation de commande, avec le panier (défaut) ou un achat direct.
///
/// Les montants affichés viennent du devis du serveur (POST /orders/quote) :
/// c'est exactement ce qui sera débité, en FC.
class CheckoutPage extends ConsumerStatefulWidget {
  /// Si fourni, utilise cet item au lieu du panier (achat immédiat)
  final CartItem? directPurchaseItem;

  const CheckoutPage({super.key, this.directPurchaseItem});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

/// Couleurs de la page, selon le mode clair ou sombre de l'app.
class _CheckoutColors {
  final bool isDark;
  final Color background;
  final Color card;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color iconTile;
  final Color accent;

  const _CheckoutColors._({
    required this.isDark,
    required this.background,
    required this.card,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.iconTile,
    required this.accent,
  });

  factory _CheckoutColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const _CheckoutColors._(
            isDark: true,
            background: Colors.black,
            card: Color(0xFF1C1C1E),
            border: Color(0x1FFFFFFF),
            text: Colors.white,
            textSecondary: Color(0xFF9A9AA0),
            iconTile: Color(0x14FFFFFF),
            accent: Color(0xFF3B8EF0),
          )
        : const _CheckoutColors._(
            isDark: false,
            background: Color(0xFFF5F6F8),
            card: Colors.white,
            border: Color(0xFFE6E8EC),
            text: Color(0xFF111418),
            textSecondary: Color(0xFF5F6673),
            iconTile: Color(0xFFF1F3F6),
            accent: Color(0xFF1A5DE6),
          );
  }
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  String _paymentMethod = 'wallet';
  bool _isPaying = false;
  bool _isEditingPhone = false;
  late final TextEditingController _phoneController;

  OrderQuote? _quote;
  String? _quoteError;
  bool _isQuoting = true;
  String? _quotedKey;

  /// Lu avec ref.read : utilisable hors du build (le build s'abonne au panier).
  List<CartItem> get _checkoutItems {
    if (widget.directPurchaseItem != null) return [widget.directPurchaseItem!];
    return ref.read(cartProvider).where((item) => item.isSelected).toList();
  }

  double get _deliveryFeeUsd => _checkoutItems.fold(0.0, (sum, item) => sum + item.deliveryPrice);

  String get _deliveryMethod {
    final items = _checkoutItems;
    final method = items.isEmpty ? '' : items.first.deliveryMethod.trim();
    return method.isEmpty ? 'Standard' : method;
  }

  /// Retrait sans livreur (PickGo, main propre). Une livraison gratuite reste une livraison :
  /// elle demande une adresse, ce n'est pas un retrait.
  bool get _isPickup {
    final method = _deliveryMethod.toLowerCase();
    return method.contains('pick') || method.contains('main propre') || method == 'hand_delivery';
  }

  @override
  void initState() {
    super.initState();
    // Numéro Mobile Money : celui du compte, déjà chargé ou dès qu'il arrive
    _phoneController = TextEditingController(text: ref.read(userProvider).value?.phone ?? '');
    ref.listenManual<AsyncValue<User?>>(userProvider, (previous, next) {
      final phone = next.value?.phone;
      if (phone != null && phone.isNotEmpty && _phoneController.text.isEmpty && mounted) {
        setState(() => _phoneController.text = phone);
      }
    });
    Future.microtask(() => ref.read(addressProvider.notifier).loadAddresses());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Redemande le devis quand les articles (ou leur quantité) changent.
  void _refreshQuoteIfNeeded(List<CartItem> items) {
    final key = items.map((i) => '${i.cartKey}x${i.quantity}').join('|') + '@$_deliveryFeeUsd';
    if (key == _quotedKey) return;
    _quotedKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuote());
  }

  Future<void> _loadQuote() async {
    final items = _checkoutItems;
    if (items.isEmpty) return;
    setState(() {
      _isQuoting = true;
      _quoteError = null;
    });
    try {
      final quote = await ref
          .read(orderServiceProvider)
          .quoteOrder(items: items.map((item) => item.toOrderItem()).toList(), deliveryFee: _deliveryFeeUsd);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _isQuoting = false;
        // Wallet insuffisant : Mobile Money est proposé d'emblée
        if (!quote.walletCovers && _paymentMethod == 'wallet') _paymentMethod = 'mobile_money';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quoteError = e.toString();
        _isQuoting = false;
      });
    }
  }

  String _fc(num amount) =>
      ref.read(exchangeRateProvider.notifier).formatAmount(amount.toDouble(), currency: Currency.CDF);

  /// Équivalent dans la monnaie choisie à l'accueil, quand ce n'est pas le FC.
  String? _equivalent(num amountFc) {
    final selected = ref.watch(exchangeRateProvider).selectedCurrency;
    if (selected == Currency.CDF) return null;
    return '≈ ${ref.read(exchangeRateProvider.notifier).formatWalletBalance(amountFc.toDouble())}';
  }

  double? get _amountToPay {
    final quote = _quote;
    if (quote == null) return null;
    return _paymentMethod == 'mobile_money' ? quote.mobileMoneyTotalFC : quote.totalFC;
  }

  /// Raison pour laquelle le paiement est impossible, ou null.
  String? get _payBlocker {
    final quote = _quote;
    if (quote == null) return null;
    if (!_isPickup && ref.read(defaultAddressProvider) == null) return 'Ajoutez une adresse de livraison';
    if (_paymentMethod == 'wallet' && !quote.walletCovers) return 'Solde du wallet insuffisant';
    if (_paymentMethod == 'mobile_money' && _phoneController.text.trim().length < 9) {
      return 'Indiquez votre numéro Mobile Money';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = _CheckoutColors.of(context);
    ref.watch(cartProvider);
    final items = _checkoutItems;
    _refreshQuoteIfNeeded(items);
    ref.watch(defaultAddressProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.text,
        elevation: 0,
        title: Text(
          'Validation de commande',
          style: TextStyle(color: c.text, fontWeight: FontWeight.w600),
        ),
      ),
      body: items.isEmpty
          ? Center(
              child: Text('Aucun article à commander', style: TextStyle(color: c.textSecondary)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _buildHeader(c, items),
                const SizedBox(height: 16),
                _buildPerks(c),
                const SizedBox(height: 16),
                _buildItemsCard(c, items),
                const SizedBox(height: 24),
                _sectionTitle(c, 'Livraison'),
                _buildDeliveryCard(c),
                const SizedBox(height: 24),
                _sectionTitle(c, 'Paiement'),
                _buildPaymentCard(c),
              ],
            ),
      bottomNavigationBar: items.isEmpty ? null : _buildPayBar(c),
    );
  }

  Widget _buildHeader(_CheckoutColors c, List<CartItem> items) {
    final quote = _quote;
    final count = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final equivalent = quote == null ? null : _equivalent(quote.totalFC);
    return Column(
      children: [
        Text('Votre commande', style: TextStyle(color: c.textSecondary, fontSize: 14)),
        const SizedBox(height: 4),
        if (_isQuoting && quote == null)
          SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
          )
        else
          Text(
            quote == null ? '—' : _fc(quote.totalFC),
            style: TextStyle(color: c.text, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
        const SizedBox(height: 4),
        Text(
          '$count article${count > 1 ? 's' : ''} · ${_isPickup ? 'retrait en boutique' : 'livraison incluse'}'
          '${equivalent == null ? '' : ' · $equivalent'}',
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildPerks(_CheckoutColors c) {
    Widget perk(IconData icon, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: c.text, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.text, fontSize: 12, height: 1.2),
          ),
        ],
      ),
    );
    return _card(
      c,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: [
          perk(
            _isPickup ? Icons.storefront_outlined : Icons.local_shipping_outlined,
            _isPickup ? 'Retrait\nen boutique' : 'Livraison\n$_deliveryMethod',
          ),
          perk(Icons.verified_user_outlined, 'Paiement\nsécurisé'),
          perk(Icons.qr_code_2_rounded, 'Code remis\nà la livraison'),
        ],
      ),
    );
  }

  Widget _buildItemsCard(_CheckoutColors c, List<CartItem> items) {
    final quote = _quote;
    return _card(
      c,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 24, color: c.border),
            _buildItemRow(c, items[i], quote),
          ],
          Divider(height: 28, color: c.border),
          _summaryRow(c, 'Articles', quote == null ? '—' : _fc(quote.itemsTotalFC)),
          const SizedBox(height: 8),
          _summaryRow(
            c,
            _isPickup ? 'Retrait en boutique' : 'Livraison · $_deliveryMethod',
            quote == null ? '—' : (quote.deliveryFeeFC == 0 ? 'Gratuit' : _fc(quote.deliveryFeeFC)),
          ),
          const SizedBox(height: 10),
          _summaryRow(c, 'Total', quote == null ? '—' : _fc(quote.totalFC), emphasize: true),
          if (_quoteError != null) ...[const SizedBox(height: 12), _buildQuoteError(c)],
        ],
      ),
    );
  }

  Widget _buildItemRow(_CheckoutColors c, CartItem item, OrderQuote? quote) {
    final line = quote?.lines.where((l) => l.productId == item.productId && l.variantId == item.variantId).firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: c.iconTile,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: item.imageUrl == null
              ? Icon(Icons.shopping_bag_outlined, color: c.textSecondary)
              : Image.network(
                  item.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.shopping_bag_outlined, color: c.textSecondary),
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
                style: TextStyle(color: c.text, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (item.sellerName != null && item.sellerName!.isNotEmpty) item.sellerName!,
                  'Qté ${item.quantity}',
                ].join(' · '),
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          line == null ? '—' : _fc(line.lineTotalFC),
          style: TextStyle(color: c.text, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildQuoteError(_CheckoutColors c) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFE5484D), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_quoteError!, style: const TextStyle(color: Color(0xFFE5484D), fontSize: 13)),
        ),
        TextButton(
          onPressed: _loadQuote,
          child: Text('Réessayer', style: TextStyle(color: c.accent)),
        ),
      ],
    );
  }

  Widget _buildDeliveryCard(_CheckoutColors c) {
    final address = ref.watch(defaultAddressProvider);
    if (_isPickup) {
      return _card(
        c,
        child: _infoRow(
          c,
          icon: Icons.storefront_outlined,
          label: 'Retrait en boutique',
          value: 'Présentez votre code au vendeur pour récupérer la commande',
        ),
      );
    }
    return _card(
      c,
      padding: EdgeInsets.zero,
      child: _infoRow(
        c,
        icon: Icons.home_outlined,
        label: address == null ? 'Adresse de livraison' : 'Livrer à · ${address.label}',
        value: address == null ? 'Ajoutez une adresse pour être livré' : address.fullAddress,
        detail: address?.referencePoint,
        warning: address == null,
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressManagementPage()));
          ref.read(addressProvider.notifier).loadAddresses();
        },
      ),
    );
  }

  Widget _buildPaymentCard(_CheckoutColors c) {
    final quote = _quote;
    final walletSubtitle = quote == null
        ? 'Solde en cours de chargement'
        : quote.walletCovers
        ? 'Solde : ${_fc(quote.walletBalanceFC)}'
        : 'Solde insuffisant : ${_fc(quote.walletBalanceFC)}';
    final mobileSubtitle = quote == null
        ? 'Airtel, Orange, Vodacom (M-Pesa)'
        : 'Frais Mobile Money : +${_fc(quote.mobileMoneyFeeFC)}';

    return _card(
      c,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _paymentOption(
            c,
            value: 'wallet',
            icon: Icons.account_balance_wallet_outlined,
            label: 'Wallet Oli',
            subtitle: walletSubtitle,
            subtitleWarning: quote != null && !quote.walletCovers,
          ),
          Divider(height: 1, indent: 64, color: c.border),
          _paymentOption(
            c,
            value: 'mobile_money',
            icon: Icons.phone_android_rounded,
            label: 'Mobile Money',
            subtitle: mobileSubtitle,
          ),
          if (_paymentMethod == 'mobile_money') ...[Divider(height: 1, indent: 64, color: c.border), _buildPhoneRow(c)],
          Divider(height: 1, indent: 64, color: c.border),
          _paymentOption(
            c,
            value: 'card',
            icon: Icons.credit_card_rounded,
            label: 'Carte bancaire',
            subtitle: 'Bientôt disponible',
            enabled: false,
          ),
        ],
      ),
    );
  }

  /// Numéro Mobile Money, prérempli avec celui du compte.
  Widget _buildPhoneRow(_CheckoutColors c) {
    if (!_isEditingPhone && _phoneController.text.isNotEmpty) {
      return _infoRow(
        c,
        icon: Icons.person_outline_rounded,
        leading: OperatorLogo(phone: _phoneController.text, size: 36),
        label: 'Numéro débité · ${MobileOperator.fromPhone(_phoneController.text).serviceName}',
        value: formatCongoPhone(_phoneController.text),
        trailing: TextButton(
          onPressed: () => setState(() => _isEditingPhone = true),
          child: Text('Modifier', style: TextStyle(color: c.accent)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: TextField(
        controller: _phoneController,
        autofocus: _isEditingPhone,
        keyboardType: TextInputType.phone,
        style: TextStyle(color: c.text),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => setState(() => _isEditingPhone = false),
        decoration: InputDecoration(
          labelText: 'Numéro Mobile Money',
          hintText: '+243 81 000 0000',
          labelStyle: TextStyle(color: c.textSecondary),
          hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: 0.6)),
          prefixIcon: MobileOperator.fromPhone(_phoneController.text) == MobileOperator.unknown
              ? Icon(Icons.phone_outlined, color: c.textSecondary)
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: OperatorLogo(phone: _phoneController.text, size: 32),
                ),
          filled: true,
          fillColor: c.iconTile,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPayBar(_CheckoutColors c) {
    final amount = _amountToPay;
    final blocker = _payBlocker;
    final canPay = amount != null && blocker == null && !_isPaying && !_isQuoting;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (blocker != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(blocker, style: const TextStyle(color: Color(0xFFE5484D), fontSize: 13)),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('À payer', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                    Text(
                      amount == null ? '—' : _fc(amount),
                      style: TextStyle(color: c.text, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              // Bouton façon Apple Pay : noir en clair, blanc en sombre
              SizedBox(
                height: 52,
                width: 190,
                child: ElevatedButton(
                  onPressed: canPay ? _confirmOrder : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.isDark ? Colors.white : Colors.black,
                    foregroundColor: c.isDark ? Colors.black : Colors.white,
                    disabledBackgroundColor: (c.isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                    disabledForegroundColor: (c.isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isPaying
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: c.isDark ? Colors.black : Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Payer avec ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400)),
                            Icon(Icons.account_balance_wallet_rounded, size: 18),
                            SizedBox(width: 3),
                            Text('Pay', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Briques visuelles ─────────────────────────────────────────────

  Widget _card(_CheckoutColors c, {required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: c.isDark ? null : const [BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _sectionTitle(_CheckoutColors c, String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      title,
      style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w700),
    ),
  );

  Widget _summaryRow(_CheckoutColors c, String label, String value, {bool emphasize = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? c.text : c.textSecondary,
              fontSize: emphasize ? 16 : 14,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: c.text,
            fontSize: emphasize ? 17 : 14,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _iconTile(_CheckoutColors c, IconData icon, {Color? color}) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(color: c.iconTile, borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, color: color ?? c.text, size: 20),
  );

  /// Ligne façon Apple Pay : icône dans un carré, libellé, valeur et flèche.
  Widget _infoRow(
    _CheckoutColors c, {
    required IconData icon,
    required String label,
    required String value,
    String? detail,
    bool warning = false,
    VoidCallback? onTap,
    Widget? trailing,
    Widget? leading,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            leading ?? _iconTile(c, icon, color: warning ? const Color(0xFFE5484D) : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  if (detail != null && detail.isNotEmpty)
                    Text(detail, style: TextStyle(color: c.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (trailing != null) trailing else if (onTap != null) Icon(Icons.chevron_right, color: c.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _paymentOption(
    _CheckoutColors c, {
    required String value,
    required IconData icon,
    required String label,
    required String subtitle,
    bool enabled = true,
    bool subtitleWarning = false,
  }) {
    final selected = _paymentMethod == value;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? () => setState(() => _paymentMethod = value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _iconTile(c, icon, color: selected ? c.accent : null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleWarning ? const Color(0xFFE5484D) : c.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? c.accent : c.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Paiement ──────────────────────────────────────────────────────

  Future<void> _confirmOrder() async {
    final quote = _quote;
    if (quote == null || _amountToPay == null || _payBlocker != null) return;

    final address = ref.read(defaultAddressProvider);
    final phone = _phoneController.text.trim();

    final choice = await showPaymentConfirmationSheet(
      context: context,
      initialMethod: _paymentMethod,
      walletTotalFC: quote.totalFC,
      mobileMoneyTotalFC: quote.mobileMoneyTotalFC,
      mobileMoneyFeeFC: quote.mobileMoneyFeeFC,
      walletBalanceFC: quote.walletBalanceFC,
      walletCovers: quote.walletCovers,
      mobileMoneyPhone: phone,
      deliveryLabel: _isPickup ? 'Retrait en boutique' : (address?.fullAddress ?? ''),
      isPickup: _isPickup,
      formatFc: _fc,
    );
    if (choice == null || !mounted) return;
    if (choice.editAddress) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressManagementPage()));
      ref.read(addressProvider.notifier).loadAddresses();
      return;
    }
    // Le moyen a pu être changé dans la feuille
    setState(() => _paymentMethod = choice.method!);
    final isMobileMoney = _paymentMethod == 'mobile_money';
    final amount = _amountToPay!;

    setState(() => _isPaying = true);
    try {
      final order = await ref
          .read(orderServiceProvider)
          .createOrder(
            items: _checkoutItems.map((item) => item.toOrderItem()).toList(),
            deliveryAddress: _isPickup ? '' : (address?.fullAddress ?? ''),
            paymentMethod: _paymentMethod,
            deliveryFee: _deliveryFeeUsd,
            deliveryMethodId: _deliveryMethod,
          );

      if (widget.directPurchaseItem == null) ref.read(cartProvider.notifier).clearCart();
      ref.invalidate(ordersProvider);
      if (!mounted) return;

      if (isMobileMoney) {
        await _processMobileMoneyPayment(order, phone, amount);
        return;
      }
      // Wallet : débit immédiat → « Terminé », puis le récapitulatif de la commande
      await showPaymentSuccessSheet(
        context: context,
        order: order,
        amountFC: amount,
        formatFc: _fc,
        onDone: () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => OrderSuccessPage(order: order, paidAmountFC: amount),
              ),
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFE5484D)));
      // Le solde a pu changer : le devis est recalculé
      _loadQuote();
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  /// La commande existe (en attente) : on lance la demande Mobile Money et on suit son statut.
  Future<void> _processMobileMoneyPayment(Order order, String phone, double amountFC) async {
    setState(() => _isPaying = true);
    Map<String, dynamic>? operation;
    String? error;
    try {
      operation = await ref.read(orderServiceProvider).payOrderMobileMoney(orderId: order.id, phone: phone);
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;
    setState(() => _isPaying = false);

    final oliOrderId = operation?['oliOrderId'] as String?;
    if (oliOrderId == null) {
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error), backgroundColor: const Color(0xFFE5484D)));
      }
      showPaymentFailedSheet(
        context: context,
        reason: PaymentResult.failed,
        onRetry: () => _processMobileMoneyPayment(order, phone, amountFC),
        onCancel: _openPurchases,
      );
      return;
    }

    final result = await showPaymentPendingSheet(
      context: context,
      ref: ref,
      oliOrderId: oliOrderId,
      phoneNumber: phone,
      providerName: MobileOperator.fromPhone(phone).serviceName,
      amountLabel: _fc(amountFC),
    );
    if (!mounted) return;

    if (result == PaymentResult.success) {
      showPaymentSuccessSheet(
        context: context,
        order: order,
        amountFC: amountFC,
        formatFc: _fc,
        onDone: _openPurchases,
      );
    } else {
      showPaymentFailedSheet(
        context: context,
        reason: result ?? PaymentResult.cancelled,
        onRetry: () => _processMobileMoneyPayment(order, phone, amountFC),
        onCancel: _openPurchases,
      );
    }
  }

  void _openPurchases() {
    Navigator.of(
      context,
    ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PurchasesPage()), (route) => route.isFirst);
  }
}
