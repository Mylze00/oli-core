import 'package:dropdown_search/dropdown_search.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'dart:convert';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/theme/oli_glass.dart';
import '../../../providers/exchange_rate_provider.dart';
import '../../../utils/cloudinary_helper.dart';

const _megabyte = 1024 * 1024;
const _maxVideoBytes = 50 * _megabyte;
const _maxVideoBytesWithSound = 40 * _megabyte;
const _maxSoundBytes = 15 * _megabyte;

/// Couleurs de la page selon le mode clair ou sombre de l'application.
class _UploadColors {
  final Color accent;
  final Color card;
  final Color border;
  final Color text;
  final Color muted;
  final Color faint;

  factory _UploadColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    return _UploadColors._(
      accent: isDark ? OliPalette.blueOnDark : OliPalette.blue,
      card: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      border: isDark ? Colors.white10 : Colors.black12,
      text: text,
      muted: text.withOpacity(0.7),
      faint: text.withOpacity(0.45),
    );
  }

  const _UploadColors._({
    required this.accent,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
  });
}

/// Vidéo prête à être envoyée après compression éventuelle.
class _PreparedVideo {
  final List<int> bytes;
  final String filename;
  final int? durationSeconds;

  const _PreparedVideo(this.bytes, this.filename, this.durationSeconds);
}

/// Page de publication d'une vidéo de vente
class VideoUploadPage extends ConsumerStatefulWidget {
  const VideoUploadPage({super.key});

  @override
  ConsumerState<VideoUploadPage> createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends ConsumerState<VideoUploadPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  XFile? _videoFile;
  PlatformFile? _soundFile;
  bool _linkProduct = false;
  bool _useCustomSound = false;
  bool _isUploading = false;
  String _uploadStatus = '';
  Map<String, dynamic>? _selectedProduct;
  List<Map<String, dynamic>> _myProducts = [];
  bool _loadingProducts = false;

  bool get _canPublish =>
      _videoFile != null &&
      !_isUploading &&
      (!_linkProduct || _selectedProduct != null) &&
      (!_useCustomSound || _soundFile != null);

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

  /// Sans recherche : mes produits. Avec recherche : tout le catalogue actif.
  Future<List<Map<String, dynamic>>> _searchProducts(String filter) async {
    final query = filter.trim();
    if (query.isEmpty) return _myProducts;

    final response = await ref.read(dioProvider).get(
      '/products',
      queryParameters: {'search': query, 'limit': 30},
    );
    final products = response.data['products'];
    if (products is! List) return [];
    return products
        .cast<Map<String, dynamic>>()
        .where((p) => p['status'] == null || p['status'] == 'active')
        .toList();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF00C853),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickVideo() async {
    final video = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (video != null && mounted) {
      setState(() => _videoFile = video);
    }
  }

