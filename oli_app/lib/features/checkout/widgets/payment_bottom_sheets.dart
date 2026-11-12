import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import '../../../config/api_config.dart';
import '../../../models/order_model.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../wallet/services/biometric_service.dart';

// --- STYLES COMMUNS ---
const _sheetShape = RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)));

/// Couleurs partagées par les quatre feuilles de paiement, en clair ou en sombre,
/// pour que confirmation, attente, succès et échec se ressemblent.
class _SheetPalette {
  final Color background;
  final Color text;
  final Color secondary;
  final Color tile;
  final Color accent;
  final Color border;

  const _SheetPalette._(this.background, this.text, this.secondary, this.tile, this.accent, this.border);

  static const pending = Color(0xFFF59E0B);
  static const danger = Color(0xFFE5484D);

  factory _SheetPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const _SheetPalette._(
            Color(0xFF1C1C1E),
            Colors.white,
            Color(0xFF9A9AA0),
            Color(0x1AFFFFFF),
            Color(0xFF3B8EF0),
            Color(0x33FFFFFF),
          )
        : const _SheetPalette._(
            Color(0xFFF2F2F7),
            Color(0xFF111418),
            Color(0xFF6B7280),
            Color(0xFFE5E7EB),
            Color(0xFF1A5DE6),
            Color(0xFFD1D5DB),
          );
  }
}

/// Pastille ronde d'état (attente, succès, échec).
Widget _statusBadge(IconData icon, Color color, {double iconSize = 44}) => Container(
  width: 80,
  height: 80,
  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
  child: Icon(icon, color: color, size: iconSize),
);

ButtonStyle _primaryButton(Color color) => ElevatedButton.styleFrom(
  backgroundColor: color,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(54),
  shape: const StadiumBorder(),
  elevation: 0,
);

// ---------------------------------------------------------
// 1. OLI PAY (Dernière lecture avant validation, façon Apple Pay)
// ---------------------------------------------------------
/// Choix rendu par la feuille Oli Pay.
class OliPayChoice {
  /// 'wallet' ou 'mobile_money' : paiement confirmé avec ce moyen.
  final String? method;

  /// L'acheteur veut changer d'adresse avant de payer.
  final bool editAddress;

  const OliPayChoice._({this.method, this.editAddress = false});
  const OliPayChoice.pay(String method) : this._(method: method);
  const OliPayChoice.editAddress() : this._(editAddress: true);
}

/// Feuille Oli Pay : moyen de paiement (modifiable sur place), adresse, marchand,
/// montant exact puis confirmation par Face ID / empreinte quand l'appareil le permet.
/// Retourne null si l'acheteur ferme la feuille.
Future<OliPayChoice?> showPaymentConfirmationSheet({
  required BuildContext context,
  required String initialMethod,
  required double walletTotalFC,
  required double mobileMoneyTotalFC,
  required double mobileMoneyFeeFC,
  required double walletBalanceFC,
  required bool walletCovers,
  required String mobileMoneyPhone,
  required String deliveryLabel,
  required bool isPickup,
  required String Function(num) formatFc,
}) {
  return showModalBottomSheet<OliPayChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _SheetPalette.of(context).background,
    shape: _sheetShape,
    builder: (_) => _OliPaySheet(
      initialMethod: initialMethod,
      walletTotalFC: walletTotalFC,
      mobileMoneyTotalFC: mobileMoneyTotalFC,
      mobileMoneyFeeFC: mobileMoneyFeeFC,
      walletBalanceFC: walletBalanceFC,
      walletCovers: walletCovers,
      mobileMoneyPhone: mobileMoneyPhone,
      deliveryLabel: deliveryLabel,
      isPickup: isPickup,
      formatFc: formatFc,
    ),
  );
}

class _OliPaySheet extends StatefulWidget {
  final String initialMethod;
  final double walletTotalFC;
  final double mobileMoneyTotalFC;
  final double mobileMoneyFeeFC;
  final double walletBalanceFC;
  final bool walletCovers;
  final String mobileMoneyPhone;
  final String deliveryLabel;
  final bool isPickup;
  final String Function(num) formatFc;

  const _OliPaySheet({
    required this.initialMethod,
    required this.walletTotalFC,
    required this.mobileMoneyTotalFC,
    required this.mobileMoneyFeeFC,
    required this.walletBalanceFC,
    required this.walletCovers,
    required this.mobileMoneyPhone,
    required this.deliveryLabel,
    required this.isPickup,
    required this.formatFc,
  });

