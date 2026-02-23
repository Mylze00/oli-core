import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom Oli-branded RefreshIndicator that wraps Flutter's standard
/// RefreshIndicator and overlays the Oli logo during refresh.
/// Works reliably on both Web and Mobile.
class OliRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const OliRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<OliRefreshIndicator> createState() => _OliRefreshIndicatorState();
}

class _OliRefreshIndicatorState extends State<OliRefreshIndicator>
    with SingleTickerProviderStateMixin {
  
  bool _isRefreshing = false;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    _rotationController.repeat();
    
    try {
      await widget.onRefresh();
    } finally {
      _rotationController.stop();
      _rotationController.reset();
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _handleRefresh,
          displacement: 60,
          color: Colors.transparent,
          backgroundColor: Colors.transparent,
          child: widget.child,
        ),
        
        // Oli logo overlay during refresh
        if (_isRefreshing)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                listenable: _rotationController,
                builder: (context, _) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Transform.rotate(
                      angle: _rotationController.value * 2 * math.pi,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/oli_logo_refresh.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Simple widget that rebuilds when a Listenable changes.
class AnimatedBuilder extends StatefulWidget {
  final Listenable listenable;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.listenable,
    required this.builder,
    this.child,
  });

  @override
  State<AnimatedBuilder> createState() => _AnimatedBuilderState();
}

class _AnimatedBuilderState extends State<AnimatedBuilder> {
  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(AnimatedBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onUpdate);
      widget.listenable.addListener(_onUpdate);
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.child);
}
