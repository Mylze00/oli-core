import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Billet de transfert cash — design skeuomorphique moderne
/// Affiche montant, expéditeur/destinataire, date, statut et numéro de réf.
class CashBillWidget extends StatefulWidget {
  final double amount;
  final String senderName;
  final String recipientName;
  final String? reference;
  final DateTime? date;
  final String status; // 'pending' | 'completed' | 'failed'
  final String currency;

  const CashBillWidget({
    super.key,
    required this.amount,
    required this.senderName,
    required this.recipientName,
    this.reference,
    this.date,
    this.status = 'completed',
    this.currency = 'FC',
  });

  @override
  State<CashBillWidget> createState() => _CashBillWidgetState();
}

class _CashBillWidgetState extends State<CashBillWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.status) {
      case 'completed': return const Color(0xFF00C853);
      case 'pending': return const Color(0xFFFF8F00);
      case 'failed': return const Color(0xFFDD2C00);
      default: return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (widget.status) {
      case 'completed': return '✓ Transféré';
      case 'pending': return '⏳ En attente';
      case 'failed': return '✗ Échoué';
      default: return widget.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = widget.date != null
        ? '${widget.date!.day.toString().padLeft(2, '0')}/'
          '${widget.date!.month.toString().padLeft(2, '0')}/'
          '${widget.date!.year}  '
          '${widget.date!.hour.toString().padLeft(2, '0')}:'
          '${widget.date!.minute.toString().padLeft(2, '0')}'
        : '';

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D32).withOpacity(0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // ── Motif filigrane ──────────────────────────────────────────
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomPaint(painter: _WatermarkPainter()),
                ),
              ),

              // ── Découpe semi-circulaire gauche/droite (style billet) ───
              Positioned(
                left: -18, top: 0, bottom: 0,
                child: Center(
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -18, top: 0, bottom: 0,
                child: Center(
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

              // ── Contenu principal ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'OLI CASH',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _statusColor, width: 1),
                          ),
                          child: Text(
                            _statusLabel,
                            style: TextStyle(
                              color: _statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Montant principal
                    Text(
                      '${_formatAmount(widget.amount)} ${widget.currency}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 4),
                    Container(height: 1, color: Colors.white24),
                    const SizedBox(height: 16),

                    // Expéditeur → Destinataire
                    Row(
                      children: [
                        _PartyInfo(label: 'De', name: widget.senderName),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.arrow_forward_rounded, color: Colors.white54, size: 20),
                        ),
                        _PartyInfo(label: 'À', name: widget.recipientName),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Container(height: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 0)),
                    const SizedBox(height: 12),

                    // Date + Référence
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (dateStr.isNotEmpty)
                          Text(
                            dateStr,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        if (widget.reference != null)
                          Text(
                            'Réf: ${widget.reference}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      final parts = amount.toStringAsFixed(0).split('');
      final result = StringBuffer();
      for (int i = 0; i < parts.length; i++) {
        if (i > 0 && (parts.length - i) % 3 == 0) result.write('.');
        result.write(parts[i]);
      }
      return result.toString();
    }
    return amount.toStringAsFixed(0);
  }
}

class _PartyInfo extends StatelessWidget {
  final String label;
  final String name;
  const _PartyInfo({required this.label, required this.name});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// CustomPainter pour le motif filigrane sur le billet
class _WatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Cercles concentriques
    for (double r = 20; r < size.width * 0.8; r += 30) {
      canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.5),
        r,
        paint,
      );
    }

    // Lignes diagonales
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    for (double i = -size.height; i < size.width + size.height; i += 18) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WatermarkPainter oldDelegate) => false;
}
