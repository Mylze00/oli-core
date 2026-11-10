import 'dart:math' as math;
import 'package:flutter/material.dart';

const _animationDuration = Duration(seconds: 4);
const _maxHearts = 14;
const _heartLifetime = 0.45;

/// Cœurs qui montent en disparaissant pendant 4 secondes au lancement d'une vidéo.
class FloatingLikes extends StatefulWidget {
  final int likesCount;
  final VoidCallback onFinished;

  const FloatingLikes({super.key, required this.likesCount, required this.onFinished});

  @override
  State<FloatingLikes> createState() => _FloatingLikesState();
}

class _FloatingLikesState extends State<FloatingLikes> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animationDuration);
    _controller.forward().whenComplete(() {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildHeart(int index, int heartCount, BoxConstraints constraints) {
    // Les départs sont répartis pour que le dernier cœur finisse à 4 secondes
    final start = heartCount == 1 ? 0.0 : index / (heartCount - 1) * (1 - _heartLifetime);
    final progress = ((_controller.value - start) / _heartLifetime).clamp(0.0, 1.0);
    if (progress == 0 || progress == 1) return const SizedBox.shrink();

    final sway = math.sin(progress * math.pi * 2 + index * 1.7) * 18;
    final size = 18.0 + (index % 3) * 6;
    return Positioned(
      bottom: progress * (constraints.maxHeight - size),
      right: constraints.maxWidth / 2 - size / 2 + sway,
      child: Opacity(
        opacity: 1 - progress,
        child: Transform.scale(
          scale: 0.7 + progress * 0.5,
          child: Icon(Icons.favorite, color: Colors.redAccent, size: size),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.shrink();
    }

    final heartCount = widget.likesCount.clamp(1, _maxHearts);
    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < heartCount; index++)
                  _buildHeart(index, heartCount, constraints),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
