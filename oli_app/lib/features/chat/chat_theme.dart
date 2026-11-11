import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fond choisi pour une discussion. Le choix reste sur ce téléphone, comme sur WhatsApp.
class ChatWallpaper {
  final String key;
  final String label;

  const ChatWallpaper(this.key, this.label);
}

const kChatWallpapers = [
  ChatWallpaper('oli', 'Motif Oli'),
  ChatWallpaper('night', 'Bleu nuit'),
  ChatWallpaper('ocean', 'Dégradé'),
  ChatWallpaper('plain', 'Uni'),
];

const _defaultWallpaper = 'oli';
const _prefsPrefix = 'chat_wallpaper_';

/// Fond de la discussion avec une personne, repéré par son identifiant.
final chatWallpaperProvider =
    StateNotifierProvider.family<ChatWallpaperNotifier, String, String>((ref, otherUserId) => ChatWallpaperNotifier(otherUserId));

class ChatWallpaperNotifier extends StateNotifier<String> {
  final String otherUserId;

  ChatWallpaperNotifier(this.otherUserId) : super(_defaultWallpaper) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('$_prefsPrefix$otherUserId');
      if (mounted && saved != null && kChatWallpapers.any((w) => w.key == saved)) state = saved;
    } catch (_) {
      // Sans stockage local, le fond par défaut reste affiché
    }
  }

  Future<void> select(String key) async {
    state = key;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefsPrefix$otherUserId', key);
    } catch (_) {}
  }
}

/// Décor du fond, adapté au mode clair ou sombre.
BoxDecoration chatWallpaperDecoration(String key, {required bool isDark}) {
  switch (key) {
    case 'night':
      return const BoxDecoration(
        color: Color(0xFF051941),
        image: DecorationImage(
          image: AssetImage('assets/images/oticket_bg.png'),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      );
    case 'ocean':
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF0B2545), Color(0xFF040B16)]
              : const [Color(0xFFDCEBFA), Color(0xFFF7FAFD)],
        ),
      );
    case 'plain':
      return BoxDecoration(color: isDark ? const Color(0xFF0E1116) : const Color(0xFFF1F3F6));
    default:
      // Chaque mode a son image : un fond clair assombri donnerait un gris terne
      return BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        image: DecorationImage(
          image: AssetImage(isDark ? 'assets/images/chat_bg_new.png' : 'assets/images/bgd.jpg'),
          fit: BoxFit.cover,
          opacity: isDark ? 0.7 : 0.4,
        ),
      );
  }
}

/// Choix du fond, avec un aperçu de chaque proposition.
Future<void> showChatWallpaperPicker(BuildContext context, WidgetRef ref, String otherUserId) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final current = ref.watch(chatWallpaperProvider(otherUserId));
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thème de la discussion', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Visible seulement sur ce téléphone', style: TextStyle(fontSize: 12, color: Theme.of(ctx).hintColor)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (final wallpaper in kChatWallpapers)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => ref.read(chatWallpaperProvider(otherUserId).notifier).select(wallpaper.key),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                AspectRatio(
                                  aspectRatio: 0.56,
                                  child: Container(
                                    decoration: chatWallpaperDecoration(wallpaper.key, isDark: isDark).copyWith(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: current == wallpaper.key ? Theme.of(ctx).primaryColor : Colors.transparent,
                                        width: 2.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: current == wallpaper.key
                                        ? Icon(Icons.check_circle, color: Theme.of(ctx).primaryColor, size: 28)
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(wallpaper.label, style: const TextStyle(fontSize: 12.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
