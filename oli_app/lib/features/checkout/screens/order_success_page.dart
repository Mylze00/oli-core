import 'package:oli_app/core/widgets/oli_image.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order_model.dart';
import '../../orders/screens/purchases_page.dart';
import '../../../providers/exchange_rate_provider.dart';

/// Page de confirmation de commande, affichée après un paiement réussi.
///
/// Même langage visuel que la validation : clair ou sombre selon l'app,
/// logo de validation animé (cercle tracé, coche dessinée, onde), puis le
/// récapitulatif et les étapes à venir apparaissent en cascade.
class OrderSuccessPage extends ConsumerStatefulWidget {
  final Order order;

  /// Montant réellement débité en FC (frais compris), quand il est connu.
  final double? paidAmountFC;

  const OrderSuccessPage({super.key, required this.order, this.paidAmountFC});

  @override
  ConsumerState<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

/// Couleurs de la page, alignées sur la page de validation.
class _SuccessColors {
  final bool isDark;
  final Color background;
  final Color card;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color tile;
  final Color accent;
  final Color success;

  const _SuccessColors._(
    this.isDark,
    this.background,
    this.card,
    this.border,
    this.text,
    this.textSecondary,
    this.tile,
    this.accent,
    this.success,
  );

  factory _SuccessColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const _SuccessColors._(
            true,
            Colors.black,
            Color(0xFF1C1C1E),
            Color(0x1FFFFFFF),
            Colors.white,
            Color(0xFF9A9AA0),
            Color(0x14FFFFFF),
            Color(0xFF3B8EF0),
            Color(0xFF30D158),
          )
        : const _SuccessColors._(
            false,
            Color(0xFFF5F6F8),
            Colors.white,
            Color(0xFFE6E8EC),
            Color(0xFF111418),
            Color(0xFF5F6673),
            Color(0xFFF1F3F6),
            Color(0xFF1A5DE6),
            Color(0xFF16A34A),
          );
  }
}

