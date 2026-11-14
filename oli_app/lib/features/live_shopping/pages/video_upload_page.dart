import 'package:oli_app/core/widgets/oli_image.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:typed_data';
import '../../../core/router/network/dio_provider.dart';
import '../../../core/theme/oli_glass.dart';
import '../../../providers/exchange_rate_provider.dart';
import '../../../utils/cloudinary_helper.dart';
import '../providers/video_publish_provider.dart';

const _megabyte = 1024 * 1024;
const _maxVideoBytes = 100 * _megabyte;
const _maxVideoBytesWithSound = 40 * _megabyte;
const _readStep = 2 * _megabyte;

enum _VideoStage { empty, preparing, ready, failed }
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

/// Page de publication d'une vidéo de vente
class VideoUploadPage extends ConsumerStatefulWidget {
  const VideoUploadPage({super.key});

  @override
  ConsumerState<VideoUploadPage> createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends ConsumerState<VideoUploadPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  PlatformFile? _soundFile;
  bool _linkProduct = false;
  bool _useCustomSound = false;

  _VideoStage _stage = _VideoStage.empty;
  double _preparePercent = 0;
  String? _prepareError;
  int _prepareRun = 0;
  XFile? _preparedFile;
  int _preparedLength = 0;
  Uint8List? _thumbnail;
  VideoPlayerController? _webPreview;

  Map<String, dynamic>? _selectedProduct;
  List<Map<String, dynamic>> _myProducts = [];
  bool _loadingProducts = false;

  bool get _isUploading => ref.read(videoPublishProvider).isActive;