  Future<void> _pickSound() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || !mounted) return;

    if (file.bytes == null || file.size > _maxSoundBytes) {
      _showMessage('Le fichier son doit faire moins de 15 Mo.', isError: true);
      return;
    }
    setState(() => _soundFile = file);
  }

  /// Compresse en HD sur mobile. Le navigateur envoie la vidéo telle quelle,
  /// son optimisation étant alors assurée par Cloudinary.
  Future<_PreparedVideo> _prepareVideo(XFile video) async {
    if (kIsWeb) {
      return _PreparedVideo(
        await video.readAsBytes(),
        video.name,
        await _readWebDuration(video.path),
      );
    }

    setState(() => _uploadStatus = 'Compression de la vidéo...');
    MediaInfo? compressed;
    try {
      compressed = await VideoCompress.compressVideo(
        video.path,
        quality: VideoQuality.Res1280x720Quality,
        deleteOrigin: false,
        includeAudio: !_useCustomSound,
      );
    } catch (e) {
      debugPrint('Compression impossible, envoi de la vidéo originale: $e');
    }

    final compressedFile = compressed?.file;
    final durationMs = compressed?.duration;
    final durationSeconds = durationMs != null && durationMs > 0 ? (durationMs / 1000).ceil() : null;

    if (compressedFile != null && await compressedFile.length() < await video.length()) {
      return _PreparedVideo(
        await compressedFile.readAsBytes(),
        compressedFile.path.split('/').last,
        durationSeconds,
      );
    }
    return _PreparedVideo(await video.readAsBytes(), video.name, durationSeconds);
  }

  Future<int?> _readWebDuration(String path) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(path));
    try {
      await controller.initialize();
      final seconds = controller.value.duration.inMilliseconds / 1000;
      return seconds > 0 ? seconds.ceil() : null;
    } catch (e) {
      debugPrint('Durée de la vidéo illisible: $e');
      return null;
    } finally {
      await controller.dispose();
    }
  }

  /// Retourne le message d'erreur si la taille n'est pas acceptée.
  String? _sizeError(int bytes) {
    if (bytes > _maxVideoBytes) {
      return 'La vidéo dépasse 50 Mo, choisissez-en une plus courte.';
    }
    if (_useCustomSound && bytes > _maxVideoBytesWithSound) {
      return 'Avec un son ajouté, la vidéo doit faire moins de 40 Mo.';
    }
    return null;
  }

  Future<void> _uploadVideo() async {
    final video = _videoFile;
    if (video == null || !_canPublish) return;

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Préparation de la vidéo...';
    });

    try {
      final prepared = await _prepareVideo(video);
      final sizeError = _sizeError(prepared.bytes.length);
      if (sizeError != null) {
        _showMessage(sizeError, isError: true);
        return;
      }

      if (mounted) setState(() => _uploadStatus = 'Publication de la vidéo...');

      final token = await ref.read(secureStorageProvider).getToken();
      final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/api/videos'));
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (_titleController.text.isNotEmpty) {
        request.fields['title'] = _titleController.text;
      }
      if (_descController.text.isNotEmpty) {
        request.fields['description'] = _descController.text;
      }
      if (_linkProduct && _selectedProduct != null) {
        request.fields['product_id'] = _selectedProduct!['id'].toString();
      }
      if (prepared.durationSeconds != null) {
        request.fields['duration_seconds'] = prepared.durationSeconds.toString();
      }

      request.files.add(http.MultipartFile.fromBytes(
        'video',
        prepared.bytes,
        filename: prepared.filename,
      ));
      final sound = _soundFile;
      if (_useCustomSound && sound != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'audio',
          sound.bytes!,
          filename: sound.name,
        ));
      }

      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode != 200 && response.statusCode != 201) {
        _showMessage(_readServerError(response.body), isError: true);
        return;
      }

      _showMessage('🎬 Vidéo publiée avec succès !');
      if (mounted) Navigator.pop(context, true); // true = rafraîchir le fil
    } catch (e) {
      debugPrint('Erreur publication vidéo: $e');
      _showMessage("Erreur lors de l'envoi de la vidéo", isError: true);
    } finally {
      if (!kIsWeb) {
        await VideoCompress.deleteAllCache();
      }
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _readServerError(String body) {
    try {
      final decoded = jsonDecode(body);
      return (decoded['message'] ?? decoded['error'] ?? "Erreur lors de l'envoi").toString();
    } catch (_) {
      return "Erreur lors de l'envoi";
    }
  }

  String? _productImage(Map<String, dynamic> product) {
    final images = product['images'];
    if (images is List && images.isNotEmpty) return images.first?.toString();
    return (product['imageUrl'] ?? product['image_url'])?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _UploadColors.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colors.text,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isUploading ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Nouvelle vidéo',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoPicker(colors),
            const SizedBox(height: 24),
            _buildLabel('Titre', colors),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleController,
              hint: 'Décrivez votre vidéo...',
              colors: colors,
              maxLength: 150,
            ),
            const SizedBox(height: 16),
            _buildLabel('Description (optionnel)', colors),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _descController,
              hint: 'Ajoutez des détails...',
              colors: colors,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildSoundSection(colors),
            const SizedBox(height: 16),
            _buildProductSection(colors),
            const SizedBox(height: 32),
            if (_isUploading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  backgroundColor: colors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(_uploadStatus, style: TextStyle(color: colors.muted, fontSize: 12)),
              ),
              const SizedBox(height: 16),
            ],
            _buildPublishButton(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label, _UploadColors colors) {
    return Text(
      label,
      style: TextStyle(color: colors.muted, fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required _UploadColors colors,
    int? maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isUploading,
      style: TextStyle(color: colors.text),
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.faint),
        filled: true,
        fillColor: colors.card,
        counterStyle: TextStyle(color: colors.faint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildVideoPicker(_UploadColors colors) {
    final video = _videoFile;
    return GestureDetector(
      onTap: _isUploading ? null : _pickVideo,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: video != null ? colors.accent : colors.border,
            width: video != null ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: video != null
              ? [
                  Icon(Icons.videocam, color: colors.accent, size: 48),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      video.name,
                      style: TextStyle(color: colors.muted, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _isUploading ? null : _pickVideo,
                    child: Text('Changer la vidéo', style: TextStyle(color: colors.accent)),
                  ),
                ]
              : [
                  Icon(Icons.video_call_outlined, color: colors.faint, size: 48),
                  const SizedBox(height: 12),
                  Text('Sélectionner une vidéo', style: TextStyle(color: colors.muted, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    'Max 60 secondes · compression automatique',
                    style: TextStyle(color: colors.faint, fontSize: 12),
                  ),
                ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required _UploadColors colors,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required List<Widget> details,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: value,
            onChanged: _isUploading ? null : onChanged,
            activeColor: colors.accent,
            title: Text(title, style: TextStyle(color: colors.text, fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle, style: TextStyle(color: colors.faint, fontSize: 12)),
          ),
          if (value)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: details,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSoundSection(_UploadColors colors) {
    final sound = _soundFile;
    return _buildOptionCard(
      colors: colors,
      title: 'Ajouter un fichier son',
      subtitle: _useCustomSound ? 'Ce son remplacera celui de la vidéo' : 'La vidéo garde son propre son',
      value: _useCustomSound,
      onChanged: (value) => setState(() {
        _useCustomSound = value;
        if (!value) _soundFile = null;
      }),
      details: [
        if (sound != null)
          Row(
            children: [
              Icon(Icons.music_note, color: colors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sound.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.text, fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: 'Retirer le son',
                icon: Icon(Icons.close, color: colors.muted, size: 20),
                onPressed: _isUploading ? null : () => setState(() => _soundFile = null),
              ),
            ],
          )
        else
          OutlinedButton.icon(
            onPressed: _isUploading ? null : _pickSound,
            icon: const Icon(Icons.library_music_outlined, size: 18),
            label: const Text('Choisir un son (MP3, WAV, M4A, AAC)'),
            style: OutlinedButton.styleFrom(foregroundColor: colors.accent),
          ),
      ],
    );
  }

  Widget _buildProductSection(_UploadColors colors) {
    return _buildOptionCard(
      colors: colors,
      title: 'Relier un produit',
      subtitle: _linkProduct ? 'Les spectateurs pourront acheter ce produit' : 'Vidéo publiée sans produit',
      value: _linkProduct,
      onChanged: (value) => setState(() {
        _linkProduct = value;
        if (!value) _selectedProduct = null;
      }),
      details: [
        if (_loadingProducts)
          Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent))
        else
          _buildProductSearch(colors),
        if (_selectedProduct != null) ...[
          const SizedBox(height: 12),
          _buildSelectedProduct(_selectedProduct!, colors),
        ],
        const SizedBox(height: 8),
        Text(
          "Recherchez dans tout le catalogue. Si le produit appartient à un autre vendeur, vous recevez 2 % de chaque vente issue de votre vidéo.",
          style: TextStyle(color: colors.faint, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildProductSearch(_UploadColors colors) {
    return DropdownSearch<Map<String, dynamic>>(
      enabled: !_isUploading,
      asyncItems: _searchProducts,
      // Le filtrage est fait par le serveur
      filterFn: (_, __) => true,
      compareFn: (i, s) => i['id']?.toString() == s['id']?.toString(),
      itemAsString: (product) => product['name']?.toString() ?? 'Produit',
      onChanged: (product) => setState(() => _selectedProduct = product),
      selectedItem: _selectedProduct,
      popupProps: PopupProps.menu(
        showSearchBox: true,
        isFilterOnline: true,
        searchFieldProps: TextFieldProps(
          style: TextStyle(color: colors.text),
          decoration: InputDecoration(
            hintText: 'Rechercher un produit...',
            hintStyle: TextStyle(color: colors.faint),
            filled: true,
            fillColor: colors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        menuProps: MenuProps(backgroundColor: colors.card),
        itemBuilder: (context, product, isSelected) => ListTile(
          leading: _buildProductThumbnail(product, 40, colors),
          title: Text(
            product['name']?.toString() ?? 'Produit',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? colors.accent : colors.text,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          hintText: 'Choisir un produit',
          hintStyle: TextStyle(color: colors.faint),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        baseStyle: TextStyle(color: colors.text),
      ),
    );
  }

  /// Miniature en qualité réduite : 120 px suffisent pour un aperçu.
  Widget _buildProductThumbnail(Map<String, dynamic> product, double size, _UploadColors colors) {
    final image = _productImage(product);
    final placeholder = Icon(Icons.image_outlined, color: colors.faint, size: size / 2);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: colors.border,
        child: image == null
            ? placeholder
            : Image.network(
                CloudinaryHelper.xsmall(image),
                fit: BoxFit.cover,
                cacheWidth: 120,
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }

  Widget _buildSelectedProduct(Map<String, dynamic> product, _UploadColors colors) {
    ref.watch(exchangeRateProvider);
    final price = double.tryParse(product['price']?.toString() ?? '');
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.accent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          _buildProductThumbnail(product, 56, colors),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Produit relié', style: TextStyle(color: colors.faint, fontSize: 11)),
                Text(
                  product['name']?.toString() ?? 'Produit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.text, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (price != null)
                  Text(
                    ref.read(exchangeRateProvider.notifier).formatProductPrice(price),
                    style: TextStyle(color: colors.accent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Retirer le produit',
            icon: Icon(Icons.close, color: colors.muted, size: 20),
            onPressed: _isUploading ? null : () => setState(() => _selectedProduct = null),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishButton(_UploadColors colors) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _canPublish ? _uploadVideo : null,
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
          backgroundColor: OliPalette.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.border,
          disabledForegroundColor: colors.faint,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }
}
