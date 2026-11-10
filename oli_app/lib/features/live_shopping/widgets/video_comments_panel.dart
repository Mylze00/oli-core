import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/router/network/dio_provider.dart';
import '../../../core/theme/oli_glass.dart';
import '../../../core/user/user_provider.dart';
import '../../../utils/cloudinary_helper.dart';
import '../models/video_sale_model.dart';
import '../providers/video_feed_provider.dart';

const _commentsPageSize = 20;
const _likeValue = 1;
const _dislikeValue = -1;
const _noReaction = 0;
const _quickEmojis = [
  '😀', '😂', '🤣', '😍', '🥰', '😘', '😎', '🤩', '😢', '😭', '😡', '🥳',
  '😅', '😊', '😉', '🤔', '🙄', '😴', '😱', '🤝', '👍', '👎', '👏', '🙏',
  '💪', '✌️', '🔥', '❤️', '💙', '💯', '🎉', '✨', '💰', '🛍️', '🇨🇩', '⭐',
];

/// Couleurs du panneau selon le mode clair ou sombre.
class _PanelColors {
  final Color background;
  final Color field;
  final Color text;
  final Color muted;
  final Color faint;
  final Color divider;
  final Color accent;

  factory _PanelColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final text = theme.colorScheme.onSurface;
    return _PanelColors._(
      background: isDark ? const Color(0xFF14141F) : Colors.white,
      field: isDark ? const Color(0xFF26263A) : const Color(0xFFF1F2F4),
      text: text,
      muted: text.withOpacity(0.6),
      faint: text.withOpacity(0.4),
      divider: text.withOpacity(0.1),
      accent: isDark ? OliPalette.blueOnDark : OliPalette.blue,
    );
  }

  const _PanelColors._({
    required this.background,
    required this.field,
    required this.text,
    required this.muted,
    required this.faint,
    required this.divider,
    required this.accent,
  });
}

/// Panneau de commentaires affiché sous la vidéo réduite.
class VideoCommentsPanel extends ConsumerStatefulWidget {
  final VideoSale video;
  final VoidCallback onClose;

  const VideoCommentsPanel({super.key, required this.video, required this.onClose});

  @override
  ConsumerState<VideoCommentsPanel> createState() => _VideoCommentsPanelState();
}

