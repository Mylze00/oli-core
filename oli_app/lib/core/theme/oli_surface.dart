import 'package:flutter/material.dart';

/// Langage visuel commun des pages « opérations » (tableau de bord, commandes,
/// ventes, panier, favoris, boutiques), tiré de la page de validation de commande :
/// fond noir ou gris très clair, cartes arrondies à bordure fine, accents bleu Oli.
class OliSurface {
  final bool isDark;
  final Color background;
  final Color card;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color tile;
  final Color accent;
  final Color success;
  final Color danger;

  const OliSurface._({
    required this.isDark,
    required this.background,
    required this.card,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.tile,
    required this.accent,
    required this.success,
    required this.danger,
  });

  /// Bleu Oli de la marque.
  static const Color oliBlue = Color(0xFF1E7DBA);

  factory OliSurface.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const OliSurface._(
            isDark: true,
            background: Colors.black,
            card: Color(0xFF1C1C1E),
            border: Color(0x1FFFFFFF),
            text: Colors.white,
            textSecondary: Color(0xFF9A9AA0),
            tile: Color(0x14FFFFFF),
            accent: Color(0xFF3B8EF0),
            success: Color(0xFF30D158),
            danger: Color(0xFFFF6B6B),
          )
        : const OliSurface._(
            isDark: false,
            background: Color(0xFFF5F6F8),
            card: Colors.white,
            border: Color(0xFFE6E8EC),
            text: Color(0xFF111418),
            textSecondary: Color(0xFF5F6673),
            tile: Color(0xFFF1F3F6),
            accent: oliBlue,
            success: Color(0xFF16A34A),
            danger: Color(0xFFE5484D),
          );
  }

  /// Décoration d'une carte (bordure fine, ombre légère en mode clair).
  BoxDecoration cardDecoration({double radius = 16, Color? borderColor}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? border),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 2))],
      );

  /// Barre du haut sobre, du même fond que la page.
  PreferredSizeWidget appBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) => AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        title: Text(title, style: TextStyle(color: text, fontWeight: FontWeight.w700)),
        actions: actions,
        bottom: bottom,
      );
}

/// Carte standard des pages opérations.
class OliCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const OliCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = OliSurface.of(context);
    return Container(
      margin: margin,
      decoration: s.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Pastille de statut neutre : point coloré, texte lisible.
class OliStatusPill extends StatelessWidget {
  final String label;
  final Color dot;

  const OliStatusPill({super.key, required this.label, required this.dot});

  @override
  Widget build(BuildContext context) {
    final s = OliSurface.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: s.tile, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: s.text, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// État vide : icône dans un cercle, titre, sous-titre et action facultative.
class OliEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const OliEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final s = OliSurface.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: s.tile, shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: s.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(color: s.text, fontSize: 17, fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: s.textSecondary, fontSize: 14)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OliSurface.oliBlue,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                ),
                child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
