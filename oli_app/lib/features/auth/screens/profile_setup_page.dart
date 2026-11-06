import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/auth_controller.dart';
import '../../user/providers/profile_controller.dart';
import '../../user/providers/address_provider.dart';
import '../../user/models/address_model.dart';
import '../../home/home_page.dart';
import '../../../core/storage/secure_storage_service.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  final String phone;

  const ProfileSetupPage({super.key, required this.phone});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  static const Color oliBlue = Color(0xFF1E7DBA);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _avatarBytes;
  String? _avatarFileName;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _avatarBytes = bytes;
          _avatarFileName = image.name.isNotEmpty ? image.name : 'avatar.jpg';
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur sélection image : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de charger l\'image')),
        );
      }
    }
  }

  void _showImageSourceActionSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF182229) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: oliBlue),
                title: Text(
                  'Prendre une photo',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: oliBlue),
                title: Text(
                  'Choisir depuis la galerie',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_avatarBytes != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text(
                    'Supprimer la photo',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _avatarBytes = null;
                      _avatarFileName = null;
                    });
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _skip() async {
    final storage = ref.read(secureStorageProvider);
    await storage.setOnboardingCompleted(widget.phone);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final addressText = _addressController.text.trim();

    setState(() => _isLoading = true);

    try {
      // 1. Upload de la photo si sélectionnée
      if (_avatarBytes != null && _avatarFileName != null) {
        try {
          await ref.read(profileControllerProvider.notifier).uploadAvatarImage(
                _avatarBytes!,
                _avatarFileName!,
              );
        } catch (e) {
          debugPrint("⚠️ Échec upload avatar (continué) : $e");
        }
      }

      // 2. Mise à jour du nom si renseigné
      if (name.isNotEmpty) {
        try {
          await ref.read(profileControllerProvider.notifier).updateUserName(name);
        } catch (e) {
          debugPrint("⚠️ Échec mise à jour nom : $e");
          ref.read(authControllerProvider.notifier).updateUserData({'name': name});
        }
      }

      // 3. Enregistrement de l'adresse si renseignée
      if (addressText.isNotEmpty) {
        try {
          await ref.read(addressProvider.notifier).addAddress(
                Address(
                  address: addressText,
                  label: 'Maison',
                  city: 'Kinshasa',
                  phone: widget.phone,
                  isDefault: true,
                ),
              );
        } catch (e) {
          debugPrint("⚠️ Échec enregistrement adresse : $e");
        }
      }

      // 4. Marquer le parcours d'onboarding comme terminé
      final storage = ref.read(secureStorageProvider);
      await storage.setOnboardingCompleted(widget.phone);

      if (!mounted) return;

      // 5. Redirection finale vers HomePage
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } catch (e) {
      debugPrint("❌ Erreur générale soumission profil : $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0B141A) : const Color(0xFFF7F8FA);
    final cardColor = isDark ? const Color(0xFF182229) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _skip,
            child: Text(
              'Passer',
              style: TextStyle(
                color: subtextColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // 🏷️ Titre & sous-titre
              Text(
                'Créez votre profil',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Ajoutez votre photo, votre nom et votre adresse habituelle pour faciliter vos commandes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: subtextColor,
                ),
              ),

              const SizedBox(height: 32),

              // 📸 Avatar de profil interactif
              Center(
                child: Stack(
                  children: [
                    InkWell(
                      onTap: _showImageSourceActionSheet,
                      borderRadius: BorderRadius.circular(60),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF1E2A32) : const Color(0xFFE9F3FA),
                          border: Border.all(
                            color: oliBlue.withValues(alpha: 0.4),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: oliBlue.withValues(alpha: 0.15),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _avatarBytes != null
                              ? Image.memory(
                                  _avatarBytes!,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                )
                              : Icon(
                                  Icons.person,
                                  size: 64,
                                  color: oliBlue.withValues(alpha: 0.6),
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _showImageSourceActionSheet,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: oliBlue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: bgColor,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // 📝 Champ Nom / Pseudo
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: textColor, fontSize: 15),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline, color: oliBlue),
                    hintText: 'Votre nom ou pseudo',
                    hintStyle: TextStyle(color: subtextColor, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 📍 Champ Adresse habituelle
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: TextField(
                  controller: _addressController,
                  maxLines: 2,
                  style: TextStyle(color: textColor, fontSize: 15),
                  decoration: InputDecoration(
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Icon(Icons.location_on_outlined, color: oliBlue),
                    ),
                    hintText: 'Adresse habituelle (Avenue, Quartier, Commune, Ville)',
                    hintStyle: TextStyle(color: subtextColor, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // 🔘 Bouton principal "Terminer et continuer"
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: oliBlue,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: oliBlue.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Terminer et continuer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
