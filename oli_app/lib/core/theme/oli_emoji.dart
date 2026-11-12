import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Emojis au style Noto (Google) sur tous les appareils : la police Noto Color Emoji
/// sert de police de secours, donc seuls les emojis changent de dessin (le texte garde
/// sa police). Elle est téléchargée une fois puis gardée en cache par google_fonts.
/// Licence : SIL Open Font License 1.1.
class OliEmoji {
  OliEmoji._();

  /// Nom de la police chargée par google_fonts.
  static final String fontFamily = GoogleFonts.notoColorEmoji().fontFamily!;

  /// À placer en police de secours dans les thèmes.
  static List<String> get fallback => [fontFamily];

  /// Lance le téléchargement dès le démarrage, pour qu'elle soit prête au premier emoji.
  static void preload() => GoogleFonts.notoColorEmoji();
}
