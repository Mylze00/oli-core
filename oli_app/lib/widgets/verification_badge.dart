import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Twitter/X-style scalloped verification badge widget
/// Built with CustomPainter (no external dependencies)
enum BadgeType {
  blue,    // Certifié / Verified
  gold,    // Shop certifié / Entreprise
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
  /// Returns null if user is ordinary (no badge)
  static BadgeType? fromSellerData({
    required bool isVerified,
    required String accountType,
    required bool hasCertifiedShop,
  }) {
    // Gold for entreprise or certified shop
    if (hasCertifiedShop || accountType == 'entreprise') {
      return BadgeType.gold;
    }
    // Blue for certified users
    if (accountType == 'certifie' || isVerified) {
      return BadgeType.blue;
    }
    // No badge for ordinary users
    return null;
  }

  /// Helper to determine badge from User model
  static BadgeType? fromUser(dynamic user) {
     // Support dynamic map (from backend JSON) or strong typed User
     final accountType = user is Map ? user['account_type'] : user.accountType;
     final isVerified = user is Map ? user['is_verified'] : user.isVerified;
     final subPlan = user is Map ? user['subscription_plan'] : user.subscriptionPlan;
     final hasCertifiedShop = user is Map ? user['has_certified_shop'] : false; // Optional

     if (accountType == 'entreprise' || subPlan == 'enterprise' || hasCertifiedShop == true) {
       return BadgeType.gold;
     }
     if (accountType == 'certifie' || subPlan == 'certified' || isVerified == true) {
       return BadgeType.blue;
     }
     return null; // No badge for ordinary
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
