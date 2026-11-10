import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../marketplace/presentation/pages/all_categories_page.dart';
import '../../../services/request_product_page.dart';
import '../../../services/services_page.dart';
import '../../../services/miniapps_page.dart';
import '../../../oticket/pages/oticket_page.dart';
import '../../../services/live_shopping_page.dart';

import 'rotating_globe.dart';
import 'service_glass_panel.dart';

class QuickActionsRow extends ConsumerWidget {
  final VoidCallback? onCategoryTap;

  const QuickActionsRow({super.key, this.onCategoryTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          _buildAnimatedCategoryActionCard(context, isDark, "Catégorie", () {
              if (onCategoryTap != null) {
                onCategoryTap!();
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AllCategoriesPage()));
              }
          }),
          _buildCustomIconActionCard(context, isDark, "Demande", const _AnimatedMegaphone(), () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestProductPage()));
          }),
          _buildCustomIconActionCard(context, isDark, "Service", const RotatingGlobe(), () {
            showDialog(
              context: context, 
              builder: (_) => const ServiceGlassPanel(),
            );
          }),
          _buildTicketActionCard(context, isDark, "O-ticket", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OTicketPage()));
          }),
          _buildAnimatedLiveActionCard(context, isDark, "Live", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveShoppingPage()));
          }),
        ],
      ),
    );
  }

  Widget _buildAnimatedCategoryActionCard(BuildContext context, bool isDark, String title, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AnimatedCategoryIcon(isDark: isDark),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'CreatoDisplay',
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, bool isDark, String title, IconData icon, Color color, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.06),
                shape: BoxShape.circle,
                border: isDark ? null : Border.all(
                  color: Colors.white, 
                  width: 1.5
                ),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              title, 
              textAlign: TextAlign.center, 
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'CreatoDisplay',
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.w500)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomIconActionCard(BuildContext context, bool isDark, String title, Widget icon, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.06),
                shape: BoxShape.circle,
                border: isDark ? null : Border.all(
                  color: Colors.white,
                  width: 1.5
                ),
              ),
              child: icon,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'CreatoDisplay',
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketActionCard(BuildContext context, bool isDark, String title, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AnimatedTicketIcon(isDark: isDark),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'CreatoDisplay',
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageActionCard(BuildContext context, bool isDark, String title, String imagePath, VoidCallback? onTap, {double size = 24.0}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.06),
                shape: BoxShape.circle,
                border: isDark ? null : Border.all(
                  color: Colors.white, 
                  width: 1.5
                ),
              ),
              child: Image.asset(
                imagePath,
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'CreatoDisplay',
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedLiveActionCard(BuildContext context, bool isDark, String title, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 1.0, end: 1.15),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              onEnd: () {
                // To make it loop, we'd need a StatefulWidget. 
                // But a simple TweenAnimationBuilder doesn't loop natively without rebuilding.
                // For a proper loop without converting QuickActionsRow to stateful:
              },
              child: _LivePulseIcon(isDark: isDark),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'CreatoDisplay',
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.w500), // Bold for Live
            ),
          ],
        ),
      ),
    );
  }
}

/// Mégaphone qui donne une courte impulsion, puis reste immobile.
class _AnimatedMegaphone extends StatefulWidget {
  const _AnimatedMegaphone();

  @override
  State<_AnimatedMegaphone> createState() => _AnimatedMegaphoneState();
}

class _AnimatedMegaphoneState extends State<_AnimatedMegaphone> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4700));

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.14), weight: 5),
    TweenSequenceItem(tween: Tween(begin: 1.14, end: 1.0), weight: 6),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 5),
    TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 6),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 78),
  ]).animate(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0;
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
    return ScaleTransition(
      scale: _scale,
      child: Image.asset('assets/images/megaphone_icon.png', width: 24, height: 24, fit: BoxFit.contain),
    );
  }
}

