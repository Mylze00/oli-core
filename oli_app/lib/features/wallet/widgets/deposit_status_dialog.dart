import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';
import '../providers/wallet_provider.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enum des états du dépôt
// ─────────────────────────────────────────────────────────────────────────────
enum DepositStatus { pending, success, failed }

// ─────────────────────────────────────────────────────────────────────────────
// Fonction utilitaire — afficher le popup de statut de dépôt
// Usage: showDepositStatusDialog(context, ref, orderId: '...', amountFC: 1000)
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showDepositStatusDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String orderId,
  required double amountFC,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => DepositStatusDialog(
      orderId: orderId,
      amountFC: amountFC,
      ref: ref,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal du popup
// ─────────────────────────────────────────────────────────────────────────────
class DepositStatusDialog extends ConsumerStatefulWidget {
  final String orderId;
  final double amountFC;
  final WidgetRef ref;

  const DepositStatusDialog({
    super.key,
    required this.orderId,
    required this.amountFC,
    required this.ref,
  });

  @override
  ConsumerState<DepositStatusDialog> createState() => _DepositStatusDialogState();
}

class _DepositStatusDialogState extends ConsumerState<DepositStatusDialog>
    with TickerProviderStateMixin {
  DepositStatus _status = DepositStatus.pending;
  Timer? _pollingTimer;
  int _attempts = 0;
  static const int _maxAttempts = 24; // 24 × 5s = 2 minutes max

  // Animations
  late AnimationController _dotController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Animation des points clignotants
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Animation de zoom pour succès/échec
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Lancer le polling
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _dotController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _startPolling() {
    // Premier check après 3 secondes
    Future.delayed(const Duration(seconds: 3), _checkStatus);
    // Puis toutes les 5 secondes
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;
    _attempts++;

    try {
      final dio = widget.ref.read(dioProvider);
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final response = await dio.get('${ApiConfig.unipesaStatus(widget.orderId)}?t=$cacheBuster');

      if (!mounted) return;

      final data = response.data;
      final serverStatus = data['status'] as String? ?? 'pending';

      if (serverStatus == 'success') {
        _pollingTimer?.cancel();
        
        if (mounted) {
          setState(() => _status = DepositStatus.success);
          _dotController.stop();
          _scaleController.forward();
        }

        try {
          // Rafraîchir le solde du wallet
          await widget.ref.read(walletProvider.notifier).loadWalletData();
          
          // Retour haptique et son
          HapticFeedback.mediumImpact();
          AudioPlayer().play(AssetSource('images/kaching.mp3'));
        } catch (e) {
          debugPrint('Erreur lors des effets de succès: $e');
        }
      } else if (serverStatus == 'failed' ||
          serverStatus == 'timeout' ||
          serverStatus == 'cancelled') {
        _pollingTimer?.cancel();
        if (mounted) {
          setState(() => _status = DepositStatus.failed);
          _dotController.stop();
          _scaleController.forward();
        }
      } else if (_attempts >= _maxAttempts) {
        // Timeout côté client (2 minutes)
        _pollingTimer?.cancel();
        if (mounted) {
          setState(() => _status = DepositStatus.failed);
          _dotController.stop();
          _scaleController.forward();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Polling status error: $e');
      if (_attempts >= _maxAttempts && mounted) {
        _pollingTimer?.cancel();
        setState(() => _status = DepositStatus.failed);
        _dotController.stop();
        _scaleController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.amountFC.toStringAsFixed(0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: _buildContent(amount),
    );
  }

  Widget _buildContent(String amount) {
    switch (_status) {
      case DepositStatus.pending:
        return _PendingCard(amount: amount, dotController: _dotController);
      case DepositStatus.success:
        return _SuccessCard(
          amount: amount,
          scaleAnimation: _scaleAnimation,
          onClose: () => Navigator.of(context).pop(),
        );
      case DepositStatus.failed:
        return _FailedCard(
          amount: amount,
          scaleAnimation: _scaleAnimation,
          onClose: () => Navigator.of(context).pop(),
          onRetry: () => Navigator.of(context).pop(),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// État 1 : EN COURS — fond bleu clair + 3 points animés
// ─────────────────────────────────────────────────────────────────────────────
class _PendingCard extends StatelessWidget {
  final String amount;
  final AnimationController dotController;

  const _PendingCard({required this.amount, required this.dotController});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF8),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A3A6E).withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A3A6E),
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'Votre depot de\n'),
                TextSpan(
                  text: '$amount FC ',
                  style: const TextStyle(color: Color(0xFF1E6FBF)),
                ),
                const TextSpan(text: 'est en cours de validation'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _AnimatedDots(controller: dotController),
          const SizedBox(height: 16),
          Text(
            'Validez sur votre téléphone...',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF1A3A6E).withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3 points animés
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedDots extends StatelessWidget {
  final AnimationController controller;

  const _AnimatedDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final delay = i * 0.33;
            final rawValue = (controller.value - delay).clamp(0.0, 1.0);
            final scale = 0.7 + (rawValue * 0.6);
            final opacity = 0.4 + (rawValue * 0.6);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Opacity(
                opacity: opacity.clamp(0.4, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E6FBF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// État 2 : SUCCÈS — fond bleu clair + ✅ vert animé
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessCard extends StatelessWidget {
  final String amount;
  final Animation<double> scaleAnimation;
  final VoidCallback onClose;

  const _SuccessCard({
    required this.amount,
    required this.scaleAnimation,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF8),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A3A6E).withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A3A6E),
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'Votre depot de\n'),
                TextSpan(
                  text: '$amount FC ',
                  style: const TextStyle(color: Color(0xFF1E6FBF)),
                ),
                const TextSpan(text: 'a été effectué avec succes'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ScaleTransition(
            scale: scaleAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4422C55E),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onClose,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF1E6FBF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Fermer',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// État 3 : ÉCHEC — fond rouge clair + ❌ rouge animé
// ─────────────────────────────────────────────────────────────────────────────
class _FailedCard extends StatelessWidget {
  final String amount;
  final Animation<double> scaleAnimation;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  const _FailedCard({
    required this.amount,
    required this.scaleAnimation,
    required this.onClose,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFFFEECEC),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB91C1C).withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB91C1C),
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'Votre depot de\n'),
                TextSpan(text: '$amount FC '),
                const TextSpan(text: "n'a pas abouti\nveuillez verifiez votre solde"),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ScaleTransition(
            scale: scaleAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x44EF4444),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onClose,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Fermer',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
