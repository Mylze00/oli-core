import 'dart:math' as math;
import 'package:flutter/material.dart';

const _turnDuration = Duration(seconds: 20);
const _initialCenterLongitude = 20.0; // Afrique centrale face à l'utilisateur
const _tiltRadians = 0.22;
const _oceanColor = Color(0xFF2196F3);
const _oceanShadeColor = Color(0xFF1565C0);
const _landColor = Color(0xFF0B3C78);

/// Contours simplifiés des continents (longitude, latitude), suffisants à cette taille.
const _continents = <List<(double, double)>>[
  [
    (-17, 15), (-16, 28), (-6, 35), (10, 37), (32, 31), (43, 12), (51, 12), (40, -5),
    (40, -16), (33, -26), (20, -35), (13, -20), (9, -1), (9, 4), (-8, 4),
  ],
  [
    (-10, 37), (-9, 44), (-2, 50), (5, 53), (9, 58), (18, 68), (40, 68), (70, 73),
    (105, 78), (140, 73), (180, 68), (170, 60), (143, 52), (130, 42), (122, 30), (110, 21),
    (105, 10), (98, 13), (90, 22), (80, 13), (72, 20), (58, 25), (52, 17), (43, 13),
    (36, 30), (27, 37), (15, 38), (3, 42),
  ],
  [
    (-165, 65), (-155, 71), (-120, 70), (-95, 72), (-80, 65), (-62, 58), (-55, 50), (-67, 44),
    (-75, 35), (-81, 26), (-90, 29), (-97, 20), (-87, 15), (-80, 8), (-92, 14), (-105, 20),
    (-115, 31), (-124, 42), (-130, 55), (-150, 60),
  ],
  [
    (-80, 8), (-62, 10), (-50, 0), (-35, -6), (-39, -18), (-50, -30), (-65, -42), (-72, -53),
    (-75, -40), (-71, -18), (-81, -5),
  ],
  [
    (113, -22), (123, -16), (132, -12), (142, -11), (153, -26), (147, -38), (135, -33), (115, -34),
  ],
];

/// Globe dont les continents défilent lentement.
class RotatingGlobe extends StatefulWidget {
  final double size;

  const RotatingGlobe({super.key, this.size = 24});

  @override
  State<RotatingGlobe> createState() => _RotatingGlobeState();
}

class _RotatingGlobeState extends State<RotatingGlobe> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _turnDuration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respecte le réglage « réduire les animations » du téléphone
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: GlobePainter(turn: _controller),
      ),
    );
  }
}

/// Projette les continents sur la sphère selon la fraction de tour [turn].
class GlobePainter extends CustomPainter {
  final Animation<double> turn;

  GlobePainter({required this.turn}) : super(repaint: turn);

  Offset? _project(double longitude, double latitude, double centerLongitude, double radius, Offset center, List<bool> isVisible) {
    final lambda = (longitude - centerLongitude) * math.pi / 180;
    final phi = latitude * math.pi / 180;

    final x = math.cos(phi) * math.sin(lambda);
    final rawY = math.sin(phi);
    final rawZ = math.cos(phi) * math.cos(lambda);

    // Légère inclinaison, pour un aspect de sphère plutôt que de carte
    final y = rawY * math.cos(_tiltRadians) - rawZ * math.sin(_tiltRadians);
    final z = rawY * math.sin(_tiltRadians) + rawZ * math.cos(_tiltRadians);

    if (z > 0) {
      isVisible[0] = true;
      return center + Offset(x, -y) * radius;
    }
    // Un point caché est ramené sur le bord, pour fermer proprement le contour
    final length = math.sqrt(x * x + y * y);
    return length == 0 ? center : center + Offset(x / length, -y / length) * radius;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final circle = Rect.fromCircle(center: center, radius: radius);
    final centerLongitude = _initialCenterLongitude - turn.value * 360;

    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    canvas.drawRect(
      circle,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          radius: 1.05,
          colors: [_oceanColor, _oceanShadeColor],
        ).createShader(circle),
    );

    final land = Paint()
      ..color = _landColor
      ..isAntiAlias = true;
    for (final continent in _continents) {
      final isVisible = [false];
      final points = <Offset>[
        for (final (longitude, latitude) in continent)
          _project(longitude, latitude, centerLongitude, radius, center, isVisible)!,
      ];
      if (isVisible[0]) {
        canvas.drawPath(Path()..addPolygon(points, true), land);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GlobePainter oldDelegate) => oldDelegate.turn != turn;
}
