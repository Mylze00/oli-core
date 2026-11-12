import 'package:flutter/material.dart';

/// Confirmation « ajouté au panier » au centre de l'écran : chariot avec pastille verte
/// cochée, qui apparaît en rebondissant puis s'efface seule. Un nouvel ajout remplace
/// l'animation en cours (jamais d'empilement, rien qui reste affiché).
class CartAddedToast {
  CartAddedToast._();

  static OverlayEntry? _current;

  /// [onTap] : action au toucher (ex. ouvrir le panier).
  static void show(BuildContext context, {VoidCallback? onTap}) {
    _current?.remove();
    _current = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CartAddedToastView(
        onTap: onTap,
        onFinished: () {
          if (_current == entry) {
            entry.remove();
            _current = null;
          }
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _CartAddedToastView extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback onFinished;

  const _CartAddedToastView({required this.onFinished, this.onTap});

  @override
  State<_CartAddedToastView> createState() => _CartAddedToastViewState();
}

class _CartAddedToastViewState extends State<_CartAddedToastView> with SingleTickerProviderStateMixin {
  /// Apparition (0 → 0,25), maintien, puis disparition (0,8 → 1). Durée totale 1,8 s.
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
        ..forward().whenComplete(widget.onFinished);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartColor = isDark ? Colors.white : const Color(0xFF1F2328);

    return IgnorePointer(
      ignoring: widget.onTap == null,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, child) {
            final t = _controller.value;
            final appear = Curves.elasticOut.transform((t / 0.35).clamp(0.0, 1.0));
            final fade = t < 0.8 ? 1.0 : 1 - Curves.easeIn.transform((t - 0.8) / 0.2);
            final rise = t < 0.8 ? 0.0 : -24 * Curves.easeIn.transform((t - 0.8) / 0.2);
            // La pastille cochée arrive juste après le chariot
            final badge = Curves.easeOutBack.transform(((t - 0.15) / 0.25).clamp(0.0, 1.0));
            return Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, rise),
                child: Transform.scale(scale: 0.6 + 0.4 * appear, child: _content(isDark, cartColor, badge)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _content(bool isDark, Color cartColor, double badge) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 168,
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xF21C1C1E) : const Color(0xF7FFFFFF),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 96,
                height: 84,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: Icon(Icons.shopping_cart_outlined, size: 84, color: cartColor)),
                    Positioned(
                      top: -2,
                      right: 4,
                      child: Transform.scale(
                        scale: badge,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(color: Color(0xFF4CC777), shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ajouté au panier',
                style: TextStyle(color: cartColor, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