class _VideoCommentsPanelState extends ConsumerState<VideoCommentsPanel> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  final List<VideoComment> _comments = [];
  final Map<String, List<VideoComment>> _replies = {};
  final Set<String> _expanded = {};
  final Set<String> _loadingReplies = {};

  bool _isLoading = true;
  bool _hasError = false;
  bool _hasMore = false;
  bool _isSending = false;
  bool _showEmojis = false;
  int _page = 0;
  String _sort = 'recent';
  VideoComment? _replyTarget;
  Uint8List? _imageBytes;
  String? _imageName;

  String get _commentsPath => '/api/videos/${widget.video.id}/comments';

  String? get _currentUserId => ref.read(userProvider).value?.id.toString();

  bool get _isVideoOwner => _currentUserId == widget.video.sellerId;

  bool get _canSend =>
      !_isSending && (_inputController.text.trim().isNotEmpty || _imageBytes != null);

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_refreshSendButton);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _refreshSendButton() => setState(() {});

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _loadFirstPage() async {
    _page = 0;
    _comments.clear();
    _replies.clear();
    _expanded.clear();
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final nextPage = _page + 1;
      final response = await ref.read(dioProvider).get(
        _commentsPath,
        queryParameters: {'page': nextPage, 'limit': _commentsPageSize, 'sort': _sort},
      );
      final data = (response.data['comments'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _comments.addAll(data.map(VideoComment.fromJson));
        _page = nextPage;
        _hasMore = data.length >= _commentsPageSize;
        _isLoading = false;
      });
    } on DioException {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _toggleReplies(VideoComment comment) async {
    if (_expanded.contains(comment.id)) {
      setState(() => _expanded.remove(comment.id));
      return;
    }
    setState(() {
      _expanded.add(comment.id);
      _loadingReplies.add(comment.id);
    });

    try {
      final response = await ref.read(dioProvider).get('$_commentsPath/${comment.id}/replies');
      final data = (response.data['replies'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _replies[comment.id] = data.map(VideoComment.fromJson).toList();
      });
    } on DioException {
      _showError('Impossible de charger les réponses');
      if (mounted) setState(() => _expanded.remove(comment.id));
    } finally {
      if (mounted) setState(() => _loadingReplies.remove(comment.id));
    }
  }

  void _replaceComment(VideoComment updated) {
    setState(() {
      final index = _comments.indexWhere((c) => c.id == updated.id);
      if (index != -1) _comments[index] = updated;
      final replies = _replies[updated.parentId];
      final replyIndex = replies?.indexWhere((c) => c.id == updated.id) ?? -1;
      if (replyIndex != -1) replies![replyIndex] = updated;
    });
  }

  /// Un second appui sur la même réaction la retire.
  Future<void> _react(VideoComment comment, int tapped) async {
    final value = comment.myReaction == tapped ? _noReaction : tapped;
    _replaceComment(comment.withReaction(value, viewerIsCreator: _isVideoOwner));

    try {
      await ref.read(dioProvider).post(
        '$_commentsPath/${comment.id}/react',
        data: {'value': value},
      );
    } on DioException {
      _replaceComment(comment);
      _showError('Impossible d\'enregistrer votre réaction');
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1080,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) {
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
      });
    }
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
    });
  }

  void _insertAtCursor(String text) {
    final value = _inputController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    _inputController.value = TextEditingValue(
      text: value.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  void _startReply(VideoComment comment) {
    final isReplyToReply = comment.parentId != null;
    setState(() {
      _replyTarget = comment;
      _showEmojis = false;
    });
    _inputController.text = isReplyToReply ? '@${comment.userName} ' : '';
    _inputController.selection = TextSelection.collapsed(offset: _inputController.text.length);
    _inputFocus.requestFocus();
  }

  /// Propose les personnes présentes dans la conversation.
  Future<void> _showMentions(_PanelColors colors) async {
    final names = <String>{
      widget.video.sellerName,
      for (final comment in _comments) comment.userName,
      for (final replies in _replies.values)
        for (final reply in replies) reply.userName,
    }.toList();

    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.background,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final person in names)
              ListTile(
                leading: Icon(Icons.alternate_email, color: colors.accent),
                title: Text(person, style: TextStyle(color: colors.text)),
                onTap: () => Navigator.pop(context, person),
              ),
          ],
        ),
      ),
    );
    if (name != null) {
      _insertAtCursor('@$name ');
      _inputFocus.requestFocus();
    }
  }

  Future<void> _send() async {
    if (!_canSend) return;
    final content = _inputController.text.trim();
    final image = _imageBytes;
    final parentId = _replyTarget?.id;

    setState(() => _isSending = true);
    try {
      final Object body = image != null
          ? FormData.fromMap({
              'content': content,
              if (parentId != null) 'parent_id': parentId,
              'image': MultipartFile.fromBytes(image, filename: _imageName ?? 'image.jpg'),
            })
          : {
              'content': content,
              if (parentId != null) 'parent_id': parentId,
            };

      final response = await ref.read(dioProvider).post(_commentsPath, data: body);
      final comment = VideoComment.fromJson(response.data['comment'] as Map<String, dynamic>);
      ref.read(videoFeedProvider.notifier).adjustCommentsCount(widget.video.id, 1);
      if (!mounted) return;

      _inputController.clear();
      _inputFocus.unfocus();
      setState(() {
        _addToList(comment);
        _replyTarget = null;
        _imageBytes = null;
        _imageName = null;
        _showEmojis = false;
      });
    } on DioException {
      _showError("Impossible d'envoyer le commentaire");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _addToList(VideoComment comment) {
    final parentId = comment.parentId;
    if (parentId == null) {
      _comments.insert(0, comment);
      return;
    }
    _replies.putIfAbsent(parentId, () => []).add(comment);
    _expanded.add(parentId);
    final index = _comments.indexWhere((c) => c.id == parentId);
    if (index != -1) {
      _comments[index] = _comments[index].copyWith(repliesCount: _comments[index].repliesCount + 1);
    }
  }

  Future<void> _delete(VideoComment comment) async {
    try {
      final response = await ref.read(dioProvider).delete('$_commentsPath/${comment.id}');
      final deleted = response.data['deleted'] as int? ?? 1;
      ref.read(videoFeedProvider.notifier).adjustCommentsCount(widget.video.id, -deleted);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
        _replies.remove(comment.id);
        final parentId = comment.parentId;
        if (parentId != null) {
          _replies[parentId]?.removeWhere((c) => c.id == comment.id);
          final index = _comments.indexWhere((c) => c.id == parentId);
          if (index != -1) {
            _comments[index] = _comments[index].copyWith(
              repliesCount: _comments[index].repliesCount - 1,
            );
          }
        }
      });
    } on DioException {
      _showError('Impossible de supprimer le commentaire');
    }
  }

  void _showCommentActions(VideoComment comment, _PanelColors colors) {
    if (!_isVideoOwner && comment.userId != _currentUserId) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.background,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
          title: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
          onTap: () {
            Navigator.pop(context);
            _delete(comment);
          },
        ),
      ),
    );
  }

  String _formatAge(DateTime date) {
    final age = DateTime.now().difference(date);
    if (age.inMinutes < 1) return "à l'instant";
    if (age.inHours < 1) return '${age.inMinutes} min';
    if (age.inDays < 1) return '${age.inHours} h';
    if (age.inDays < 7) return '${age.inDays} j';
    if (age.inDays < 365) return '${age.inDays ~/ 7} sem';
    return '${age.inDays ~/ 365} an';
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)} M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)} k';
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PanelColors.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Material(
        color: colors.background,
        child: Column(
          children: [
            _buildHeader(colors),
            Expanded(child: _buildList(colors)),
            Divider(height: 1, color: colors.divider),
            SafeArea(top: false, child: _buildComposer(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_PanelColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    '${_formatCount(widget.video.commentsCount)} commentaires',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.text, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Trier les commentaires',
                  icon: Icon(Icons.sort, color: colors.muted, size: 20),
                  initialValue: _sort,
                  onSelected: (value) {
                    _sort = value;
                    _loadFirstPage();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'recent', child: Text('Les plus récents')),
                    PopupMenuItem(value: 'top', child: Text('Les plus aimés')),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Fermer les commentaires',
            onPressed: widget.onClose,
            icon: Icon(Icons.close, color: colors.text, size: 20),
            style: IconButton.styleFrom(backgroundColor: colors.field),
          ),
        ],
      ),
    );
  }

  Widget _buildList(_PanelColors colors) {
    if (_isLoading && _comments.isEmpty) {
      return Center(child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2));
    }
    if (_hasError && _comments.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadNextPage,
          icon: Icon(Icons.refresh, color: colors.accent),
          label: Text('Réessayer', style: TextStyle(color: colors.accent)),
        ),
      );
    }
    if (_comments.isEmpty) {
      return Center(
        child: Text('Soyez le premier à commenter', style: TextStyle(color: colors.muted)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _comments.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _comments.length) {
          return TextButton(
            onPressed: _isLoading ? null : _loadNextPage,
            child: Text(
              _isLoading ? 'Chargement...' : 'Voir plus',
              style: TextStyle(color: colors.accent),
            ),
          );
        }
        final comment = _comments[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildComment(comment, colors),
            if (comment.repliesCount > 0) _buildRepliesSection(comment, colors),
          ],
        );
      },
    );
  }

  Widget _buildRepliesSection(VideoComment comment, _PanelColors colors) {
    final isExpanded = _expanded.contains(comment.id);
    final replies = _replies[comment.id] ?? const <VideoComment>[];
    final label = isExpanded
        ? 'Masquer les réponses'
        : 'Afficher ${comment.repliesCount} réponse${comment.repliesCount > 1 ? 's' : ''}';

    return Padding(
      padding: const EdgeInsets.only(left: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isExpanded)
            for (final reply in replies) _buildComment(reply, colors, isReply: true),
          if (_loadingReplies.contains(comment.id))
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2),
              ),
            ),
          TextButton.icon(
            onPressed: () => _toggleReplies(comment),
            icon: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: colors.muted,
              size: 18,
            ),
            label: Text(label, style: TextStyle(color: colors.muted, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? url, double size, _PanelColors colors) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colors.field,
      backgroundImage: url != null ? NetworkImage(CloudinaryHelper.xsmall(url)) : null,
      child: url == null ? Icon(Icons.person, color: colors.muted, size: size * 0.6) : null,
    );
  }

  /// Met en évidence les mentions dans le texte du commentaire.
  Widget _buildContent(String content, _PanelColors colors) {
    final spans = <TextSpan>[];
    content.splitMapJoin(
      RegExp(r'@[^\s@]+'),
      onMatch: (match) {
        spans.add(TextSpan(
          text: match[0],
          style: TextStyle(color: colors.accent, fontWeight: FontWeight.w600),
        ));
        return '';
      },
      onNonMatch: (text) {
        spans.add(TextSpan(text: text));
        return '';
      },
    );
    return Text.rich(TextSpan(
      style: TextStyle(color: colors.text, fontSize: 15, height: 1.3),
      children: spans,
    ));
  }

  Widget _buildComment(VideoComment comment, _PanelColors colors, {bool isReply = false}) {
    return InkWell(
      onLongPress: () => _showCommentActions(comment, colors),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(comment.userAvatar, isReply ? 26 : 34, colors),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(
                    style: TextStyle(color: colors.muted, fontSize: 13),
                    children: [
                      TextSpan(text: comment.userName),
                      if (comment.isCreator) ...[
                        const TextSpan(text: ' · '),
                        TextSpan(text: 'Créateur', style: TextStyle(color: colors.accent)),
                      ],
                    ],
                  )),
                  const SizedBox(height: 2),
                  if (comment.content.isNotEmpty) _buildContent(comment.content, colors),
                  if (comment.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          CloudinaryHelper.medium(comment.imageUrl!),
                          width: 160,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  _buildCommentActions(comment, colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentActions(VideoComment comment, _PanelColors colors) {
    final isLiked = comment.myReaction == _likeValue;
    final isDisliked = comment.myReaction == _dislikeValue;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  _formatAge(comment.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.faint, fontSize: 12),
                ),
              ),
              Flexible(
                flex: 2,
                child: TextButton(
                  onPressed: () => _startReply(comment),
                  child: Text(
                    'Répondre',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.muted, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (comment.creatorLiked) _buildCreatorLike(colors),
            ],
          ),
        ),
        IconButton(
          tooltip: "J'aime",
          visualDensity: VisualDensity.compact,
          onPressed: () => _react(comment, _likeValue),
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.redAccent : colors.muted,
            size: 20,
          ),
        ),
        if (comment.likesCount > 0)
          Text(_formatCount(comment.likesCount), style: TextStyle(color: colors.muted, fontSize: 13)),
        IconButton(
          tooltip: "Je n'aime pas",
          visualDensity: VisualDensity.compact,
          onPressed: () => _react(comment, _dislikeValue),
          icon: Icon(
            isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
            color: isDisliked ? colors.accent : colors.muted,
            size: 20,
          ),
        ),
      ],
    );
  }

  /// Avatar du créateur marqué d'un cœur quand il a aimé le commentaire.
  Widget _buildCreatorLike(_PanelColors colors) {
    return Tooltip(
      message: 'Aimé par le créateur',
      child: SizedBox(
        width: 26,
        height: 24,
        child: Stack(
          children: [
            _buildAvatar(widget.video.sellerAvatar, 20, colors),
            const Positioned(
              right: 0,
              bottom: 0,
              child: Icon(Icons.favorite, color: Colors.redAccent, size: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(_PanelColors colors) {
    final user = ref.watch(userProvider).value;
    final replyTarget = _replyTarget;
    final image = _imageBytes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyTarget != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Réponse à ${replyTarget.userName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.muted, fontSize: 13),
                  ),
                ),
                IconButton(
                  tooltip: 'Annuler la réponse',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _replyTarget = null),
                  icon: Icon(Icons.close, color: colors.muted, size: 18),
                ),
              ],
            ),
          ),
        if (image != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(image, width: 64, height: 64, fit: BoxFit.cover, cacheWidth: 180),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton(
                      tooltip: "Retirer l'image",
                      visualDensity: VisualDensity.compact,
                      onPressed: _clearImage,
                      icon: const Icon(Icons.cancel, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              _buildAvatar(user?.avatarUrl, 34, colors),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 14),
                  decoration: BoxDecoration(
                    color: colors.field,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          focusNode: _inputFocus,
                          maxLength: 500,
                          minLines: 1,
                          maxLines: 3,
                          onTap: () {
                            if (_showEmojis) setState(() => _showEmojis = false);
                          },
                          style: TextStyle(color: colors.text, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Ajouter un commentaire...',
                            hintStyle: TextStyle(color: colors.faint),
                            border: InputBorder.none,
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                      ),
                      _buildComposerIcon(Icons.image_outlined, 'Ajouter une image', _pickImage, colors),
                      _buildComposerIcon(Icons.emoji_emotions_outlined, 'Ajouter un emoji', () {
                        _inputFocus.unfocus();
                        setState(() => _showEmojis = !_showEmojis);
                      }, colors),
                      _buildComposerIcon(Icons.alternate_email, 'Mentionner', () => _showMentions(colors), colors),
                    ],
                  ),
                ),
              ),
              if (_canSend || _isSending)
                IconButton(
                  tooltip: 'Envoyer',
                  onPressed: _canSend ? _send : null,
                  icon: Icon(Icons.send, color: colors.accent),
                ),
            ],
          ),
        ),
        if (_showEmojis) _buildEmojiGrid(),
      ],
    );
  }

  Widget _buildComposerIcon(IconData icon, String tooltip, VoidCallback onPressed, _PanelColors colors) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(icon, color: colors.text, size: 21),
    );
  }

  Widget _buildEmojiGrid() {
    return SizedBox(
      height: 150,
      child: GridView.count(
        crossAxisCount: 8,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final emoji in _quickEmojis)
            InkWell(
              onTap: () => _insertAtCursor(emoji),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
            ),
        ],
      ),
    );
  }
}
