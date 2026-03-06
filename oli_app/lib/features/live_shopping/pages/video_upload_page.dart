import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/router/network/dio_provider.dart';
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';

/// Page d'upload de vidéo de vente
class VideoUploadPage extends ConsumerStatefulWidget {
  const VideoUploadPage({super.key});

  @override
  ConsumerState<VideoUploadPage> createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends ConsumerState<VideoUploadPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  XFile? _videoFile;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _selectedProductId;
  List<Map<String, dynamic>> _myProducts = [];
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();
    _loadMyProducts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadMyProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/products/user/my-products');
      if (response.data is List) {
        _myProducts = (response.data as List).cast<Map<String, dynamic>>();
      } else if (response.data['products'] is List) {
        _myProducts = (response.data['products'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Erreur chargement produits: $e');
    }
    if (mounted) setState(() => _loadingProducts = false);
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (video != null && mounted) {
      setState(() => _videoFile = video);
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final storage = ref.read(secureStorageProvider);
      final token = await storage.getToken();
      
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/videos');
      var request = http.MultipartRequest('POST', uri);
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (_titleController.text.isNotEmpty) {
        request.fields['title'] = _titleController.text;
      }
      if (_descController.text.isNotEmpty) {
        request.fields['description'] = _descController.text;
      }
      if (_selectedProductId != null) {
        request.fields['product_id'] = _selectedProductId!;
      }

      final videoBytes = await _videoFile!.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'video',
        videoBytes,
        filename: _videoFile!.name,
      ));

      // Simulons une progression puisque http.MultipartRequest ne le supporte pas nativement facilement
      setState(() => _uploadProgress = 0.5);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      setState(() => _uploadProgress = 1.0);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎬 Vidéo publiée avec succès !'),
            backgroundColor: Color(0xFF00C853),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // true = refresh feed
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      String message = 'Erreur lors de l\'upload';
      try {
        final decoded = jsonDecode(e.toString().replaceAll('Exception: ', ''));
        message = decoded['message'] ?? decoded['error'] ?? message;
      } catch (_) {}
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nouvelle vidéo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sélection vidéo ──
            GestureDetector(
              onTap: _isUploading ? null : _pickVideo,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _videoFile != null ? const Color(0xFFFF6D00) : Colors.white10,
                    width: _videoFile != null ? 2 : 1,
                  ),
                ),
                child: _videoFile != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam, color: Color(0xFFFF6D00), size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _videoFile!.name,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: _isUploading ? null : _pickVideo,
                            child: const Text(
                              'Changer la vidéo',
                              style: TextStyle(color: Color(0xFFFF6D00)),
                            ),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_call_outlined, color: Colors.white30, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'Sélectionner une vidéo',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Max 60 secondes · 50MB',
                            style: TextStyle(color: Colors.white24, fontSize: 12),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Titre ──
            const Text('Titre', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              maxLength: 150,
              decoration: InputDecoration(
                hintText: 'Décrivez votre vidéo...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle: const TextStyle(color: Colors.white24),
              ),
            ),

            const SizedBox(height: 16),

            // ── Description ──
            const Text('Description (optionnel)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ajoutez des détails...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Lier un produit ──
            const Text('Lier un produit', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _loadingProducts
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedProductId,
                        hint: const Text('Choisir un produit (optionnel)', style: TextStyle(color: Colors.white30)),
                        dropdownColor: const Color(0xFF1A1A2E),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white30),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Aucun produit', style: TextStyle(color: Colors.white54)),
                          ),
                          ..._myProducts.map((p) => DropdownMenuItem<String>(
                                value: p['id']?.toString(),
                                child: Text(
                                  p['name'] ?? 'Produit',
                                  style: const TextStyle(color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                        onChanged: (val) => setState(() => _selectedProductId = val),
                      ),
                    ),
            ),

            const SizedBox(height: 32),

            // ── Progress bar ──
            if (_isUploading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6D00)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_uploadProgress * 100).toInt()}% envoyé...',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],

            // ── Bouton publier ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _videoFile != null && !_isUploading ? _uploadVideo : null,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.publish, size: 20),
                label: Text(
                  _isUploading ? 'Publication en cours...' : 'Publier la vidéo',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6D00),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[800],
                  disabledForegroundColor: Colors.white38,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
