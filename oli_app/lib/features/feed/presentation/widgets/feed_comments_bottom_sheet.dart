import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
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
  XFile? _selectedMedia;
  String? _selectedMediaType;
  bool _isCompressing = false;

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

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickMedia();

    if (pickedFile != null) {
      setState(() {
        _selectedMedia = pickedFile;
        // Determine type loosely by extension or mime
        final path = pickedFile.path.toLowerCase();
        if (path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.avi')) {
          _selectedMediaType = 'video';
        } else {
          _selectedMediaType = 'image';
        }
      });

      // Compress video if it's a video
      if (_selectedMediaType == 'video') {
        setState(() => _isCompressing = true);
        try {
          final info = await VideoCompress.compressVideo(
            pickedFile.path,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
          );
          if (info != null && info.file != null) {
            setState(() {
              _selectedMedia = XFile(info.file!.path);
            });
          }
        } catch (e) {
          debugPrint("Video compression error: $e");
        } finally {
          setState(() => _isCompressing = false);
        }
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _selectedMedia == null) return;

    setState(() { _isPosting = true; });

    final newComment = await ref.read(feedProvider.notifier).addComment(
      widget.postId, 
      text,
      mediaFile: _selectedMedia,
      mediaType: _selectedMediaType,
    );
    
    if (mounted) {
      setState(() { _isPosting = false; });
      if (newComment != null) {
        _commentController.clear();
        _selectedMedia = null;
        _selectedMediaType = null;
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (comment['content'] != null && comment['content'].toString().isNotEmpty)
                              Text(comment['content']),
                            if (comment['media_url'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: comment['media_type'] == 'video'
                                    ? Container(
                                        height: 150,
                                        width: double.infinity,
                                        color: Colors.black12,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.play_circle_fill, size: 40, color: Colors.white70),
                                      )
                                    : Image.network(
                                        comment['media_url'],
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          // Preview of selected media
          if (_selectedMedia != null)
            Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.centerLeft,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _selectedMediaType == 'video' 
                      ? Container(
                          width: 80, height: 80, color: Colors.black26, 
                          child: const Icon(Icons.videocam, color: Colors.white)
                        )
                      : Image.file(File(_selectedMedia!.path), width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: -10,
                    right: -10,
                    child: IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => setState(() {
                        _selectedMedia = null;
                        _selectedMediaType = null;
                      }),
                    ),
                  ),
                  if (_isCompressing)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
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
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.camera_alt_outlined),
                        onPressed: _pickMedia,
                        tooltip: "Joindre une photo ou vidéo",
                      ),
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
