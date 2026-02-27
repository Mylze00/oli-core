import 'dart:ui';
import 'package:flutter/material.dart';

/// SliverPersistentHeaderDelegate qui épingle la [QuickActionsRow] lors
/// du scroll et applique un effet glassmorphism quand l'utilisateur a scrollé.
class QuickActionsDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color backgroundColor;
  final bool isScrolled;

  const QuickActionsDelegate({
    required this.child,
    required this.backgroundColor,
    this.isScrolled = false,
  });

  @override
  double get minExtent => 90.0;

  @override
  double get maxExtent => 90.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fond : glass ou solide selon le scroll
        if (isScrolled)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: backgroundColor.withOpacity(0.60)),
            ),
          )
        else
          ColoredBox(color: backgroundColor),

        // Icônes toujours visibles par-dessus
        AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: 1.0,
          child: child,
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(QuickActionsDelegate oldDelegate) =>
      oldDelegate.child != child ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.isScrolled != isScrolled;
}