  bool get _canPublish =>
      _stage == _VideoStage.ready &&
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
    _webPreview?.dispose();
    if (!kIsWeb && _stage == _VideoStage.preparing) {
      VideoCompress.cancelCompression();
    }
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
      await _prepareVideo(video);
    }
  }

  /// Prépare la vidéo dès sa sélection : la publication n'est possible qu'à 100 %.
  Future<void> _prepareVideo(XFile video) async {
    final run = ++_prepareRun;
    if (!kIsWeb && _stage == _VideoStage.preparing) {
      await VideoCompress.cancelCompression();
    }
    final previous = _webPreview;
    setState(() {
      _stage = _VideoStage.preparing;
      _preparePercent = 0;
      _prepareError = null;
      _thumbnail = null;
      _webPreview = null;
      _preparedFile = null;
    });
    await previous?.dispose();

    try {
      final prepared = kIsWeb ? await _readForWeb(video, run) : await _compressOnMobile(video, run);
      if (run != _prepareRun || !mounted) return;

      final length = await prepared.length();
      if (length > _maxVideoBytes) {
        _failPreparation('La vidéo dépasse 100 Mo, choisissez-en une plus courte.');
        return;
      }
      setState(() {
        _preparedFile = prepared;
        _preparedLength = length;
        _preparePercent = 1;
        _stage = _VideoStage.ready;
      });
    } catch (e) {
      debugPrint('Préparation de la vidéo impossible: $e');
      if (run == _prepareRun && mounted) {
        _failPreparation('Cette vidéo ne peut pas être lue. Essayez-en une autre.');
      }
    }
  }

  void _failPreparation(String message) {
    setState(() {
      _stage = _VideoStage.failed;
      _prepareError = message;
    });
  }

  /// Le navigateur lit le fichier par blocs pour vérifier qu'il est accessible en entier.
  Future<XFile> _readForWeb(XFile video, int run) async {
    unawaited(_loadWebPreview(video, run));
    final total = await video.length();
    var offset = 0;
    while (offset < total) {
      final end = offset + _readStep < total ? offset + _readStep : total;
      await video.openRead(offset, end).drain<void>();
      offset = end;
      if (run != _prepareRun || !mounted) return video;
      setState(() => _preparePercent = offset / total);
    }
    return video;
  }

  /// Certains formats ne sont pas lisibles par le navigateur : l'aperçu reste alors sans image.
  Future<void> _loadWebPreview(XFile video, int run) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(video.path));
    try {
      await controller.initialize();
      await controller.setVolume(0);
      // Safari sur iPhone n'affiche la première image qu'après un début de lecture
      await controller.play();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await controller.pause();
      if (run == _prepareRun && mounted) {
        setState(() => _webPreview = controller);
      } else {
        await controller.dispose();
      }
    } catch (e) {
      debugPrint('Aperçu de la vidéo indisponible: $e');
      await controller.dispose();
    }
  }

  /// Compresse en HD et garde l'originale si elle est déjà plus légère.
  Future<XFile> _compressOnMobile(XFile video, int run) async {
    unawaited(_loadMobileThumbnail(video, run));
    final subscription = VideoCompress.compressProgress$.subscribe((percent) {
      if (run == _prepareRun && mounted) {
        setState(() => _preparePercent = (percent / 100).clamp(0.0, 1.0));
      }
    });
    try {
      final compressed = await VideoCompress.compressVideo(
        video.path,
        quality: VideoQuality.Res1280x720Quality,
        deleteOrigin: false,
      );
      final file = compressed?.file;
      if (file != null && await file.length() < await video.length()) {
        return XFile(file.path);
      }
    } catch (e) {
      debugPrint('Compression impossible, envoi de la vidéo originale: $e');
    } finally {
      subscription.unsubscribe();
    }
    return video;
  }

  Future<void> _loadMobileThumbnail(XFile video, int run) async {
    try {
      final thumbnail = await VideoCompress.getByteThumbnail(video.path, quality: 60);
      if (run == _prepareRun && mounted) setState(() => _thumbnail = thumbnail);
    } catch (e) {
      debugPrint('Miniature indisponible: $e');
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
    setState(() {
      _soundFile = file;
    });
  }

  /// Confie la publication au service global, qui survit à la fermeture de la page.
  void _publish() {
    final file = _preparedFile;
    if (file == null || !_canPublish) return;

    if (_useCustomSound && _preparedLength > _maxVideoBytesWithSound) {
      _showMessage('Avec un son ajouté, la vidéo doit faire moins de 40 Mo.', isError: true);
      return;
    }

    ref.read(videoPublishProvider.notifier).start(
          VideoPublishJob(
            file: file,
            length: _preparedLength,
            sound: _useCustomSound ? _soundFile : null,
            title: _titleController.text,
            description: _descController.text,
            productId: _linkProduct ? _selectedProduct!['id'].toString() : null,
          ),
          thumbnail: _thumbnail,
        );
  }

  /// L'envoi continue pendant que l'utilisateur navigue dans l'application.
  void _continueInBackground() {
    ref.read(videoPublishProvider.notifier).sendToBackground();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("L'envoi continue. Gardez l'application ouverte jusqu'à la fin.")),
    );
  }

  String? _productImage(Map<String, dynamic> product) {
    final images = product['images'];
    if (images is List && images.isNotEmpty) return images.first?.toString();
    return (product['imageUrl'] ?? product['image_url'])?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _UploadColors.of(context);
    final publish = ref.watch(videoPublishProvider);
    ref.listen(videoPublishProvider, (previous, next) {
      if (next.status == VideoPublishStatus.done && !next.inBackground) {
        _showMessage('🎬 Vidéo publiée avec succès !');
        ref.read(videoPublishProvider.notifier).dismiss();
        Navigator.pop(context, true); // true = rafraîchir le fil
      }
    });

    return Stack(
      children: [
        Scaffold(
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
            _buildPublishButton(colors),
          ],
        ),
      ),
        ),
        if (publish.isActive && !publish.inBackground) Positioned.fill(child: _buildPublishOverlay(publish)),
      ],
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

  /// Image de la vidéo en arrière-plan, ou fond sombre si le format ne peut pas s'afficher.
  Widget _buildVideoBackdrop() {
    final thumbnail = _thumbnail;
    if (thumbnail != null) {
      return Image.memory(thumbnail, fit: BoxFit.cover, cacheWidth: 720);
    }
    final preview = _webPreview;
    if (preview != null && preview.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: preview.value.size.width,
          height: preview.value.size.height,
          child: VideoPlayer(preview),
        ),
      );
    }
    return const ColoredBox(color: OliPalette.navy);
  }

  Widget _buildPercent(double? progress, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          progress == null ? '...' : '${(progress * 100).floor()} %',
          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(OliPalette.blueOnDark),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  Widget _buildVideoPicker(_UploadColors colors) {
    final isEmpty = _stage == _VideoStage.empty;
    return GestureDetector(
      onTap: _isUploading || _stage == _VideoStage.preparing ? null : _pickVideo,
      child: Container(
        height: 220,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _stage == _VideoStage.ready ? colors.accent : colors.border,
            width: _stage == _VideoStage.ready ? 2 : 1,
          ),
        ),
        child: isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_call_outlined, color: colors.faint, size: 48),
                  const SizedBox(height: 12),
                  Text('Sélectionner une vidéo', style: TextStyle(color: colors.muted, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    'MP4, MOV, WebM et autres · 100 Mo maximum',
                    style: TextStyle(color: colors.faint, fontSize: 12),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  _buildVideoBackdrop(),
                  const ColoredBox(color: Color(0x8C000000)),
                  _buildVideoStage(),
                ],
              ),
      ),
    );
  }

  Widget _buildVideoStage() {
    switch (_stage) {
      case _VideoStage.preparing:
        return _buildPercent(_preparePercent, kIsWeb ? 'Chargement de la vidéo' : 'Compression de la vidéo');
      case _VideoStage.ready:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 44),
            const SizedBox(height: 8),
            const Text(
              'Vidéo prête à publier',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: _isUploading ? null : _pickVideo,
              child: const Text('Changer la vidéo', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      case _VideoStage.failed:
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 40),
              const SizedBox(height: 8),
              Text(
                _prepareError ?? 'Cette vidéo ne peut pas être préparée.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              TextButton(
                onPressed: _pickVideo,
                child: const Text('Choisir une autre vidéo', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      case _VideoStage.empty:
        return const SizedBox.shrink();
    }
  }

  /// Écran de publication : l'aperçu reste visible derrière la progression réelle.
  Widget _buildPublishOverlay(VideoPublishState publish) {
    final notifier = ref.read(videoPublishProvider.notifier);
    final error = publish.error;
    final isFinalizing = publish.status == VideoPublishStatus.finalizing;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (error == null) {
          _continueInBackground();
        } else {
          notifier.dismiss();
        }
      },
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideoBackdrop(),
            const ColoredBox(color: Color(0xA6000000)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (error == null) ...[
                      _buildPercent(
                        isFinalizing ? null : publish.progress,
                        isFinalizing ? 'Finalisation de la publication' : 'Envoi de votre vidéo',
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _continueInBackground,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Continuer en arrière-plan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OliPalette.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.wifi_off, color: Colors.white, size: 44),
                      const SizedBox(height: 12),
                      Text(
                        error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: notifier.retry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OliPalette.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Réessayer'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: error == null ? notifier.cancel : notifier.dismiss,
                      child: Text(
                        error == null ? "Annuler l'envoi" : 'Fermer',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
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
            : OliImage.network(
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
        onPressed: _canPublish ? _publish : null,
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
