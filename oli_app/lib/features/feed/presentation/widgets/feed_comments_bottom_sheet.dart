import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/feed_provider.dart';

class FeedCommentsBottomSheet extends ConsumerStatefulWidget {
  final int postId;

  const FeedCommentsBottomSheet({Key? key, required this.postId}) : super(key: key);

  @override
  ConsumerState<FeedCommentsBottomSheet> createState() => _FeedCommentsBottomSheetState();
}

class _FeedCommentsBottomSheetState extends ConsumerState<FeedCommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final comments = await ref.read(feedProvider.notifier).fetchComments(widget.postId);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() { _isPosting = true; });

    final newComment = await ref.read(feedProvider.notifier).addComment(widget.postId, text);
    
    if (mounted) {
      setState(() { _isPosting = false; });
      if (newComment != null) {
        _commentController.clear();
        setState(() {
          _comments.add(newComment);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de l'envoi du commentaire.")),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hauteur max de la modal: 80% de l'écran
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // Gestion du clavier
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle pour indiquer que c'est draggable
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            "Commentaires",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          // Liste des commentaires
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _comments.isEmpty 
                ? const Center(child: Text("Aucun commentaire pour le moment."))
                : ListView.builder(
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: comment['author_avatar'] != null 
                              ? NetworkImage(comment['author_avatar']) 
                              : null,
                          child: comment['author_avatar'] == null 
                              ? const Icon(Icons.person) 
                              : null,
                        ),
                        title: Text(comment['author_name'] ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(comment['content'] ?? ''),
                      );
                    },
                  ),
          ),
          // Input
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: "Ajouter un commentaire...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                const SizedBox(width: 8),
                _isPosting 
                  ? const CircularProgressIndicator()
                  : IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: _postComment,
                    )
              ],
            ),
          )
        ],
      ),
    );
  }
}
