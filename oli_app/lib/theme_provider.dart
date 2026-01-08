import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _themeKey = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);
      if (savedTheme == 'dark') {
        state = ThemeMode.dark;
      } else {
        state = ThemeMode.light;
      }
    } catch (e) {
      // Fallback to light if error
      state = ThemeMode.light;
    }
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, newMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (e) {
      debugPrint("❌ Erreur sauvegarde thème: $e");
    }
  }
}
