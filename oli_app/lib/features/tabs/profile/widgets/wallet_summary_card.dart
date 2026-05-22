import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../../../wallet/widgets/wallet_action_sheets.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../features/auth/providers/auth_controller.dart';

class WalletSummaryCard extends ConsumerWidget {
  const WalletSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);
    // Watch pour rebuild quand devise/taux change
    ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    final authState = ref.watch(authControllerProvider);
    final userName = authState.userData?['name'] ?? 'OLI USER';
    final formattedName = userName.toUpperCase();

    return Column(
      children: [
        // ── Carte de crédit ──────────────────────────────────
        _CreditCard(
          balance: walletState.balance,
          formattedBalance: exchangeNotifier.formatProductPrice(walletState.balance),
          cardholderName: formattedName,
        ),

        const SizedBox(height: 16),

        // ── Boutons d'actions ─────────────────────────────────
        _ActionButtonsRow(context: context),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte de crédit premium
// ─────────────────────────────────────────────────────────────────────────────
class _CreditCard extends StatelessWidget {
  final double balance;
  final String formattedBalance;
  final String cardholderName;

  const _CreditCard({
    required this.balance,
    required this.formattedBalance,
    required this.cardholderName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1A2E44), Color(0xFF0D1B2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E7DBA).withOpacity(0.35),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Vagues holographiques de fond
            Positioned.fill(child: CustomPaint(painter: _CardWavePainter())),

            // Reflet subtil en haut
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.07),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Ligne 1 : Chip + Logo OLI ──────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Chip EMV
                      _ChipWidget(),
                      // Logo OLI (NFC + nom)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Icône NFC/sans-contact
                          Icon(
                            Icons.wifi,
                            color: Colors.white.withOpacity(0.6),
                            size: 18,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'OLI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Solde — zone principale ──────────────────────
                  const Text(
                    'SOLDE DISPONIBLE',
                    style: TextStyle(
                      color: Color(0xFF7AAECF),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formattedBalance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        height: 1.1,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ── Ligne bas : Titulaire + Expiry ────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TITULAIRE',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 8,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cardholderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'VALABLE',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 8,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '12/28',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip EMV doré
// ─────────────────────────────────────────────────────────────────────────────
class _ChipWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: const LinearGradient(
          colors: [Color(0xFFD4A843), Color(0xFFF5D37A), Color(0xFFB8860B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: CustomPaint(painter: _ChipPainter()),
    );
  }
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Lignes horizontales du chip
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.35), paint);
    canvas.drawLine(Offset(0, size.height * 0.65), Offset(size.width, size.height * 0.65), paint);
    // Lignes verticales
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.65, 0), Offset(size.width * 0.65, size.height), paint);
    // Carré central
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.3,
      height: size.height * 0.3,
    );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Peintre des vagues holographiques
// ─────────────────────────────────────────────────────────────────────────────
class _CardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Arcs bleus concentrés à droite
    for (int i = 0; i < 18; i++) {
      final t = i / 18.0;
      final radius = size.width * 0.4 + i * 14.0;
      final opacity = (0.12 - t * 0.08).clamp(0.0, 0.12);
      paint.color = const Color(0xFF1E7DBA).withOpacity(opacity);

      final center = Offset(size.width * 0.75, size.height * 0.5);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.6,
        math.pi * 0.9,
        false,
        paint,
      );
    }

    // Lignes ondulées en fond, côté droit
    for (int i = 0; i < 10; i++) {
      final y = size.height * 0.3 + i * 12.0;
      final opacity = (0.06 - i * 0.005).clamp(0.0, 0.08);
      paint.color = Colors.blue.withOpacity(opacity);
      paint.strokeWidth = 0.5;
      final path = Path();
      path.moveTo(size.width * 0.45, y);
      for (double x = size.width * 0.45; x <= size.width; x += 6) {
        final wave = math.sin((x / size.width) * math.pi * 4 + i) * 3;
        path.lineTo(x, y + wave);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Rangée de 5 boutons d'actions
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButtonsRow extends StatelessWidget {
  final BuildContext context;
  const _ActionButtonsRow({required this.context});

  @override
  Widget build(BuildContext wContext) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionBtn(
          icon: Icons.add_circle_outline,
          label: 'Recharger',
          onTap: () => showWalletSheet(context, const RechargerSheet()),
        ),
        _ActionBtn(
          icon: Icons.arrow_upward_rounded,
          label: 'Retirer',
          onTap: () => showWalletSheet(context, const RetirerSheet()),
        ),
        _ActionBtn(
          icon: Icons.send_rounded,
          label: 'Envoyer',
          onTap: () => showWalletSheet(context, const EnvoyerSheet()),
        ),
        _ActionBtn(
          icon: Icons.arrow_downward_rounded,
          label: 'Recevoir',
          onTap: () => showWalletSheet(context, const RecevoirSheet()),
        ),
        _ActionBtn(
          icon: Icons.bar_chart_rounded,
          label: 'Historique',
          onTap: () => showWalletSheet(context, const HistoriqueSheet()),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5A), Color(0xFF24496E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF1E7DBA).withOpacity(0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E7DBA).withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF7EC8F0)),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB0C8DC),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