class _OrderSuccessPageState extends ConsumerState<OrderSuccessPage> with TickerProviderStateMixin {
  /// Logo : cercle (0 → 0,45), coche (0,4 → 0,8), léger rebond (0,75 → 1).
  late final AnimationController _logo = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  /// Onde qui se diffuse autour du logo, en boucle douce.
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// Apparition en cascade du contenu.
  late final AnimationController _content = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _logo.forward().whenComplete(() {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _ripple.repeat();
    });
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _content.forward();
    });
  }

  @override
  void dispose() {
    _logo.dispose();
    _ripple.dispose();
    _content.dispose();
    super.dispose();
  }

  Order get _order => widget.order;

  /// Une commande wallet revient avec status 'paid' même si payment_status n'est pas encore relu.
  bool get _isPaid => _order.status != 'pending' || _order.paymentStatus == 'completed';

  String _amountLabel() {
    final ex = ref.read(exchangeRateProvider.notifier);
    final paid = widget.paidAmountFC;
    if (paid != null) return ex.formatAmount(paid, currency: Currency.CDF);
    return ex.formatProductPrice(_order.totalAmount);
  }

  String _paymentLabel(String? method) {
    switch (method) {
      case 'wallet':
        return 'Wallet OLI';
      case 'mobile_money':
        return 'Mobile Money';
      case 'card':
        return 'Carte bancaire';
      default:
        return method ?? '—';
    }
  }

  /// Élément qui glisse et apparaît, décalé selon son rang.
  Widget _reveal(int index, Widget child) {
    final start = (index * 0.12).clamp(0.0, 0.7);
    final animation = CurvedAnimation(
      parent: _content,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(offset: Offset(0, 16 * (1 - animation.value)), child: child),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(exchangeRateProvider);
    final c = _SuccessColors.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                children: [
                  Center(child: _buildLogo(c)),
                  const SizedBox(height: 28),
                  _reveal(
                    0,
                    Column(
                      children: [
                        Text(
                          'Commande confirmée',
                          style: TextStyle(
                            color: c.text,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Commande n° ${_order.id} · payée à OLI',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.textSecondary, fontSize: 15),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _amountLabel(),
                          style: TextStyle(
                            color: c.text,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _reveal(1, _buildSummaryCard(c)),
                  const SizedBox(height: 16),
                  _reveal(2, _buildNextSteps(c)),
                ],
              ),
            ),
            _reveal(3, _buildActions(c)),
          ],
        ),
      ),
    );
  }

  // ─── Logo animé ────────────────────────────────────────────────────

  Widget _buildLogo(_SuccessColors c) {
    const size = 112.0;
    return SizedBox(
      width: size * 1.7,
      height: size * 1.7,
      child: AnimatedBuilder(
        animation: Listenable.merge([_logo, _ripple]),
        builder: (_, __) {
          final t = _logo.value;
          final bounce = t < 0.75 ? 1.0 : 1 + 0.06 * math.sin((t - 0.75) / 0.25 * math.pi);
          return Stack(
            alignment: Alignment.center,
            children: [
              // Ondes : deux anneaux décalés qui s'élargissent et s'effacent
              if (_ripple.isAnimating) ...[
                _rippleRing(c, _ripple.value, size),
                _rippleRing(c, (_ripple.value + 0.5) % 1, size),
              ],
              Transform.scale(
                scale: bounce,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.success.withValues(alpha: 0.12 * Curves.easeOut.transform((t / 0.45).clamp(0, 1))),
                  ),
                  child: CustomPaint(
                    painter: _CheckPainter(
                      circleProgress: Curves.easeInOutCubic.transform((t / 0.45).clamp(0, 1)),
                      checkProgress: Curves.easeOutCubic.transform(((t - 0.4) / 0.4).clamp(0, 1)),
                      color: c.success,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _rippleRing(_SuccessColors c, double v, double size) {
    final eased = Curves.easeOut.transform(v);
    return Container(
      width: size * (1 + 0.65 * eased),
      height: size * (1 + 0.65 * eased),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.success.withValues(alpha: 0.35 * (1 - eased)), width: 1.5),
      ),
    );
  }

  // ─── Récapitulatif ─────────────────────────────────────────────────

  Widget _buildSummaryCard(_SuccessColors c) {
    return _card(
      c,
      child: Column(
        children: [
          _row(c, 'Statut', trailing: _statusPill(c)),
          Divider(height: 1, indent: 16, endIndent: 16, color: c.border),
          _row(c, 'Paiement', value: _paymentLabel(_order.paymentMethod)),
          Divider(height: 1, indent: 16, endIndent: 16, color: c.border),
          _row(c, 'Montant', value: _amountLabel()),
          if (_order.items.isNotEmpty) ...[
            Divider(height: 1, color: c.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(children: _order.items.map((item) => _itemRow(c, item)).toList()),
            ),
          ],
        ],
      ),
    );
  }

  /// Pastille de statut neutre avec un point vert (pas de texte coloré).
  Widget _statusPill(_SuccessColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: _isPaid ? c.success : c.textSecondary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _isPaid ? 'Payée' : 'En attente de paiement',
            style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(_SuccessColors c, OrderItem item) {
    final ex = ref.read(exchangeRateProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.tile,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.imageUrl == null
                ? Icon(Icons.shopping_bag_outlined, color: c.textSecondary, size: 20)
                : OliImage.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.shopping_bag_outlined, color: c.textSecondary, size: 20),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text('Qté ${item.quantity}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(
            ex.formatProductPrice(item.total),
            style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ─── Étapes à venir ────────────────────────────────────────────────

  Widget _buildNextSteps(_SuccessColors c) {
    final steps = [
      (Icons.check_rounded, 'Paiement reçu', 'Le montant est sécurisé par OLI jusqu\'à la livraison', true),
      (Icons.inventory_2_outlined, 'Préparation', 'Le vendeur a été notifié et prépare votre commande', false),
      (Icons.local_shipping_outlined, 'Livraison', 'Votre code de réception apparaîtra dans Mes achats', false),
    ];
    return _card(
      c,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Et maintenant ?',
            style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: steps[i].$4 ? c.success : c.tile),
                        child: Icon(steps[i].$1, size: 16, color: steps[i].$4 ? Colors.white : c.textSecondary),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: c.border),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].$2,
                            style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(steps[i].$3, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.3)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Actions ───────────────────────────────────────────────────────

  Widget _buildActions(_SuccessColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PurchasesPage()), (route) => route.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.isDark ? Colors.white : Colors.black,
                foregroundColor: c.isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Suivre ma commande', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              style: TextButton.styleFrom(foregroundColor: c.text),
              child: const Text('Continuer mes achats', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Briques ───────────────────────────────────────────────────────

  Widget _card(_SuccessColors c, {required Widget child, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
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

  Widget _row(_SuccessColors c, String label, {String? value, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: c.textSecondary, fontSize: 14)),
          ),
          trailing ??
              Text(
                value ?? '—',
                style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w600),
              ),
        ],
      ),
    );
  }
}

/// Dessine le cercle de validation puis la coche, chacun selon sa progression.
class _CheckPainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;
  final Color color;

  _CheckPainter({required this.circleProgress, required this.checkProgress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.055;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Cercle tracé depuis le haut, dans le sens horaire
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - stroke / 2);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * circleProgress, false, paint);

    if (checkProgress <= 0) return;
    // Coche : deux segments, le second démarre quand le premier est fini
    final w = size.width;
    final p1 = Offset(w * 0.30, w * 0.52);
    final p2 = Offset(w * 0.44, w * 0.66);
    final p3 = Offset(w * 0.71, w * 0.38);
    final first = (p2 - p1).distance;
    final second = (p3 - p2).distance;
    final drawn = (first + second) * checkProgress;

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawn <= first) {
      final p = Offset.lerp(p1, p2, drawn / first)!;
      path.lineTo(p.dx, p.dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final p = Offset.lerp(p2, p3, (drawn - first) / second)!;
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint..strokeWidth = stroke * 1.25);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.circleProgress != circleProgress || old.checkProgress != checkProgress || old.color != color;
}
