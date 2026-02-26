import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../../../config/api_config.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
import 'location_message_bubble.dart';
import 'audio_message_bubble.dart';
import 'reaction_picker.dart';
import 'message_actions.dart';

class ChatMessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String? otherAvatarUrl;
  final String currentUserId;
  final Function(Map<String, dynamic> message)? onSwipeReply;
  final Function(String messageId, String emoji)? onReact;
  final Function(Map<String, dynamic> message)? onForward;
  final Function(String messageId, {required bool forAll})? onDelete;
  final Function(Map<String, dynamic> message)? onEdit;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
    this.otherAvatarUrl,
    this.onSwipeReply,
    this.onReact,
    this.onForward,
    this.onDelete,
    this.onEdit,
  });

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  OverlayEntry? _reactionOverlay;
  double _dragOffset = 0;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _removeReactionOverlay();
    _swipeController.dispose();
    super.dispose();
  }

  // ─── Swipe-to-reply ───────────────────────────────────────────────────────

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // Only allow right-swipe for reply
    final newOffset = (_dragOffset + details.delta.dx).clamp(0.0, 72.0);
    setState(() => _dragOffset = newOffset);

    if (!_hasTriggered && _dragOffset >= 60) {
      _hasTriggered = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset >= 60 && widget.onSwipeReply != null) {
      widget.onSwipeReply!(widget.message);
    }

    // Spring back with animation
    _swipeAnimation = Tween<Offset>(
      begin: Offset(_dragOffset / MediaQuery.of(context).size.width, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.elasticOut));
    _swipeController.forward(from: 0);

    setState(() {
      _dragOffset = 0;
      _hasTriggered = false;
    });
  }

  // ─── Reaction Overlay ─────────────────────────────────────────────────────

  void _showReactionPicker(BuildContext context) {
    _removeReactionOverlay();
    HapticFeedback.heavyImpact();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _reactionOverlay = OverlayEntry(
      builder: (ctx) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _removeReactionOverlay,
          child: Stack(
            children: [
              Positioned(
                top: position.dy - 60,
                left: widget.isMe ? null : position.dx,
                right: widget.isMe
                    ? MediaQuery.of(ctx).size.width - position.dx - size.width
                    : null,
                child: ReactionPicker(
                  position: position,
                  isMe: widget.isMe,
                  onReactionSelected: (emoji) {
                    _removeReactionOverlay();
                    final msgId = widget.message['id']?.toString();
                    if (msgId != null && widget.onReact != null) {
                      widget.onReact!(msgId, emoji);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_reactionOverlay!);
  }

  void _removeReactionOverlay() {
    _reactionOverlay?.remove();
    _reactionOverlay = null;
  }

  // ─── Reactions parsing ────────────────────────────────────────────────────

  Map<String, int> _parseReactions() {
    final raw = widget.message['reactions'];
    if (raw == null) return {};
    try {
      final Map<String, dynamic> decoded =
          raw is String ? jsonDecode(raw) : (raw as Map<String, dynamic>);
      return decoded.map((key, value) => MapEntry(key, (value as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  // ─── Reply-to context helper ──────────────────────────────────────────────

  Widget? _buildReplyContext() {
    final replyContent = widget.message['reply_to_content'];
    final replySender = widget.message['reply_to_sender'];
    if (replyContent == null) return null;

    final isReplySelf = replySender?.toString() == widget.currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withOpacity(0.25)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: widget.isMe ? Colors.white70 : Colors.grey.shade400,
            width: 2.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isReplySelf ? 'Vous' : (widget.message['reply_sender_name'] ?? 'Utilisateur'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: widget.isMe ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyContent.length > 60 ? '${replyContent.substring(0, 60)}…' : replyContent,
            style: TextStyle(
              fontSize: 12,
              color: widget.isMe ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    // ─── Metadata parsing ────────────
    String? mediaUrl;
    String? mediaType;
    Map<String, dynamic>? metaMap;

    if (widget.message['metadata'] != null) {
      try {
        metaMap = widget.message['metadata'] is String
            ? jsonDecode(widget.message['metadata'])
            : widget.message['metadata'];
        mediaUrl = metaMap?['mediaUrl'];
        mediaType = metaMap?['mediaType'];
      } catch (e) { /* ignore */ }
    }

    final bool isLocation = widget.message['type'] == 'location' ||
        (metaMap != null &&
            metaMap.containsKey('lat') &&
            metaMap.containsKey('lng'));

    String timeString = '';
    if (widget.message['created_at'] != null) {
      try {
        final date = DateTime.parse(widget.message['created_at']).toLocal();
        timeString =
            "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
      } catch (e) { /* ignore */ }
    }

    final reactions = _parseReactions();
    final replyContext = _buildReplyContext();

    // ─── The bubble itself ───────────
    final bubble = GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        // Calculer si l'utilisateur peut encore éditer (15 min)
        bool canEdit = false;
        if (widget.message['created_at'] != null) {
          try {
            final sent = DateTime.parse(widget.message['created_at']);
            canEdit = DateTime.now().difference(sent).inMinutes < 15;
          } catch (_) {}
        }
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => MessageContextMenu(
            message: widget.message,
            myId: widget.currentUserId,
            canEdit: canEdit,
            onReply: () {
              if (widget.onSwipeReply != null) widget.onSwipeReply!(widget.message);
            },
            onEdit: () {
              if (widget.onEdit != null) widget.onEdit!(widget.message);
            },
            onDeleteForMe: () {
              final msgId = widget.message['id']?.toString();
              if (msgId != null && widget.onDelete != null) {
                widget.onDelete!(msgId, forAll: false);
              }
            },
            onDeleteForAll: () {
              final msgId = widget.message['id']?.toString();
              if (msgId != null && widget.onDelete != null) {
                widget.onDelete!(msgId, forAll: true);
              }
            },
            onForward: () {
              if (widget.onForward != null) widget.onForward!(widget.message);
            },
            onCopy: () {
              final text = widget.message['content']?.toString() ?? '';
              if (text.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(children: [
                      Icon(Icons.copy, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Message copié'),
                    ]),
                    backgroundColor: Colors.grey.shade800,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
          ),
        );
      },
      onHorizontalDragUpdate: (details) {
        // Only allow swipe for reply
        if (details.delta.dx > 0) _onHorizontalDragUpdate(details);
      },
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: Row(
            mainAxisAlignment:
                widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Reply icon indicator (shown while swiping)
              if (!widget.isMe && _dragOffset > 10)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Opacity(
                    opacity: (_dragOffset / 60).clamp(0.0, 1.0),
                    child: Icon(
                      Icons.reply_rounded,
                      size: 20,
                      color: theme.primaryColor,
                    ),
                  ),
                ),

              // Avatar for Other User
              if (!widget.isMe) ...[
                AutoRefreshAvatar(avatarUrl: widget.otherAvatarUrl, size: 28),
                const SizedBox(width: 8),
              ],

              // Bubble
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: size.width * 0.75),
                  padding: isLocation
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isLocation
                        ? Colors.transparent
                        : (widget.isMe ? theme.primaryColor : Colors.white),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: isLocation
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: isLocation
                      ? LocationMessageBubble(metadata: metaMap!, isMe: widget.isMe)
                      : (mediaType == 'audio' ||
                              (mediaUrl != null && mediaUrl.endsWith('.m4a')))
                          ? AudioMessageBubble(audioUrl: mediaUrl!, isMe: widget.isMe)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── Reply-to context ──
                                if (replyContext != null) replyContext,

                                // ── Image / Media ──
                                if (mediaUrl != null && mediaType != 'audio')
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        mediaUrl.startsWith('http')
                                            ? mediaUrl
                                            : '${ApiConfig.baseUrl}/$mediaUrl',
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          height: 150,
                                          color: Colors.grey[300],
                                          child: const Center(
                                              child: Icon(Icons.broken_image,
                                                  color: Colors.grey)),
                                        ),
                                        loadingBuilder:
                                            (ctx, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            height: 200,
                                            width: double.infinity,
                                            color: Colors.black12,
                                            child: const Center(
                                                child:
                                                    CircularProgressIndicator()),
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                // ── Text Content ──
                                if (widget.message['content'] != null &&
                                    widget.message['content']
                                        .toString()
                                        .isNotEmpty &&
                                    widget.message['content'] != '📷 Image')
                                  Text(
                                    widget.message['content'],
                                    style: TextStyle(
                                      color: widget.isMe
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 15,
                                      height: 1.3,
                                    ),
                                  ),

                                // ── Time + Read ticks ──
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (timeString.isNotEmpty)
                                        Text(
                                          timeString,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: widget.isMe
                                                ? Colors.white.withOpacity(0.7)
                                                : Colors.black38,
                                          ),
                                        ),
                                      if (widget.isMe) ...[
                                        const SizedBox(width: 4),
                                        if (widget.message['id']
                                            .toString()
                                            .startsWith('temp_'))
                                          Icon(Icons.access_time,
                                              size: 12,
                                              color: Colors.white.withOpacity(0.7))
                                        else if (widget.message['is_read'] == true)
                                          const Icon(Icons.done_all,
                                              size: 14,
                                              color: Colors.lightBlueAccent)
                                        else
                                          Icon(Icons.check,
                                              size: 14,
                                              color: Colors.white.withOpacity(0.7)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                ),
              ),

              // Reply icon indicator (right side for "isMe" messages)
              if (widget.isMe && _dragOffset > 10)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Opacity(
                    opacity: (_dragOffset / 60).clamp(0.0, 1.0),
                    child: Icon(
                      Icons.reply_rounded,
                      size: 20,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // ─── Wrap with reaction badge below ──────────────────────────────────────
    return Column(
      crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        if (reactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ReactionBadge(
              reactions: reactions,
              isMe: widget.isMe,
              onTap: (emoji) {
                final msgId = widget.message['id']?.toString();
                if (msgId != null && widget.onReact != null) {
                  widget.onReact!(msgId, emoji);
                }
              },
            ),
          ),
      ],
    );
  }
}
