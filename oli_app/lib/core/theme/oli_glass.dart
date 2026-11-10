import 'dart:ui';
import 'package:flutter/material.dart';

/// Palette des écrans sombres en verre, autour du bleu Oli.
class OliPalette {
  OliPalette._();

  static const Color blue = Color(0xFF1E7DBA);

  /// Bleu éclairci, lisible en texte sur fond sombre.
  static const Color blueOnDark = Color(0xFF6CB8EA);
  static const Color navy = Color(0xFF0B1727);
  static const Color navyLight = Color(0xFF12344F);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color hairline = Color(0x24FFFFFF);
  static const Color danger = Color(0xFFF87171);
}

/// Fond dégradé qui donne de la profondeur à l'effet verre.
const LinearGradient oliBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [OliPalette.navyLight, OliPalette.navy],
);

/// Carte en verre pour les listes : sans flou, pour rester fluide au défilement.
BoxDecoration oliGlassCardDecoration({bool highlighted = false, double radius = 18}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x1FFFFFFF), Color(0x0DFFFFFF)],
    ),
    border: Border.all(
      color: highlighted ? OliPalette.blueOnDark : OliPalette.hairline,
    ),
  );
}

/// Panneau en verre dépoli, réservé aux dialogues et feuilles.
class OliGlassPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const OliGlassPanel({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xD90F2238),
            borderRadius: borderRadius,
            border: Border.all(color: OliPalette.hairline),
          ),
          child: child,
        ),
      ),
    );
  }
}

ButtonStyle oliPrimaryButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: OliPalette.blue,
    foregroundColor: Colors.white,
    disabledBackgroundColor: Colors.white12,
    elevation: 0,
    minimumSize: const Size(48, 48),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontFamily: 'CreatoDisplay', fontSize: 16, fontWeight: FontWeight.w700),
  );
}

ButtonStyle oliSecondaryButtonStyle({Color color = Colors.white}) {
  return OutlinedButton.styleFrom(
    foregroundColor: color,
    minimumSize: const Size(48, 48),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    side: BorderSide(color: color == Colors.white ? OliPalette.hairline : color),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontFamily: 'CreatoDisplay', fontSize: 15, fontWeight: FontWeight.w600),
  );
}

/// Champ avec un libellé qui reste visible pendant la saisie.
InputDecoration oliGlassInputDecoration(String label) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: OliPalette.textSecondary, fontSize: 14),
    floatingLabelStyle: const TextStyle(color: OliPalette.blueOnDark, fontSize: 14),
    filled: true,
    fillColor: const Color(0x14FFFFFF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: border(OliPalette.hairline, 1),
    focusedBorder: border(OliPalette.blueOnDark, 1.5),
  );
}

/// Dialogue de confirmation. Renvoie true si l'utilisateur confirme.
Future<bool> showOliConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: OliGlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(color: OliPalette.textSecondary, fontSize: 15, height: 1.4),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: oliSecondaryButtonStyle(),
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: destructive
                        ? OutlinedButton(
                            style: oliSecondaryButtonStyle(color: OliPalette.danger),
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: Text(confirmLabel),
                          )
                        : ElevatedButton(
                            style: oliPrimaryButtonStyle(),
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: Text(confirmLabel),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result == true;
}

const _pressDuration = Duration(milliseconds: 120);
const _pressedScale = 0.92;

/// Réduit légèrement son contenu pendant l'appui.
class OliPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const OliPressable({super.key, required this.child, this.onTap});

  @override
  State<OliPressable> createState() => _OliPressableState();
}

class _OliPressableState extends State<OliPressable> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (widget.onTap != null) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed ? _pressedScale : 1,
        duration: _pressDuration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Surface de verre : flou de l'arrière-plan, teinte, reflet et contour lumineux.
class OliGlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final Color tint;
  final Color borderColor;
  final double reflection;
  final List<BoxShadow> shadows;

  const OliGlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.blur = 18,
    this.tint = const Color(0x40101820),
    this.borderColor = const Color(0x40FFFFFF),
    this.reflection = 0.22,
    this.shadows = const [],
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: tint,
              border: Border.all(color: borderColor),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: reflection),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0, 0.55],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Bouton rond en verre. La version mise en avant est teintée en bleu Oli.
class OliGlassIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  final double iconSize;
  final bool prominent;

  const OliGlassIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = Colors.white,
    this.size = 44,
    this.iconSize = 22,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onPressed != null,
      label: label,
      child: ExcludeSemantics(
        child: OliPressable(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: OliGlassSurface(
              borderRadius: BorderRadius.circular(size / 2),
              tint: prominent ? const Color(0xB31E7DBA) : const Color(0x59101820),
              child: Center(child: Icon(icon, color: color, size: iconSize)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Capsule de verre unique contenant plusieurs actions, avec un seul flou.
class OliGlassGroup extends StatelessWidget {
  final List<OliGlassGroupAction> actions;

  const OliGlassGroup({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return OliGlassSurface(
      borderRadius: BorderRadius.circular(22),
      tint: const Color(0x59101820),
      child: Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
  }
}

/// Action d'un [OliGlassGroup].
class OliGlassGroupAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const OliGlassGroupAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: OliPressable(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
