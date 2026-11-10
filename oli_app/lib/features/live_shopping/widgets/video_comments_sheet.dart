import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/network/dio_provider.dart';
import '../../../core/user/user_provider.dart';
import '../models/video_sale_model.dart';
import '../providers/video_feed_provider.dart';

const _commentsPageSize = 20;

/// Volet des commentaires d'une vidéo
class VideoCommentsSheet extends ConsumerStatefulWidget {
  final VideoSale video;

  const VideoCommentsSheet({super.key, required this.video});

  @override
  ConsumerState<VideoCommentsSheet> createState() => _VideoCommentsSheetState();
}

class _VideoCommentsSheetState extends ConsumerState<VideoCommentsSheet> {
  final _inputController = TextEditingController();
  final List<VideoComment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _hasError = false;
  bool _hasMore = false;
  int _page = 0;

  String get _commentsPath => '/api/videos/${widget.video.id}/comments';

  @override
  void initState() {
    super.initState();
    _loadNextPage();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
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
        queryParameters: {'page': nextPage, 'limit': _commentsPageSize},
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

  Future<void> _send() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final response = await ref.read(dioProvider).post(_commentsPath, data: {'content': content});
      final comment = VideoComment.fromJson(response.data['comment'] as Map<String, dynamic>);
      ref.read(videoFeedProvider.notifier).adjustCommentsCount(widget.video.id, 1);
      if (!mounted) return;
      _inputController.clear();
      setState(() => _comments.insert(0, comment));
    } on DioException {
      _showError("Impossible d'envoyer le commentaire");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _delete(VideoComment comment) async {
    try {
      await ref.read(dioProvider).delete('$_commentsPath/${comment.id}');
      ref.read(videoFeedProvider.notifier).adjustCommentsCount(widget.video.id, -1);
      if (mounted) setState(() => _comments.remove(comment));
    } on DioException {
      _showError('Impossible de supprimer le commentaire');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(userProvider).value?.id.toString();
    final isVideoOwner = currentUserId == widget.video.sellerId;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Commentaires',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(child: _buildList(currentUserId, isVideoOwner)),
          const Divider(height: 1, color: Colors.white12),
          SafeArea(top: false, child: _buildInput()),
        ],
      ),
    );
  }

  Widget _buildList(String? currentUserId, bool isVideoOwner) {
    if (_isLoading && _comments.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2));
    }
    if (_hasError && _comments.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadNextPage,
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('Réessayer', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    if (_comments.isEmpty) {
      return const Center(
        child: Text('Soyez le premier à commenter', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _comments.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _comments.length) {
          return TextButton(
            onPressed: _isLoading ? null : _loadNextPage,
            child: Text(_isLoading ? 'Chargement...' : 'Voir plus'),
          );
        }
        final comment = _comments[index];
        final canDelete = isVideoOwner || comment.userId == currentUserId;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[800],
            backgroundImage: comment.userAvatar != null ? NetworkImage(comment.userAvatar!) : null,
            child: comment.userAvatar == null
                ? const Icon(Icons.person, color: Colors.white54, size: 20)
                : null,
          ),
          title: Text(
            '${comment.userName} · ${_formatDate(comment.createdAt)}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          subtitle: Text(comment.content, style: const TextStyle(color: Colors.white, fontSize: 14)),
          trailing: canDelete
              ? IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                  onPressed: () => _delete(comment),
                )
              : null,
        );
      },
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLength: 500,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Ajouter un commentaire...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Envoyer',
            onPressed: _isSending ? null : _send,
            icon: const Icon(Icons.send, color: Color(0xFFFF6D00)),
          ),
        ],
      ),
    );
  }
}
