import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Tirer pour actualiser, façon Alibaba.
///
/// En tirant vers le bas depuis le haut de la page, tout le contenu descend et ouvre
/// une zone vide où le logo Oli apparaît, grandit et tourne au rythme du doigt.
/// Il faut insister : la page résiste (le contenu descend deux fois moins vite que
/// le doigt) et ne recharge qu'au-delà de [triggerDistance]. Relâché avant, tout
/// remonte sans recharger ; relâché après, la zone reste ouverte et le logo tourne
/// jusqu'à la fin du rechargement, puis elle se referme.
class OliRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  /// Ouverture de la zone (en px affichés) nécessaire pour recharger.
  /// Avec la résistance, le doigt doit parcourir environ deux fois cette distance.
  final double triggerDistance;

  const OliRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.triggerDistance = 90,
  });

  @override
  State<OliRefreshIndicator> createState() => _OliRefreshIndicatorState();
}

enum _Phase { idle, dragging, refreshing, settling }

class _OliRefreshIndicatorState extends State<OliRefreshIndicator> with TickerProviderStateMixin {
  /// Résistance : le contenu descend de [_resistance] px pour 1 px de doigt.
  static const _resistance = 0.5;
  static const _maxPull = 150.0;

  /// Hauteur de la zone gardée ouverte pendant le rechargement.
  static const _holdHeight = 72.0;
  static const _logoSize = 40.0;

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

  /// Anime l'ouverture de la zone vers [target].
  Future<void> _animateTo(double target, {int ms = 260}) async {
    _settleAnim = Tween<double>(begin: _pull, end: target)
        .animate(CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic));
    _settle.duration = Duration(milliseconds: ms);
    await _settle.forward(from: 0);
  }

  bool _onNotification(ScrollNotification n) {
    if (n.depth != 0) return false; // seulement le défilement principal
    if (_phase == _Phase.refreshing || _phase == _Phase.settling) return false;

    // Tirage au-delà du haut (défilement « clampé ») : la zone s'ouvre
    if (n is OverscrollNotification && n.overscroll < 0 && n.dragDetails != null) {
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
    final topInset = MediaQuery.of(context).padding.top;
    final progress = (_pull / widget.triggerDistance).clamp(0.0, 1.0);
    final refreshing = _phase == _Phase.refreshing || (_phase == _Phase.settling && _spin.isAnimating);

    return Stack(
      children: [
        // Contenu : défilement « clampé » partout (même rendu web, Android, iPhone),
        // décalé vers le bas de l'ouverture de la zone
        NotificationListener<ScrollNotification>(
          onNotification: _onNotification,
          child: ScrollConfiguration(
            behavior: const _ClampedNoGlow(),
            child: Transform.translate(offset: Offset(0, _pull), child: widget.child),
          ),
        ),

        // Logo Oli dans la zone ouverte
        if (_pull > 2)
          Positioned(
            top: topInset + (_pull - _logoSize) / 2,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (_, child) {
                    final angle = refreshing ? _spin.value * 2 * math.pi : progress * math.pi;
                    return Opacity(
                      opacity: refreshing ? 1 : progress,
                      child: Transform.scale(
                        scale: refreshing ? 1 : 0.5 + 0.5 * progress,
                        child: Transform.rotate(angle: angle, child: child),
                      ),
                    );
                  },
                  child: Image.asset(
                    'assets/images/oli_logo_refresh.png',
                    width: _logoSize,
                    height: _logoSize,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
      ],
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
