import 'dart:math' as math;
import 'package:flutter/material.dart';

const _noteAspectRatio = 2.05;
const _maxNoteWidth = 300.0;
const _noteGreen = Color(0xFF0F5A43);
const _paper = Color(0xFFF6EFD9);
const _gold = Color(0xFFE3C878);

/// Envoi d'argent attesté par le serveur, affiché comme un billet.
class CashNoteBubble extends StatelessWidget {
  final num amountFc;
  final bool isMe;
  final String? note;
  final Color noteTextColor;
  final Widget footer;

  const CashNoteBubble({
    super.key,
    required this.amountFc,
    required this.isMe,
    required this.noteTextColor,
    required this.footer,
    this.note,
  });

  static String _formatAmount(num amount) => amount
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ' ');

  static String _cornerValue(num amount) {
    String compact(double value) =>
        value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1).replaceAll('.', ',');
    if (amount >= 1000000) return '${compact(amount / 1000000)}M';
    if (amount >= 1000) return '${compact(amount / 1000)}K';
    return amount.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final amount = _formatAmount(amountFc);
    final width = math.min(MediaQuery.of(context).size.width * 0.75, _maxNoteWidth);

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '$amount francs congolais ${isMe ? 'envoyés' : 'reçus'}',
          child: ExcludeSemantics(
            child: SizedBox(
              width: width,
              child: AspectRatio(aspectRatio: _noteAspectRatio, child: _buildNote(amount)),
            ),
          ),
        ),
        if (note != null && note!.isNotEmpty)
          SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
              child: Text(note!, style: TextStyle(color: noteTextColor, fontSize: 14, height: 1.3)),
            ),
          ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: footer),
      ],
    );
  }

  Widget _buildNote(String amount) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: const _BanknotePainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  _buildBand('OLI CASH', _cornerValue(amountFc)),
                  Expanded(
                    child: Row(
                      children: [
                        _buildMedallion(),
                        const SizedBox(width: 10),
                        Expanded(child: _buildAmountBox(amount)),
                      ],
                    ),
                  ),
                  _buildBand(_cornerValue(amountFc), isMe ? 'ENVOYÉ' : 'REÇU'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBand(String left, String right) {
    const style = TextStyle(
      color: _gold,
      fontFamily: 'CreatoDisplay',
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(left, style: style), Text(right, style: style)],
    );
  }

  Widget _buildMedallion() {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _paper,
        border: Border.all(color: _gold, width: 2),
      ),
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
  }

  Widget _buildAmountBox(String amount) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _gold, width: 1.5),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$amount FC',
            maxLines: 1,
            style: const TextStyle(
              color: _noteGreen,
              fontFamily: 'CreatoDisplay',
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fond du billet : dégradé, fines vagues de sécurité et double cadre.
class _BanknotePainter extends CustomPainter {
  const _BanknotePainter();

  static const _waveCount = 18;
  static const _waveHeight = 5.0;
  static const _wavelength = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_noteGreen, Color(0xFF1F8061), _noteGreen],
        ).createShader(bounds),
    );

    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.16);
    for (var i = 0; i < _waveCount; i++) {
      final baseline = size.height * i / (_waveCount - 1);
      final path = Path()..moveTo(0, baseline);
      for (double x = 2; x <= size.width; x += 2) {
        path.lineTo(x, baseline + math.sin((x / _wavelength + i / 4) * 2 * math.pi) * _waveHeight);
      }
      canvas.drawPath(path, wavePaint);
    }

    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = _gold;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(4), const Radius.circular(5)),
      framePaint..strokeWidth = 1.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(7), const Radius.circular(3)),
      framePaint..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(_BanknotePainter oldDelegate) => false;
}
