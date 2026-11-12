import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Tirer pour actualiser, façon Alibaba.
///
/// En tirant vers le bas depuis le haut de la page, une zone vide s'ouvre et le logo
/// Oli y apparaît, grandit et tourne au rythme du doigt. Il faut insister : la zone
/// s'ouvre deux fois moins vite que le doigt et ne recharge qu'au-delà de
/// [triggerDistance]. Relâché avant, tout se referme sans recharger ; relâché après,
/// la zone reste ouverte et le logo tourne jusqu'à la fin du rechargement.
///
/// Avec [inlineGap], la page ne descend pas en bloc : la zone s'ouvre là où la page
/// place un [OliRefreshGap] (par exemple juste sous la barre de recherche).
class OliRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  /// Ouverture de la zone (en px affichés) nécessaire pour recharger.
  /// Avec la résistance, le doigt doit parcourir environ deux fois cette distance.
  final double triggerDistance;

  /// La zone s'ouvre dans la page, à l'emplacement d'un [OliRefreshGap].
  final bool inlineGap;

  const OliRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.triggerDistance = 90,
    this.inlineGap = false,
  });

  @override
  State<OliRefreshIndicator> createState() => _OliRefreshIndicatorState();
}

enum _Phase { idle, dragging, refreshing, settling }

class _OliRefreshIndicatorState extends State<OliRefreshIndicator> with TickerProviderStateMixin {
  /// Résistance : la zone s'ouvre de [_resistance] px pour 1 px de doigt.
  static const _resistance = 0.5;
  static const _maxPull = 150.0;

  /// Hauteur de la zone gardée ouverte pendant le rechargement.
  static const _holdHeight = 72.0;

  double _pull = 0;
  _Phase _phase = _Phase.idle;
  bool _armed = false;

  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _settle = AnimationController(vsync: this);
  Animation<double>? _settleAnim;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      if (_settleAnim != null) setState(() => _pull = _settleAnim!.value);
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    _settle.dispose();
    super.dispose();
  }

  Future<void> _animateTo(double target, {int ms = 260}) async {
    _settleAnim = Tween<double>(begin: _pull, end: target)
        .animate(CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic));
    _settle.duration = Duration(milliseconds: ms);
    await _settle.forward(from: 0);
  }

  bool _onNotification(ScrollNotification n) {
    if (n.depth != 0) return false; // seulement le défilement principal
    if (_phase == _Phase.refreshing || _phase == _Phase.settling) return false;

    if (n is OverscrollNotification && n.overscroll < 0 && n.dragDetails != null) {
      // Tirage au-delà du haut : la zone s'ouvre
      _phase = _Phase.dragging;
      _setPull(_pull - n.overscroll * _resistance);
    } else if (n is ScrollUpdateNotification && _pull > 0 && n.dragDetails != null) {
      // Le doigt remonte alors que la zone est ouverte : elle se referme d'abord
      final delta = n.scrollDelta ?? 0;
      if (delta > 0) _setPull(_pull - delta);
    } else if (n is ScrollEndNotification ||
        (n is UserScrollNotification && n.direction == ScrollDirection.idle)) {
      if (_phase == _Phase.dragging) _release();
    }
    return false;
  }

  void _setPull(double value) {
    final next = value.clamp(0.0, _maxPull);
    final nowArmed = next >= widget.triggerDistance;
    if (nowArmed && !_armed) HapticFeedback.lightImpact(); // seuil atteint
    setState(() {
      _pull = next;
      _armed = nowArmed;
    });
  }

  Future<void> _release() async {
    if (_armed) {
      setState(() => _phase = _Phase.refreshing);
      _spin.repeat();
      await _animateTo(_holdHeight, ms: 200);
      try {
        await widget.onRefresh();
      } finally {
        if (mounted) {
          setState(() => _phase = _Phase.settling);
          await _animateTo(0, ms: 320);
          _spin.stop();
          _spin.reset();
          if (mounted) {
            setState(() {
              _phase = _Phase.idle;
              _armed = false;
            });
          }
        }
      }
    } else {
      setState(() => _phase = _Phase.settling);
      await _animateTo(0);
      if (mounted) setState(() => _phase = _Phase.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_pull / widget.triggerDistance).clamp(0.0, 1.0);
    final refreshing = _phase == _Phase.refreshing || (_phase == _Phase.settling && _spin.isAnimating);

    // Défilement « clampé » partout : même rendu web, Android et iPhone
    final scrollable = NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: ScrollConfiguration(
        behavior: const _ClampedNoGlow(),
        child: widget.inlineGap ? widget.child : Transform.translate(offset: Offset(0, _pull), child: widget.child),
      ),
    );

    return _OliPullScope(
      pull: _pull,
      progress: progress,
      refreshing: refreshing,
      spin: _spin,
      child: widget.inlineGap
          ? scrollable
          : Stack(
              children: [
                scrollable,
                if (_pull > 2)
                  Positioned(
                    top: MediaQuery.of(context).padding.top,
                    left: 0,
                    right: 0,
                    height: _pull,
                    child: const IgnorePointer(child: _OliPullLogo()),
                  ),
              ],
            ),
    );
  }
}

/// État de l'ouverture partagé avec la page (pour [OliRefreshGap]).
class _OliPullScope extends InheritedWidget {
  final double pull;
  final double progress;
  final bool refreshing;
  final AnimationController spin;

  const _OliPullScope({
    required this.pull,
    required this.progress,
    required this.refreshing,
    required this.spin,
    required super.child,
  });

  static _OliPullScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_OliPullScope>();

  @override
  bool updateShouldNotify(_OliPullScope old) =>
      old.pull != pull || old.progress != progress || old.refreshing != refreshing;
}

/// Zone extensible à placer dans la page (dans un SliverToBoxAdapter), là où la zone
/// d'actualisation doit s'ouvrir — par exemple juste sous la barre de recherche.
class OliRefreshGap extends StatelessWidget {
  const OliRefreshGap({super.key});

  @override
  Widget build(BuildContext context) {
    final pull = _OliPullScope.of(context)?.pull ?? 0;
    if (pull <= 0.5) return const SizedBox.shrink();
    return SizedBox(height: pull, child: const _OliPullLogo());
  }
}

/// Logo Oli : grandit et tourne avec le doigt, tourne en continu pendant le rechargement.
class _OliPullLogo extends StatelessWidget {
  const _OliPullLogo();

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final scope = _OliPullScope.of(context);
    if (scope == null) return const SizedBox.shrink();
    return ClipRect(
      child: Center(
        child: AnimatedBuilder(
          animation: scope.spin,
          builder: (_, child) {
            final angle = scope.refreshing ? scope.spin.value * 2 * math.pi : scope.progress * math.pi;
            return Opacity(
              opacity: scope.refreshing ? 1 : scope.progress,
              child: Transform.scale(
                scale: scope.refreshing ? 1 : 0.5 + 0.5 * scope.progress,
                child: Transform.rotate(angle: angle, child: child),
              ),
            );
          },
          child: Image.asset('assets/images/oli_logo_refresh.png', width: _size, height: _size, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// Défilement sans rebond ni halo : l'ouverture de la zone est gérée ci-dessus.
class _ClampedNoGlow extends ScrollBehavior {
  const _ClampedNoGlow();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
