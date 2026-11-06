import 'package:flutter/material.dart';

/// Couleur du prix affiché sur les cartes produit.
///
/// Thème clair : rouge, pour rester lisible sur fond blanc.
/// Thème sombre : bleu clair, inchangé.
Color productPriceColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF64B5F6) // bleu clair
      : const Color(0xFFD32F2F); // rouge
}
