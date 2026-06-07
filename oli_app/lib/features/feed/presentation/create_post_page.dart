import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import '../providers/feed_provider.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  XFile? _selectedMedia;
  String? _mediaType; // 'image' or 'video'

  Future<void> _pickMedia(bool isVideo) async {
    try {
      final XFile? pickedFile = isVideo 
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(
            source: ImageSource.gallery, 
            imageQuality: 50, 
            maxWidth: 1080, 
            maxHeight: 1080
          ); // Compression drastique 50% max HD

      if (pickedFile != null) {
        if (isVideo) {
          // Validation de la durée (< 1 minute)
          final controller = kIsWeb 
              ? VideoPlayerController.networkUrl(Uri.parse(pickedFile.path))
              : VideoPlayerController.file(File(pickedFile.path));
          await controller.initialize();
          final duration = controller.value.duration;
          await controller.dispose();

          if (duration.inSeconds > 60) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("La vidéo doit durer moins d'une minute.")),
              );
            }
            return;
          }

          setState(() { _isLoading = true; });
          
          XFile compressedFile = pickedFile;
          
          if (!kIsWeb) {
            // Compression vidéo native sur mobile
            final info = await VideoCompress.compressVideo(
              pickedFile.path,
              quality: VideoQuality.MediumQuality,
              deleteOrigin: false,
              includeAudio: true,
            );
            if (info != null && info.file != null) {
              compressedFile = XFile(info.file!.path);
            }
          }

          setState(() {
            _selectedMedia = compressedFile;
            _mediaType = 'video';
            _isLoading = false;
          });
        } else {
          setState(() {
            _selectedMedia = pickedFile;
            _mediaType = 'image';
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur media picker: $e");
      setState(() { _isLoading = false; });
    }
  }

  void _publishPost() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedMedia == null) return;

    setState(() {
      _isLoading = true;
    });

    final success = await ref.read(feedProvider.notifier).createPost(
      text, 
      mediaFile: _selectedMedia, 
      mediaType: _mediaType
    );
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (success) {
        Navigator.of(context).pop(); // Fermer la page et retourner au feed
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de la publication")),
        );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Créer une publication', style: TextStyle(color: Colors.black, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _publishPost,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Publier'),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: "Quoi de neuf ?",
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            if (_selectedMedia != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[200],
                      image: _mediaType == 'image' ? DecorationImage(
                        image: kIsWeb 
                            ? NetworkImage(_selectedMedia!.path) as ImageProvider
                            : FileImage(File(_selectedMedia!.path)),
                        fit: BoxFit.cover,
                      ) : null,
                    ),
                    child: _mediaType == 'video' ? const Center(
                      child: Icon(Icons.videocam, size: 48, color: Colors.grey),
                    ) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => setState(() { _selectedMedia = null; _mediaType = null; }),
                  )
                ],
              ),
            const Divider(),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined, color: Colors.blue),
                  onPressed: () => _pickMedia(false),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam_outlined, color: Colors.red),
                  onPressed: () => _pickMedia(true),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
