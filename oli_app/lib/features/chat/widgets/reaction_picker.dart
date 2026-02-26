import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Les 6 réactions rapides disponibles
const List<String> kDefaultReactions = ['❤️', '😂', '👍', '😢', '😮', '🔥'];

/// Affiche un sélecteur de réactions en popup (arc d'emojis)
class ReactionPicker extends StatefulWidget {
  final Offset position;
  final bool isMe;
  final Function(String emoji) onReactionSelected;

  const ReactionPicker({
    super.key,
    required this.position,
    required this.isMe,
    required this.onReactionSelected,
  });

  @override
  State<ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<ReactionPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      alignment: widget.isMe ? Alignment.bottomRight : Alignment.bottomLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: kDefaultReactions.map((emoji) {
            return _ReactionItem(
              emoji: emoji,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onReactionSelected(emoji);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ReactionItem extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionItem({required this.emoji, required this.onTap});

  @override
  State<_ReactionItem> createState() => _ReactionItemState();
}

class _ReactionItemState extends State<_ReactionItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _hoverAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _hoverController.forward(),
      onTapUp: (_) {
        _hoverController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _hoverController.reverse(),
      child: ScaleTransition(
        scale: _hoverAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 26)),
        ),
      ),
    );
  }
}

/// Badge de réaction affiché sous une bulle
class ReactionBadge extends StatelessWidget {
  final Map<String, int> reactions; // {'❤️': 2, '👍': 1}
  final bool isMe;
  final Function(String emoji) onTap;

  const ReactionBadge({
    super.key,
    required this.reactions,
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          top: 2,
          left: isMe ? 0 : 36,
          right: isMe ? 8 : 0,
        ),
        child: Wrap(
          spacing: 4,
          children: reactions.entries.map((entry) {
            return GestureDetector(
              onTap: () => onTap(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 13)),
                    if (entry.value > 1) ...[
                      const SizedBox(width: 2),
                      Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