/// Billet qui se balance puis reçoit un reflet, avant une pause.
class _AnimatedTicketIcon extends StatefulWidget {
  final bool isDark;
  const _AnimatedTicketIcon({required this.isDark});

  @override
  State<_AnimatedTicketIcon> createState() => _AnimatedTicketIconState();
}

class _AnimatedTicketIconState extends State<_AnimatedTicketIcon> with SingleTickerProviderStateMixin {
  static const _shineBandWidth = 0.35;

  late final AnimationController _controller;

  // Le mouvement occupe le début du cycle, le reste est une pause.
  late final Animation<double> _rotation = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.16), weight: 5),
    TweenSequenceItem(tween: Tween(begin: -0.16, end: 0.14), weight: 7),
    TweenSequenceItem(tween: Tween(begin: 0.14, end: -0.08), weight: 6),
    TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.0), weight: 5),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 77),
  ]).animate(_controller);

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.14), weight: 10),
    TweenSequenceItem(tween: Tween(begin: 1.14, end: 1.0), weight: 13),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 77),
  ]).animate(_controller);

  late final Animation<double> _shine = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.24, 0.5, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respecte le réglage « réduire les animations » du téléphone
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Shader _shineShader(Rect bounds) {
    // Le reflet traverse le billet de gauche à droite pendant sa phase du cycle
    final position = -_shineBandWidth + _shine.value * (1 + 2 * _shineBandWidth);
    return LinearGradient(
      colors: const [Colors.transparent, Color(0xB3FFFFFF), Colors.transparent],
      stops: [
        (position - _shineBandWidth / 2).clamp(0.0, 1.0),
        position.clamp(0.0, 1.0),
        (position + _shineBandWidth / 2).clamp(0.0, 1.0),
      ],
    ).createShader(bounds);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.06),
        shape: BoxShape.circle,
        border: widget.isDark ? null : Border.all(
          color: Colors.white,
          width: 1.5
        ),
      ),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          child: Image.asset(
            'assets/images/ticket_icon.png',
            width: 36,
            height: 36,
            fit: BoxFit.contain,
          ),
          builder: (context, child) => Transform.rotate(
            angle: _rotation.value,
            child: Transform.scale(
              scale: _scale.value,
              child: _shine.value > 0 && _shine.value < 1
                  ? ShaderMask(
                      shaderCallback: _shineShader,
                      blendMode: BlendMode.srcATop,
                      child: child,
                    )
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}

class _LivePulseIcon extends StatefulWidget {
  final bool isDark;
  const _LivePulseIcon({required this.isDark});

  @override
  State<_LivePulseIcon> createState() => _LivePulseIconState();
}

class _LivePulseIconState extends State<_LivePulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.06),
        shape: BoxShape.circle,
        border: widget.isDark ? null : Border.all(
          color: Colors.white, 
          width: 1.5
        ),
      ),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: const Icon(Icons.live_tv, color: Colors.redAccent, size: 24),
      ),
    );
  }
}

class _AnimatedCategoryIcon extends StatefulWidget {
  final bool isDark;
  const _AnimatedCategoryIcon({required this.isDark});

  @override
  State<_AnimatedCategoryIcon> createState() => _AnimatedCategoryIconState();
}

class _AnimatedCategoryIconState extends State<_AnimatedCategoryIcon> {
  int _currentIndex = 0;
  Timer? _timer;

  final List<IconData> _categoryIcons = [
    Icons.grid_view,
    Icons.phone_android,
    Icons.checkroom,
    Icons.chair,
    Icons.restaurant,
    Icons.face,
    Icons.sports_soccer,
    Icons.directions_car,
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _categoryIcons.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.06),
        shape: BoxShape.circle,
        border: widget.isDark ? null : Border.all(
          color: Colors.white, 
          width: 1.5
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: Icon(
          _categoryIcons[_currentIndex],
          key: ValueKey<int>(_currentIndex),
          color: Colors.orange,
          size: 24,
        ),
      ),
    );
  }
}

