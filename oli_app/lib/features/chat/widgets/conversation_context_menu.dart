import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/oli_glass.dart';

const _menuWidth = 268.0;
const _itemHeight = 46.0;
const _screenMargin = 12.0;
const _gap = 8.0;
const _danger = Color(0xFFE5484D);

/// Une ligne du menu. Avec [submenu], l'appui affiche ces choix à la place du menu.
class ConversationMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDanger;
  final List<ConversationMenuItem>? submenu;

  const ConversationMenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDanger = false,
    this.submenu,
  });
}

/// Détache la ligne pressée au-dessus de la liste floutée et affiche le menu en verre.
Future<void> showConversationContextMenu({
  required BuildContext context,
  required Rect anchor,
  required Widget preview,
  required List<ConversationMenuItem> items,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer le menu',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => _ConversationMenuOverlay(anchor: anchor, preview: preview, items: items),
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween<double>(begin: 0.97, end: 1).animate(curved), child: child),
      );
    },
  );
}

class _ConversationMenuOverlay extends StatefulWidget {
  final Rect anchor;
  final Widget preview;
  final List<ConversationMenuItem> items;

  const _ConversationMenuOverlay({required this.anchor, required this.preview, required this.items});

  @override
  State<_ConversationMenuOverlay> createState() => _ConversationMenuOverlayState();
}

class _ConversationMenuOverlayState extends State<_ConversationMenuOverlay> {
  ConversationMenuItem? _openSubmenu;

  void _select(ConversationMenuItem item) {
    if (item.submenu != null) {
      setState(() => _openSubmenu = item);
      return;
    }
    Navigator.pop(context);
    item.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final minTop = media.padding.top + _screenMargin;
    final maxBottom = media.size.height - media.padding.bottom - _screenMargin;
    final menuHeight = math.min(
      widget.items.length * _itemHeight + 16,
      maxBottom - minTop - widget.anchor.height - _gap,
    );
    final previewTop = widget.anchor.top.clamp(
      minTop,
      math.max(minTop, maxBottom - menuHeight - _gap - widget.anchor.height),
    ).toDouble();

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: ColoredBox(color: isDark ? const Color(0x73000000) : const Color(0x4D000000)),
              ),
            ),
          ),
          Positioned(
            top: previewTop,
            left: _screenMargin,
            right: _screenMargin,
            height: widget.anchor.height,
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: widget.preview),
              ),
            ),
          ),
          Positioned(
            top: previewTop + widget.anchor.height + _gap,
            left: _screenMargin,
            width: math.min(_menuWidth, media.size.width - _screenMargin * 2),
            height: menuHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: OliGlassSurface(
                borderRadius: BorderRadius.circular(20),
                blur: 24,
                tint: isDark ? const Color(0xB3242428) : const Color(0xD9F4F7FB),
                borderColor: isDark ? const Color(0x33FFFFFF) : const Color(0x591E7DBA),
                reflection: isDark ? 0.12 : 0.4,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(mainAxisSize: MainAxisSize.min, children: _buildRows(isDark)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRows(bool isDark) {
    final submenu = _openSubmenu;
    if (submenu != null) {
      return [
        _MenuRow(
          item: ConversationMenuItem(icon: Icons.arrow_back, label: submenu.label),
          isDark: isDark,
          onTap: () => setState(() => _openSubmenu = null),
        ),
        for (final item in submenu.submenu!) _MenuRow(item: item, isDark: isDark, onTap: () => _select(item)),
      ];
    }
    return [for (final item in widget.items) _MenuRow(item: item, isDark: isDark, onTap: () => _select(item))];
  }
}

class _MenuRow extends StatelessWidget {
  final ConversationMenuItem item;
  final bool isDark;
  final VoidCallback onTap;

  const _MenuRow({required this.item, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = item.isDanger ? _danger : (isDark ? Colors.white : Colors.black87);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _itemHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(item.icon, size: 21, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 15),
                ),
              ),
              if (item.submenu != null) Icon(Icons.chevron_right, size: 20, color: color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
