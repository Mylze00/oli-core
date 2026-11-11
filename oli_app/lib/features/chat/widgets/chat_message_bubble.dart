import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../../config/api_config.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
import 'location_message_bubble.dart';
import 'audio_message_bubble.dart';
import 'reaction_picker.dart';
import 'cash_note_bubble.dart';
import '../../../core/theme/oli_colors.dart';
import 'chat_image_viewer.dart';
import 'progressive_chat_image.dart';
import 'conversation_context_menu.dart';
import '../chat_controller.dart';
import '../../../core/theme/oli_glass.dart';

/// Retrait du menu sous la bulle : à droite pour mes messages, après l'avatar sinon.
const _menuInsetMine = 8.0;
const _menuInsetOther = 44.0;

class ChatMessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String? otherAvatarUrl;
  final String? myAvatarUrl;
  final String currentUserId;
  final Function(Map<String, dynamic> message)? onSwipeReply;
  final Function(String messageId, String emoji)? onReact;
  final Function(Map<String, dynamic> message)? onForward;
  final Function(String messageId, {required bool forAll})? onDelete;
  final Function(Map<String, dynamic> message)? onEdit;
  final void Function(String messageId)? onVoicePlayed;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
    this.otherAvatarUrl,
    this.myAvatarUrl,
    this.onSwipeReply,
    this.onReact,
    this.onForward,
    this.onDelete,
    this.onEdit,
    this.onVoicePlayed,
  });

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  final GlobalKey _rowKey = GlobalKey();
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

  // ─── Menu du message (appui long) ─────────────────────────────────────────

  Duration? _messageAge() {
    final createdAt = DateTime.tryParse(widget.message['created_at']?.toString() ?? '');
    return createdAt == null ? null : DateTime.now().difference(createdAt);
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.message['content']?.toString() ?? ''));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Message copié'), duration: Duration(seconds: 1)));
  }

  void _openMessageMenu(
    Widget preview, {
    required bool isDeleted,
    required bool isPlainText,
    required bool isCash,
  }) {
    final box = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final id = widget.message['id']?.toString();
    final isSent = isServerMessageId(id);
    final isLive = isSent && !isDeleted;
    final age = _messageAge();
    final content = widget.message['content']?.toString() ?? '';
    final isTextType = (widget.message['type'] ?? 'text') == 'text';
    final canEdit = widget.isMe && isLive && isPlainText && isTextType && age != null && age < kMessageEditWindow;
    final canDeleteForAll = widget.isMe && isLive && !isCash && age != null && age < kMessageDeleteForAllWindow;

    final items = [
      if (isLive && widget.onSwipeReply != null)
        ConversationMenuItem(
          icon: Icons.reply_rounded,
          label: 'Répondre',
          onTap: () => widget.onSwipeReply!(widget.message),
        ),
      if (!isDeleted && isPlainText && content.isNotEmpty)
        ConversationMenuItem(icon: Icons.copy_rounded, label: 'Copier', onTap: _copyText),
      if (isLive && !isCash && widget.onForward != null)
        ConversationMenuItem(
          icon: Icons.forward_rounded,
          label: 'Transférer',
          onTap: () => widget.onForward!(widget.message),
        ),
      if (canEdit && widget.onEdit != null)
        ConversationMenuItem(
          icon: Icons.edit_outlined,
          label: 'Modifier',
          onTap: () => widget.onEdit!(widget.message),
        ),
      if (isSent && widget.onDelete != null)
        ConversationMenuItem(
          icon: Icons.delete_outline_rounded,
          label: 'Supprimer pour moi',
          isDanger: true,
          onTap: () => widget.onDelete!(id!, forAll: false),
        ),
      if (canDeleteForAll && widget.onDelete != null)
        ConversationMenuItem(
          icon: Icons.delete_forever_outlined,
          label: 'Supprimer pour tous',
          isDanger: true,
          onTap: () => widget.onDelete!(id!, forAll: true),
        ),
    ];
    if (items.isEmpty) return;

    HapticFeedback.mediumImpact();
    showConversationContextMenu(
      context: context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      preview: preview,
      items: items,
      keepAnchorPosition: true,
      alignEnd: widget.isMe,
      menuInset: widget.isMe ? _menuInsetMine : _menuInsetOther,
      header: isLive && widget.onReact != null
          ? (close) => _ReactionBar(
                onSelected: (emoji) {
                  close();
                  widget.onReact!(id!, emoji);
                },
              )
          : null,
    );
  }

  Widget _buildForwardedLabel(Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forward_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text('Transféré', style: TextStyle(fontSize: 12, color: color, fontStyle: FontStyle.italic)),
        ],
      ),
    );
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

  // ─── Time + read ticks ────────────────────────────────────────────────────

  Widget _buildReadTicks(Color color, {required bool onBlueBubble}) {
    final ticks = Icon(Icons.done_all, size: onBlueBubble ? 12 : 14, color: color);
    if (!onBlueBubble) return ticks;
    // Des coches bleues resteraient invisibles sur la bulle bleue
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: ticks,
    );
  }

  Widget _buildTimeRow(
    String timeString, {
    required Color color,
    required Color readColor,
    bool readOnBlueBubble = false,
    bool compact = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: compact ? 0 : 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.message['edited_at'] != null && widget.message['deleted_at'] == null)
            Text('modifié  ', style: TextStyle(fontSize: 10, color: color, fontStyle: FontStyle.italic)),
          if (timeString.isNotEmpty)
            Text(timeString, style: TextStyle(fontSize: 10, color: color)),
          if (widget.isMe) ...[
            const SizedBox(width: 4),
            if (widget.message['id'].toString().startsWith('temp_'))
              Icon(Icons.access_time, size: 12, color: color)
            else if (widget.message['is_read'] == true)
              _buildReadTicks(readColor, onBlueBubble: readOnBlueBubble)
            else if (widget.message['delivered_at'] != null)
              Icon(Icons.done_all, size: 14, color: color)
            else
              Icon(Icons.check, size: 14, color: color),
          ],
        ],
      ),
    );
  }

  /// Le commentaire du transfert suit le montant dans le texte du message.
  String? _cashNote() {
    const marker = '\nNote: ';
    final content = widget.message['content']?.toString() ?? '';
    final index = content.indexOf(marker);
    return index < 0 ? null : content.substring(index + marker.length);
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
    final isDark = theme.brightness == Brightness.dark;

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

    final isDeleted = widget.message['deleted_at'] != null || metaMap?['deleted'] == true;
    if (isDeleted) {
      metaMap = null;
      mediaUrl = null;
      mediaType = null;
    }
    final isForwarded = metaMap?['forwarded'] == true;

    final bool isLocation = !isDeleted && widget.message['type'] == 'location' ||
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

    final cashTransfer = metaMap?['cash_transfer'];
    final cashAmount = cashTransfer is Map ? num.tryParse('${cashTransfer['amount_fc']}') : null;
    final localImage = isDeleted ? null : widget.message['local_image'] as Uint8List?;
    final messageContent = widget.message['content']?.toString() ?? '';
    // Une image sans légende s'affiche seule, sans bulle autour
    final isImageOnly = localImage != null ||
        (mediaUrl != null &&
            mediaType != 'audio' &&
            !mediaUrl.endsWith('.m4a') &&
            (messageContent.isEmpty || messageContent == '📷 Image'));
    final isCardMessage = isLocation || cashAmount != null || isImageOnly;
    final isVoice = widget.message['local_audio'] == true ||
        mediaType == 'audio' ||
        (mediaUrl != null && mediaUrl.endsWith('.m4a'));
    final waveform = (metaMap?['waveform'] as List?)?.map((v) => (v as num).toInt()).toList();

    final isPlainText = !isLocation && cashAmount == null && !isVoice && mediaUrl == null && localImage == null;

    final reactions = _parseReactions();
    final replyContext = _buildReplyContext();

    // ─── La ligne du message (bulle + avatar), reprise telle quelle dans le menu ───
    final row = Padding(
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

              // Avatar for Other User (un vocal porte déjà la photo dans sa bande)
              if (!widget.isMe) ...[
                if (isVoice)
                  const SizedBox(width: 28)
                else
                  AutoRefreshAvatar(avatarUrl: widget.otherAvatarUrl, size: 28),
                const SizedBox(width: 8),
              ],

              // Bubble
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: size.width * 0.75),
                  padding: isCardMessage
                      ? EdgeInsets.zero
                      : isVoice
                      ? const EdgeInsets.fromLTRB(8, 6, 10, 4)
                      : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCardMessage
                        ? Colors.transparent
                        : (widget.isMe ? theme.primaryColor : (isDark ? OliChatDarkColors.receivedBubble : Colors.white)),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: isCardMessage
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
                      : widget.message['local_audio'] == true
                          ? AudioUploadingBubble(
                              progress: (widget.message['upload_progress'] as num?)?.toDouble() ?? 0,
                              durationMs: (widget.message['duration_ms'] as num?)?.toInt() ?? 0,
                              isMe: widget.isMe,
                            )
                      : cashAmount != null
                          ? CashNoteBubble(
                              amountFc: cashAmount,
                              isMe: widget.isMe,
                              note: _cashNote(),
                              noteTextColor: isDark ? Colors.white : Colors.black87,
                              footer: _buildTimeRow(
                                timeString,
                                color: isDark ? Colors.white70 : Colors.black54,
                                readColor: theme.primaryColor,
                              ),
                            )
                      : (mediaType == 'audio' ||
                              (mediaUrl != null && mediaUrl.endsWith('.m4a')))
                          ? AudioMessageBubble(
                              audioUrl: mediaUrl!,
                              isMe: widget.isMe,
                              durationMs: (metaMap?['duration_ms'] as num?)?.toInt(),
                              waveform: waveform,
                              isPlayed: widget.message['played_at'] != null,
                              onFirstPlay: () => widget.onVoicePlayed?.call(widget.message['id'].toString()),
                              avatarUrl: widget.isMe ? widget.myAvatarUrl : widget.otherAvatarUrl,
                              footer: _buildTimeRow(
                                timeString,
                                color: widget.isMe || isDark ? Colors.white.withOpacity(0.7) : Colors.black38,
                                readColor: theme.primaryColor,
                                readOnBlueBubble: widget.isMe,
                                compact: true,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: isImageOnly && widget.isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── Image en cours d'envoi ──
                                if (localImage != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: UploadingChatImage(
                                      bytes: localImage,
                                      progress: (widget.message['upload_progress'] as num?)?.toDouble() ?? 0,
                                    ),
                                  ),

                                if (isForwarded)
                                  _buildForwardedLabel(
                                    isImageOnly
                                        ? (isDark ? Colors.white70 : Colors.black54)
                                        : (widget.isMe || isDark ? Colors.white70 : Colors.black54),
                                  ),

                                // ── Reply-to context ──
                                if (replyContext != null) replyContext,

                                // ── Image / Media ──
                                if (mediaUrl != null && mediaType != 'audio')
                                  Padding(
                                    padding: EdgeInsets.only(bottom: isImageOnly ? 0 : 6.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: GestureDetector(
                                      onTap: () {
                                        final url = mediaUrl!;
                                        Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => ChatImageViewer(
                                            imageUrl: url.startsWith('http') ? url : '${ApiConfig.baseUrl}/$url',
                                          ),
                                        ));
                                      },
                                      child: ProgressiveChatImage(
                                        url: mediaUrl.startsWith('http')
                                            ? mediaUrl
                                            : '${ApiConfig.baseUrl}/$mediaUrl',
                                      ),
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
                                      color: (widget.isMe || isDark ? Colors.white : Colors.black87)
                                          .withValues(alpha: isDeleted ? 0.7 : 1),
                                      fontSize: 15,
                                      height: 1.3,
                                      fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),

                                // ── Time + Read ticks ──
                                _buildTimeRow(
                                  timeString,
                                  color: isImageOnly
                                      ? (isDark ? Colors.white70 : Colors.black54)
                                      : (widget.isMe && isDark
                                          ? Colors.white.withOpacity(0.9)
                                          : (widget.isMe || isDark
                                              ? Colors.white.withOpacity(0.7)
                                              : Colors.black38)),
                                  readColor: theme.primaryColor,
                                  readOnBlueBubble: !isImageOnly,
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
        );

    final bubble = GestureDetector(
      onLongPress: () => _openMessageMenu(
        row,
        isDeleted: isDeleted,
        isPlainText: isPlainText,
        isCash: cashAmount != null,
      ),
      onHorizontalDragUpdate: (details) {
        // Seul le glissement vers la droite déclenche la réponse
        if (details.delta.dx > 0) _onHorizontalDragUpdate(details);
      },
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: KeyedSubtree(key: _rowKey, child: row),
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

/// Barre de réactions rapides, dans le même verre que le menu.
class _ReactionBar extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _ReactionBar({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OliGlassSurface(
      borderRadius: BorderRadius.circular(26),
      blur: 24,
      tint: isDark ? const Color(0xB3242428) : const Color(0xD9F4F7FB),
      borderColor: isDark ? const Color(0x33FFFFFF) : const Color(0x591E7DBA),
      reflection: isDark ? 0.12 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in kDefaultReactions)
              Semantics(
                button: true,
                label: 'Réagir $emoji',
                child: InkResponse(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(emoji);
                  },
                  radius: 24,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Text(emoji, style: const TextStyle(fontSize: 27)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
