import 'package:oli_app/core/widgets/oli_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/video_sale_model.dart';
import '../providers/video_feed_provider.dart';

const _pickerHeight = 240.0;

const _emojiCategories = <String, List<String>>{
  'Visages': [
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊',
    '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😋', '😛', '😜', '🤪', '😝',
    '🤗', '🤭', '🤫', '🤔', '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄',
    '😬', '😌', '😔', '😪', '😴', '😷', '🤒', '🤕', '🤢', '🤧', '🥵', '🥶',
    '😵', '🤯', '🤠', '🥳', '😎', '🤓', '🧐', '😕', '😟', '🙁', '😮', '😯',
    '😲', '😳', '🥺', '😦', '😧', '😨', '😰', '😥', '😢', '😭', '😱', '😖',
    '😣', '😞', '😓', '😩', '😫', '🥱', '😤', '😡', '😠', '🤬', '😈', '💀',
  ],
  'Gestes': [
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '👇',
    '☝️', '✋', '🤚', '🖐️', '🖖', '👋', '🤝', '🙏', '👏', '🙌', '👐', '🤲',
    '💪', '🦾', '✍️', '💅', '🤳', '👀', '🧠', '💋',
  ],
  'Cœurs': [
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️', '💕',
    '💞', '💓', '💗', '💖', '💘', '💝', '💟', '🔥', '✨', '⭐', '🌟', '💯',
  ],
  'Achats': [
    '🛍️', '🛒', '💰', '💵', '💸', '💳', '🏷️', '🎁', '📦', '🚚', '🛵', '🏍️',
    '👗', '👕', '👖', '👟', '👠', '👜', '🕶️', '💍', '⌚', '📱', '💻', '🎧',
    '🏠', '🚗', '🍽️', '🍲', '🍗', '🥤', '🍺', '☕',
  ],
  'Fête': [
    '🎉', '🎊', '🎈', '🎂', '🥂', '🍾', '🏆', '🥇', '⚽', '🏀', '🎵', '🎶',
    '🎤', '💃', '🕺', '🇨🇩', '🌍', '☀️', '🌙', '🌈', '⚡', '💥', '🙈', '🐆',
  ],
};

/// Galerie d'emojis et de stickers du champ de commentaire.
class CommentMediaPicker extends ConsumerWidget {
  final ValueChanged<String> onEmoji;
  final ValueChanged<CommentSticker> onSticker;
  final Color accent;
  final Color text;
  final Color muted;

  const CommentMediaPicker({
    super.key,
    required this.onEmoji,
    required this.onSticker,
    required this.accent,
    required this.text,
    required this.muted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: _pickerHeight,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              labelColor: accent,
              unselectedLabelColor: muted,
              indicatorColor: accent,
              tabs: const [Tab(text: 'Emojis', height: 36), Tab(text: 'Stickers', height: 36)],
            ),
            Expanded(
              child: TabBarView(
                children: [_buildEmojis(), _buildStickers(ref)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Text(
          title,
          style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmojis() {
    return CustomScrollView(
      slivers: [
        for (final category in _emojiCategories.entries) ...[
          _buildSectionTitle(category.key),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
              itemCount: category.value.length,
              itemBuilder: (context, index) {
                final emoji = category.value[index];
                return InkWell(
                  onTap: () => onEmoji(emoji),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStickers(WidgetRef ref) {
    return ref.watch(commentStickersProvider).when(
      loading: () => Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2)),
      error: (_, __) => Center(
        child: TextButton.icon(
          onPressed: () => ref.invalidate(commentStickersProvider),
          icon: Icon(Icons.refresh, color: accent),
          label: Text('Réessayer', style: TextStyle(color: accent)),
        ),
      ),
      data: (stickers) {
        if (stickers.isEmpty) {
          return Center(child: Text('Aucun sticker disponible', style: TextStyle(color: muted)));
        }
        final packs = <String, List<CommentSticker>>{};
        for (final sticker in stickers) {
          packs.putIfAbsent(sticker.pack, () => []).add(sticker);
        }
        return CustomScrollView(
          slivers: [
            for (final pack in packs.entries) ...[
              _buildSectionTitle(pack.key),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                  itemCount: pack.value.length,
                  itemBuilder: (context, index) => _buildSticker(pack.value[index]),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSticker(CommentSticker sticker) {
    return Semantics(
      button: true,
      label: 'Sticker ${sticker.name}',
      child: InkWell(
        onTap: () => onSticker(sticker),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: OliImage.network(
            sticker.imageUrl,
            fit: BoxFit.contain,
            cacheWidth: 180,
            errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: muted),
          ),
        ),
      ),
    );
  }
}
