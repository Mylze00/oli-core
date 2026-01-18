import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Twitter/X-style scalloped verification badge widget
/// Built with CustomPainter (no external dependencies)
enum BadgeType {
  blue,    // Certifié / Verified
  gold,    // Shop certifié / Entreprise
  green,   // Premium
  gray     // Standard/Ordinaire
}

class VerificationBadge extends StatelessWidget {
  final BadgeType type;
  final double size;

  const VerificationBadge({
    super.key,
    this.type = BadgeType.blue,
    this.size = 20,
  });

  Color get _badgeColor {
    switch (type) {
      case BadgeType.blue:
        return const Color(0xFF1DA1F2); // Twitter blue
      case BadgeType.gold:
        return const Color(0xFFD4A500); // Gold
      case BadgeType.green:
        return const Color(0xFF00BA7C); // Green
      case BadgeType.gray:
        return const Color(0xFF71767B); // Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _VerificationBadgePainter(color: _badgeColor),
    );
  }

  /// Helper to determine badge type from product seller data
  static BadgeType fromSellerData({
    required bool isVerified,
    required String accountType,
    required bool hasCertifiedShop,
  }) {
    if (hasCertifiedShop || accountType == 'entreprise') {
      return BadgeType.gold;
    } else if (accountType == 'premium') {
      return BadgeType.green;
    } else if (accountType == 'certifie' || isVerified) {
      return BadgeType.blue;
    } else {
      return BadgeType.gray;
    }
  }
}

class _VerificationBadgePainter extends CustomPainter {
  final Color color;

  _VerificationBadgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw scalloped circle (simplified, using circle for performance)
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    canvas.drawCircle(center, radius, paint);

    // Draw white checkmark
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final smallLeg = size.width * 0.3;
    final longLeg = size.width * 0.5;
    
    path.moveTo(center.dx - longLeg * 0.4, center.dy);
    path.lineTo(center.dx - longLeg * 0.1, center.dy + smallLeg * 0.5);
    path.lineTo(center.dx + longLeg * 0.4, center.dy - smallLeg * 0.7);

    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
