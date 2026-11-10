import 'package:flutter/material.dart';

/// Couleurs du mode clair, partagées entre les écrans.
class OliLightColors {
  OliLightColors._();

  static const Color background = Color(0xFFF5F6F8);
  static const Color surface = Colors.white;

  /// Texte secondaire : contraste d'au moins 4,5:1 sur le fond et les cartes.
  static const Color textSecondary = Color(0xFF5F6673);
}

/// Espace à réserver en fin de page pour que le contenu reste accessible
/// au-dessus du menu flottant du bas.
double bottomNavClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 24;
