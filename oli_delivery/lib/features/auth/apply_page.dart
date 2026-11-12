import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/api_config.dart';
import '../../core/providers/dio_provider.dart';
import 'providers/auth_controller.dart';

const _primary = Color(0xFF1E7DBA);
const _minPledgeFc = 100;
/// Limite du serveur pour la photo de la pièce d'identité.
const _maxDocumentBytes = 8 * 1024 * 1024;

/// Moyens de déplacement acceptés par le serveur (valeur envoyée → libellé).
const _vehicles = {
  'moto': 'Moto',
  'velo': 'Vélo',
  'voiture': 'Voiture',
  'pied': 'À pied',
};
const _vehiclesWithPlate = {'moto', 'voiture'};

class ApplyPage extends ConsumerStatefulWidget {
  const ApplyPage({super.key});

  @override
  ConsumerState<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends ConsumerState<ApplyPage> {
  final _fullNameController = TextEditingController();
  final _plateController = TextEditingController();
  final _zoneController = TextEditingController();
  final _pledgeController = TextEditingController();
  final _motivationController = TextEditingController();

  String? _vehicleType;
  XFile? _idDocument;
  Uint8List? _idDocumentPreview;

  /// Solde du wallet Oli en FC : null tant qu'il n'est pas chargé.
  double? _walletBalance;
  bool _isSubmitting = false;

  /// Vrai tant qu'on vérifie si une candidature existe déjà.
  bool _isCheckingExisting = true;

  @override
  void initState() {
    super.initState();
    _redirectIfAlreadyApplied();
    _loadWalletBalance();
  }

  /// Après la connexion par téléphone, un candidat qui a déjà postulé suit sa
  /// candidature au lieu de remplir le formulaire une seconde fois.
  Future<void> _redirectIfAlreadyApplied() async {
    try {
      final response = await ref.read(dioProvider).get(ApiConfig.deliveryApplyStatus);
      final status = response.data is Map ? response.data['status']?.toString() : null;
      if (mounted && (status == 'pending' || status == 'approved')) {
        context.go('/pending');
        return;
      }
    } catch (e) {
      debugPrint('Statut de candidature non vérifié: $e');
    }
    if (mounted) setState(() => _isCheckingExisting = false);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _plateController.dispose();
    _zoneController.dispose();
    _pledgeController.dispose();
    _motivationController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletBalance() async {
    try {
      final response = await ref.read(dioProvider).get(ApiConfig.oliWalletBalance);
      final balance = (response.data['balanceFC'] as num?)?.toDouble();
      if (mounted && balance != null) setState(() => _walletBalance = balance);
    } catch (e) {
      debugPrint('Solde du wallet non chargé: $e');
    }
  }

  Future<void> _pickIdDocument(ImageSource source) async {
    try {
      // Sur le web, le redimensionnement passe par un canvas qui échoue sur certains
      // formats de photo : l'image est prise telle quelle et seule sa taille est vérifiée
      final file = kIsWeb
          ? await ImagePicker().pickImage(source: source)
          : await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxDocumentBytes) {
        _showError('Photo trop lourde (8 Mo maximum). Choisissez une image plus légère.');
        return;
      }
      if (mounted) {
        setState(() {
          _idDocument = file;
          _idDocumentPreview = bytes;
        });
      }
    } catch (e) {
      debugPrint('Photo de la pièce non ouverte: $e');
      _showError("Impossible d'ouvrir la photo ($e).");
    }
  }

  void _chooseIdDocumentSource() {
    // Sur le web, le navigateur propose lui-même appareil photo ou fichier
    if (kIsWeb) {
      _pickIdDocument(ImageSource.gallery);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickIdDocument(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.pop(ctx);
                _pickIdDocument(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Premier champ manquant, ou null si la candidature est complète.
  String? _validationError(int pledge) {
    if (_fullNameController.text.trim().length < 3) return 'Indiquez votre nom complet';
    if (_vehicleType == null) return 'Choisissez votre moyen de déplacement';
    if (_vehiclesWithPlate.contains(_vehicleType) && _plateController.text.trim().isEmpty) {
      return "Indiquez la plaque d'immatriculation";
    }
    if (_zoneController.text.trim().isEmpty) return 'Indiquez votre zone de livraison';
    if (_idDocument == null) return "Ajoutez la photo de votre pièce d'identité";
    if (pledge < _minPledgeFc) return 'Le gage doit être d\'au moins $_minPledgeFc FC';
    final balance = _walletBalance;
    if (balance != null && pledge > balance) {
      return 'Solde insuffisant : votre wallet Oli contient ${_formatFc(balance)}. Rechargez-le ou baissez le gage.';
    }
    return null;
  }

  Future<void> _submit() async {
    final pledge = int.tryParse(_pledgeController.text.trim()) ?? 0;
    final error = _validationError(pledge);
    if (error != null) {
      _showError(error);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquer le gage ?'),
        content: Text(
          '${_formatFc(pledge)} seront prélevés sur votre wallet Oli et bloqués pendant l\'examen '
          'de votre candidature. Ils vous seront rendus si elle est refusée.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final document = _idDocument!;
      final form = FormData.fromMap({
        'full_name': _fullNameController.text.trim(),
        'vehicle_type': _vehicleType,
        'vehicle_plate': _plateController.text.trim(),
        'zone': _zoneController.text.trim(),
        'pledge_fc': pledge,
        'motivation': _motivationController.text.trim(),
        'id_document': MultipartFile.fromBytes(
          await document.readAsBytes(),
          filename: document.name.isNotEmpty ? document.name : 'piece_identite.jpg',
        ),
      });

      final response = await ref.read(dioProvider).post(ApiConfig.deliveryApply, data: form);
      if (mounted && (response.statusCode == 201 || response.statusCode == 200)) {
        context.go('/pending');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final code = data is Map ? data['code']?.toString() : null;
      if (mounted && (code == 'already_pending' || code == 'already_approved')) {
        context.go('/pending');
        return;
      }
      final message = data is Map ? data['error']?.toString() : null;
      _showError(message ?? 'Envoi impossible. Vérifiez votre connexion et réessayez.');
    } catch (e) {
      _showError('Envoi impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingExisting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final needsPlate = _vehiclesWithPlate.contains(_vehicleType);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConnectedPhone(),
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildAdvantages(),
                  const SizedBox(height: 28),

                  _sectionTitle('Votre identité'),
                  _field(
                    controller: _fullNameController,
                    label: 'Nom complet (comme sur la pièce)',
                    icon: Icons.person_outline,
                    capitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  _buildIdDocumentPicker(),

                  const SizedBox(height: 28),
                  _sectionTitle('Votre activité'),
                  _label('Moyen de déplacement'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _vehicles.entries.map((vehicle) => ChoiceChip(
                          label: Text(vehicle.value),
                          selected: _vehicleType == vehicle.key,
                          selectedColor: _primary.withOpacity(0.15),
                          onSelected: (_) => setState(() => _vehicleType = vehicle.key),
                        )).toList(),
                  ),
                  if (needsPlate) ...[
                    const SizedBox(height: 12),
                    _field(
                      controller: _plateController,
                      label: "Plaque d'immatriculation",
                      icon: Icons.pin_outlined,
                      capitalization: TextCapitalization.characters,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _field(
                    controller: _zoneController,
                    label: 'Zone de livraison (ex : Gombe, Limete)',
                    icon: Icons.location_on_outlined,
                    capitalization: TextCapitalization.words,
                  ),

                  const SizedBox(height: 28),
                  _sectionTitle('Gage de garantie'),
                  Text(
                    'Prélevé sur votre wallet Oli et bloqué pendant l\'examen. Il vous est rendu si votre '
                    'candidature est refusée, et reste bloqué comme garantie si elle est acceptée.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  _field(
                    controller: _pledgeController,
                    label: 'Montant du gage (FC)',
                    icon: Icons.lock_outline,
                    keyboardType: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    suffix: 'FC',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _walletBalance == null
                        ? 'Minimum $_minPledgeFc FC'
                        : 'Solde disponible : ${_formatFc(_walletBalance!)} · minimum $_minPledgeFc FC',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 28),
                  _sectionTitle('Motivation (optionnel)'),
                  _field(
                    controller: _motivationController,
                    label: 'Pourquoi souhaitez-vous devenir livreur ?',
                    maxLines: 3,
                  ),

                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: _changePhone,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Changer de numéro'),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Retour à la saisie du numéro. Un simple context.go('/login') ne suffit pas :
  /// la session ouverte renverrait aussitôt vers ce formulaire.
  Future<void> _changePhone() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  /// La candidature est liée à ce numéro : il est affiché en premier pour éviter
  /// de postuler avec une session restée ouverte sur un autre compte.
  Widget _buildConnectedPhone() {
    final phone = ref.watch(authControllerProvider).userData?['phone']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_iphone, color: _primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Candidature au nom du numéro', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(
                  phone.isEmpty ? 'Numéro inconnu' : phone,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _changePhone, child: const Text('Changer')),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(Icons.delivery_dining, size: 56, color: _primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Devenir Livreur Oli',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primary),
          ),
          const SizedBox(height: 8),
          Text(
            'Rejoignez notre équipe de livreurs et commencez à gagner dès aujourd\'hui',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvantages() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.stars, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text('Avantages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          _buildAdvantage('Gagnez des commissions sur chaque livraison'),
          _buildAdvantage('Horaires flexibles — travaillez quand vous voulez'),
          _buildAdvantage('Wallet intégré avec retrait Mobile Money'),
          _buildAdvantage('Notifications en temps réel pour les commandes'),
        ],
      ),
    );
  }

  Widget _buildIdDocumentPicker() {
    final preview = _idDocumentPreview;
    return InkWell(
      onTap: _chooseIdDocumentSource,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: preview == null ? Colors.grey.shade300 : _primary),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 48,
                child: preview == null
                    ? Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.badge_outlined, color: Colors.grey),
                      )
                    : Image.memory(preview, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview == null ? "Photo de la pièce d'identité" : 'Pièce ajoutée',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    preview == null ? "Carte d'électeur, passeport ou permis" : 'Touchez pour la changer',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(preview == null ? Icons.add_a_photo_outlined : Icons.check_circle,
                color: preview == null ? Colors.grey : Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submit,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.send),
        label: Text(
          _isSubmitting ? 'Envoi en cours...' : 'Soumettre ma candidature',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    TextCapitalization capitalization = TextCapitalization.sentences,
    String? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixText: suffix,
        filled: true,
        fillColor: Colors.white,
        border: border(Colors.grey.shade300),
        enabledBorder: border(Colors.grey.shade300),
        focusedBorder: border(_primary, 2),
      ),
    );
  }

  Widget _buildAdvantage(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

String _formatFc(num amount) {
  final digits = amount.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]} ',
      );
  return '$digits FC';
}
