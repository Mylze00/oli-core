import 'package:flutter/material.dart';

/// Découpe le widget ticket avec des encoches semi-circulaires sur les côtés
class TicketClipper extends CustomClipper<Path> {
  final double notchPosition; // 0.0 à 1.0 (position verticale des encoches)
  final double notchRadius;

  const TicketClipper({
    this.notchPosition = 0.63,
    this.notchRadius = 18.0,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final notchY = size.height * notchPosition;

    // Côté gauche
    path.moveTo(0, 0);
    path.lineTo(0, notchY - notchRadius);
    path.arcToPoint(
      Offset(0, notchY + notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(0, size.height);

    // Bas
    path.lineTo(size.width, size.height);

    // Côté droit (remonter)
    path.lineTo(size.width, notchY + notchRadius);
    path.arcToPoint(
      Offset(size.width, notchY - notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(size.width, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(TicketClipper oldClipper) =>
      oldClipper.notchPosition != notchPosition ||
      oldClipper.notchRadius != notchRadius;
}

/// Dessine une ligne pointillée horizontale
class DashLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  const DashLinePainter({
    this.color = const Color(0xFF3A3A3A),
    this.dashWidth = 6,
    this.dashSpace = 4,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(DashLinePainter oldDelegate) => false;
}
