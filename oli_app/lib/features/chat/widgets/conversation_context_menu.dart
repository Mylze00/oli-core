import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/oli_glass.dart';

const _menuWidth = 268.0;
const _itemHeight = 46.0;
const _screenMargin = 12.0;
const _gap = 8.0;
const _danger = Color(0xFFE5484D);
const _headerHeight = 52.0;
const _maxPreviewShare = 0.4;

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
///
/// Par défaut l'aperçu occupe toute la largeur (ligne de la liste). Avec
/// [keepAnchorPosition], il reste exactement à sa place horizontale (bulle d'un message)
/// et le menu s'aligne du côté [alignEnd]. [header] s'affiche au-dessus de l'aperçu
/// (barre de réactions) et reçoit de quoi fermer le menu.
Future<void> showConversationContextMenu({
  required BuildContext context,
  required Rect anchor,
  required Widget preview,
  required List<ConversationMenuItem> items,
  bool keepAnchorPosition = false,
  bool alignEnd = false,
  double menuInset = _screenMargin,
  Widget Function(VoidCallback close)? header,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer le menu',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => _ConversationMenuOverlay(
      anchor: anchor,
      preview: preview,
      items: items,
      keepAnchorPosition: keepAnchorPosition,
      alignEnd: alignEnd,
      menuInset: menuInset,
      header: header,
    ),
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
  final bool keepAnchorPosition;
  final bool alignEnd;
  final double menuInset;
  final Widget Function(VoidCallback close)? header;

  const _ConversationMenuOverlay({
    required this.anchor,
    required this.preview,
    required this.items,
    required this.keepAnchorPosition,
    required this.alignEnd,
    required this.menuInset,
    required this.header,
  });

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
    final headerSpace = widget.header == null ? 0.0 : _headerHeight + _gap;
    final minTop = media.padding.top + _screenMargin + headerSpace;
    final maxBottom = media.size.height - media.padding.bottom - _screenMargin;
    // Un très long message est montré par son début : le menu doit rester visible
    final previewHeight = math.min(widget.anchor.height, media.size.height * _maxPreviewShare);
    final menuHeight = math.min(
      widget.items.length * _itemHeight + 16,
      maxBottom - minTop - previewHeight - _gap,
    );
    final previewTop = widget.anchor.top.clamp(
      minTop,
      math.max(minTop, maxBottom - menuHeight - _gap - previewHeight),
    ).toDouble();
    final menuWidth = math.min(_menuWidth, media.size.width - _screenMargin * 2);
    final sideOffset = widget.alignEnd ? media.size.width - widget.anchor.right : widget.anchor.left;
    final menuSide = widget.keepAnchorPosition ? math.max(widget.menuInset, sideOffset) : widget.menuInset;

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
          if (widget.keepAnchorPosition)
            Positioned(
              top: previewTop,
              left: widget.anchor.left,
              width: widget.anchor.width,
              height: previewHeight,
              child: IgnorePointer(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: widget.anchor.height,
                    child: widget.preview,
                  ),
                ),
              ),
            )
          else
            Positioned(
              top: previewTop,
              left: _screenMargin,
              right: _screenMargin,
              height: previewHeight,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: widget.preview),
                ),
              ),
            ),
          if (widget.header != null)
            Positioned(
              top: previewTop - _headerHeight - _gap,
              left: widget.alignEnd ? null : menuSide,
              right: widget.alignEnd ? menuSide : null,
              height: _headerHeight,
              child: widget.header!(() => Navigator.pop(context)),
            ),
          Positioned(
            top: previewTop + previewHeight + _gap,
            left: widget.alignEnd ? null : menuSide,
            right: widget.alignEnd ? menuSide : null,
            width: menuWidth,
            height: menuHeight,
            child: Align(
              alignment: widget.alignEnd ? Alignment.topRight : Alignment.topLeft,
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

/// Menu en verre déroulé sous un bouton (⋮ de l'en-tête), aligné sur son bord droit.
Future<void> showAnchoredGlassMenu({
  required BuildContext context,
  required Rect anchor,
  required List<ConversationMenuItem> items,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer le menu',
    barrierColor: Colors.black.withValues(alpha: 0.08),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, __, ___) => _AnchoredMenu(anchor: anchor, items: items),
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

class _AnchoredMenu extends StatefulWidget {
  final Rect anchor;
  final List<ConversationMenuItem> items;

  const _AnchoredMenu({required this.anchor, required this.items});

  @override
  State<_AnchoredMenu> createState() => _AnchoredMenuState();
}

class _AnchoredMenuState extends State<_AnchoredMenu> {
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
    final submenu = _openSubmenu;
    final rows = submenu == null
        ? [for (final item in widget.items) _MenuRow(item: item, isDark: isDark, onTap: () => _select(item))]
        : [
            _MenuRow(
              item: ConversationMenuItem(icon: Icons.arrow_back, label: submenu.label),
              isDark: isDark,
              onTap: () => setState(() => _openSubmenu = null),
            ),
            for (final item in submenu.submenu!) _MenuRow(item: item, isDark: isDark, onTap: () => _select(item)),
          ];
    final top = widget.anchor.bottom + 4;
    final maxHeight = media.size.height - media.padding.bottom - _screenMargin - top;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => Navigator.pop(context)),
          ),
          Positioned(
            top: top,
            right: math.max(_screenMargin, media.size.width - widget.anchor.right),
            width: math.min(_menuWidth, media.size.width - _screenMargin * 2),
            child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: OliGlassSurface(
                  borderRadius: BorderRadius.circular(22),
                  blur: 24,
                  tint: isDark ? const Color(0xB3242428) : const Color(0xD9F4F7FB),
                  borderColor: isDark ? const Color(0x33FFFFFF) : const Color(0x591E7DBA),
                  reflection: isDark ? 0.12 : 0.4,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(mainAxisSize: MainAxisSize.min, children: rows),
                  ),
                ),
            ),
          ),
        ],
      ),
    );
  }
}