  @override
  State<_OliPaySheet> createState() => _OliPaySheetState();
}

class _OliPaySheetState extends State<_OliPaySheet> {
  late String _method = widget.initialMethod;
  bool _choosingMethod = false;
  bool _authenticating = false;
  bool _hasBiometrics = false;

  bool get _isMobileMoney => _method == 'mobile_money';
  double get _amount => _isMobileMoney ? widget.mobileMoneyTotalFC : widget.walletTotalFC;

  /// Raison pour laquelle le moyen choisi ne peut pas payer, ou null.
  String? get _blocker {
    if (!_isMobileMoney && !widget.walletCovers) return 'Solde du wallet insuffisant';
    if (_isMobileMoney && widget.mobileMoneyPhone.trim().length < 9) {
      return 'Indiquez votre numéro Mobile Money sur la page de commande';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    biometricService.isAvailable().then((ok) {
      if (mounted) setState(() => _hasBiometrics = ok);
    });
  }

  Future<void> _confirm() async {
    if (_blocker != null || _authenticating) return;
    setState(() => _authenticating = true);
    final ok = await biometricService.authenticate(
      reason: 'Confirmez le paiement de ${widget.formatFc(_amount)} à OLI',
    );
    if (!mounted) return;
    setState(() => _authenticating = false);
    if (ok) {
      HapticFeedback.lightImpact();
      Navigator.pop(context, OliPayChoice.pay(_method));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _SheetPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final blocker = _blocker;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : marque Oli Pay + fermeture
            Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: p.text, size: 26),
                const SizedBox(width: 6),
                Text(
                  'Pay',
                  style: TextStyle(color: p.text, fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                Text(
                  'OLI',
                  style: TextStyle(color: p.secondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _circleButton(p, Icons.close, () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),

            // Moyen de paiement (touchez pour changer)
            _card(
              card,
              child: Column(
                children: [
                  _row(
                    p,
                    leading: _methodTile(_method),
                    title: _isMobileMoney ? 'Mobile Money' : 'Wallet OLI',
                    subtitle: _isMobileMoney
                        ? '${widget.mobileMoneyPhone} · validation sur le téléphone'
                        : 'Solde ${widget.formatFc(widget.walletBalanceFC)}',
                    warning: blocker != null,
                    trailing: Icon(_choosingMethod ? Icons.expand_less : Icons.chevron_right, color: p.secondary),
                    onTap: () => setState(() => _choosingMethod = !_choosingMethod),
                  ),
                  if (_choosingMethod) ...[
                    Divider(height: 1, color: p.border),
                    _methodOption(
                      p,
                      'wallet',
                      'Wallet OLI',
                      widget.walletCovers
                          ? 'Solde ${widget.formatFc(widget.walletBalanceFC)}'
                          : 'Solde insuffisant : ${widget.formatFc(widget.walletBalanceFC)}',
                      enabled: widget.walletCovers,
                    ),
                    _methodOption(
                      p,
                      'mobile_money',
                      'Mobile Money',
                      'Airtel, Orange, M-Pesa · frais +${widget.formatFc(widget.mobileMoneyFeeFC)}',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Adresse ou retrait (touchez pour modifier)
            _card(
              card,
              child: _row(
                p,
                leading: _tile(p, widget.isPickup ? Icons.storefront_outlined : Icons.home_rounded),
                title: widget.deliveryLabel.isEmpty ? '—' : widget.deliveryLabel,
                overline: widget.isPickup ? 'Retrait' : 'Livrer à',
                trailing: widget.isPickup ? null : Icon(Icons.chevron_right, color: p.secondary),
                onTap: widget.isPickup ? null : () => Navigator.pop(context, const OliPayChoice.editAddress()),
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 4),

            // Marchand et montant
            Divider(height: 24, color: p.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OLI', style: TextStyle(color: p.secondary, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    widget.formatFc(_amount),
                    style: TextStyle(color: p.text, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                  ),
                  if (_isMobileMoney && widget.mobileMoneyFeeFC > 0)
                    Text(
                      'dont ${widget.formatFc(widget.mobileMoneyFeeFC)} de frais Mobile Money',
                      style: TextStyle(color: p.secondary, fontSize: 13),
                    ),
                ],
              ),
            ),
            Divider(height: 24, color: p.border),

            if (blocker != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(blocker, style: const TextStyle(color: _SheetPalette.danger, fontSize: 13)),
              ),

            // Confirmation (Face ID / empreinte si disponible)
            Center(
              child: InkWell(
                onTap: blocker == null ? _confirm : null,
                borderRadius: BorderRadius.circular(16),
                child: Opacity(
                  opacity: blocker == null ? 1 : 0.4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: p.accent, width: 2),
                          ),
                          child: _authenticating
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
                                )
                              : Icon(
                                  _hasBiometrics ? Icons.fingerprint : Icons.check_rounded,
                                  color: p.accent,
                                  size: 32,
                                ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hasBiometrics ? 'Confirmer avec Face ID ou empreinte' : 'Toucher pour confirmer',
                          style: TextStyle(color: p.text, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodOption(_SheetPalette p, String value, String label, String subtitle, {bool enabled = true}) {
    final selected = _method == value;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: _row(
        p,
        leading: _methodTile(value),
        title: label,
        subtitle: subtitle,
        trailing: Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? p.accent : p.secondary),
        onTap: enabled
            ? () => setState(() {
                _method = value;
                _choosingMethod = false;
              })
            : null,
      ),
    );
  }

  /// Vignette du moyen de paiement, façon carte bancaire.
  Widget _methodTile(String method) {
    final isMm = method == 'mobile_money';
    return Container(
      width: 46,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: LinearGradient(
          colors: isMm ? const [Color(0xFFF59E0B), Color(0xFFEA580C)] : const [Color(0xFF1A5DE6), Color(0xFF0B2E7A)],
        ),
      ),
      child: Icon(
        isMm ? Icons.phone_android_rounded : Icons.account_balance_wallet_rounded,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Widget _tile(_SheetPalette p, IconData icon) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(color: p.tile, borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, color: p.text, size: 24),
  );

  Widget _card(Color color, {required Widget child}) => Container(
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget _row(
    _SheetPalette p, {
    required Widget leading,
    required String title,
    String? overline,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool warning = false,
    int maxLines = 1,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (overline != null) Text(overline, style: TextStyle(color: p.secondary, fontSize: 13)),
                  Text(
                    title,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: warning ? _SheetPalette.danger : p.secondary, fontSize: 13),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _circleButton(_SheetPalette p, IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: p.tile, shape: BoxShape.circle),
      child: Icon(icon, color: p.secondary, size: 18),
    ),
  );
}

// ---------------------------------------------------------
// 2. PENDING SHEET (Attente et suivi du statut)
// ---------------------------------------------------------
enum PaymentResult { success, failed, timeout, cancelled }

/// Durée d'attente de la validation sur le téléphone.
const _pendingTimeout = Duration(seconds: 60);

Future<PaymentResult?> showPaymentPendingSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String oliOrderId,
  required String phoneNumber,
  required String providerName,
}) {
  return showModalBottomSheet<PaymentResult>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: _SheetPalette.of(context).background,
    shape: _sheetShape,
    builder: (ctx) {
      return _PaymentPendingWidget(oliOrderId: oliOrderId, phoneNumber: phoneNumber, providerName: providerName);
    },
  );
}

class _PaymentPendingWidget extends ConsumerStatefulWidget {
  final String oliOrderId;
  final String phoneNumber;
  final String providerName;

  const _PaymentPendingWidget({required this.oliOrderId, required this.phoneNumber, required this.providerName});

  @override
  ConsumerState<_PaymentPendingWidget> createState() => _PaymentPendingWidgetState();
}

class _PaymentPendingWidgetState extends ConsumerState<_PaymentPendingWidget> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _statusTimer;
  Timer? _countdownTimer;
  int _secondsLeft = _pendingTimeout.inSeconds;
  bool _isChecking = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _startTimers();
  }

  void _startTimers() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        // Dernière vérification avant de conclure à l'expiration
        _checkPaymentStatus().whenComplete(() => _handleResult(PaymentResult.timeout));
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });

    // Suivi du statut toutes les 4 secondes
    _statusTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isChecking) _checkPaymentStatus();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPaymentStatus() async {
    _isChecking = true;
    try {
      final token = await ref.read(secureStorageProvider).getToken();
      if (token == null) return;

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/unipesa/status/${widget.oliOrderId}'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && mounted) {
        final status = jsonDecode(response.body)['status'] as String?;
        if (status == 'success') {
          _handleResult(PaymentResult.success);
        } else if (status == 'failed' || status == 'cancelled') {
          _handleResult(PaymentResult.failed);
        } else if (status == 'timeout') {
          _handleResult(PaymentResult.timeout);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erreur suivi du statut : $e');
    } finally {
      _isChecking = false;
    }
  }

  /// Ferme la feuille une seule fois, quel que soit le minuteur qui conclut.
  void _handleResult(PaymentResult result) {
    if (!mounted || _done) return;
    _done = true;
    _statusTimer?.cancel();
    _countdownTimer?.cancel();
    Navigator.pop(context, result);
  }

  String get _countdownLabel {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final p = _SheetPalette.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, child) => Transform.scale(scale: _pulseAnimation.value, child: child),
              child: _statusBadge(Icons.phone_android_rounded, _SheetPalette.pending, iconSize: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'En attente de validation',
              style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Validez la demande ${widget.providerName} reçue sur\n${widget.phoneNumber}',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.secondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _SheetPalette.pending),
                ),
                const SizedBox(width: 12),
                Text(
                  _countdownLabel,
                  style: const TextStyle(
                    color: _SheetPalette.pending,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _handleResult(PaymentResult.cancelled),
                child: Text('Annuler', style: TextStyle(color: p.secondary, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 3. SUCCESS SHEET (« Terminé », façon Apple Pay)
// ---------------------------------------------------------
/// Coche bleue animée puis « Terminé » ; se ferme seule après un court instant.
/// [amountFC] : montant réellement débité (frais Mobile Money compris), en FC.
Future<void> showPaymentSuccessSheet({
  required BuildContext context,
  required Order order,
  required double amountFC,
  required String Function(num) formatFc,
  required VoidCallback onDone,
}) async {
  HapticFeedback.mediumImpact();

  // Son de succès ; le lecteur est libéré une fois le son terminé
  final player = AudioPlayer();
  player.onPlayerComplete.first.then((_) => player.dispose());
  player.play(AssetSource('images/kaching.mp3')).catchError((_) => player.dispose());

  await showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: _SheetPalette.of(context).background,
    shape: _sheetShape,
    builder: (_) => _PaymentDoneSheet(orderId: order.id, amountLabel: formatFc(amountFC)),
  );
  onDone();
}

class _PaymentDoneSheet extends StatefulWidget {
  final int orderId;
  final String amountLabel;

  const _PaymentDoneSheet({required this.orderId, required this.amountLabel});

  @override
  State<_PaymentDoneSheet> createState() => _PaymentDoneSheetState();
}

class _PaymentDoneSheetState extends State<_PaymentDoneSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();
  Timer? _autoClose;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _autoClose = Timer(const Duration(milliseconds: 2200), _close);
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    _autoClose?.cancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _SheetPalette.of(context);
    return SafeArea(
      top: false,
      child: InkWell(
        onTap: _close,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cercle qui se dessine puis coche qui apparaît
              SizedBox(
                width: 96,
                height: 96,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    final t = Curves.easeOutCubic.transform(_controller.value);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(value: t, strokeWidth: 4, color: p.accent),
                        ),
                        Transform.scale(
                          scale: Curves.elasticOut.transform((_controller.value - 0.4).clamp(0, 0.6) / 0.6),
                          child: Icon(Icons.check_rounded, color: p.accent, size: 56),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Terminé',
                style: TextStyle(color: p.accent, fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Text(
                widget.amountLabel,
                style: TextStyle(color: p.text, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              Text('Payé à OLI · commande #${widget.orderId}', style: TextStyle(color: p.secondary, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 4. FAILED SHEET (Avec option de Réessayer)
// ---------------------------------------------------------
void showPaymentFailedSheet({
  required BuildContext context,
  required PaymentResult reason,
  required VoidCallback onRetry,
  required VoidCallback onCancel,
}) {
  var title = 'Paiement échoué';
  var message = 'Votre paiement n\'a pas pu être traité.';
  if (reason == PaymentResult.timeout) {
    title = 'Temps écoulé';
    message = 'La demande n\'a pas été validée à temps.';
  } else if (reason == PaymentResult.cancelled) {
    title = 'Paiement annulé';
    message = 'Vous avez annulé la transaction.';
  }
  // La commande existe déjà : on dit où la retrouver
  message += '\nVotre commande reste en attente de paiement dans Mes achats.';

  final p = _SheetPalette.of(context);
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: p.background,
    shape: _sheetShape,
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              _statusBadge(Icons.error_outline_rounded, _SheetPalette.danger),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.secondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onRetry();
                },
                style: _primaryButton(p.accent),
                child: const Text('Réessayer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onCancel();
                  },
                  child: Text('Voir mes achats', style: TextStyle(color: p.secondary, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
