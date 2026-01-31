import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/verification_badge.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
import '../../../user/providers/profile_controller.dart';
import '../../../user/widgets/edit_name_dialog.dart';
import '../../../user/providers/address_provider.dart';
import '../../../settings/screens/settings_page.dart';
import '../../../../config/api_config.dart';
import 'avatar_preview_dialog.dart';

class ProfileHeader extends ConsumerWidget {
  final Map<String, dynamic> user;

  const ProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Optionnel: Écouter les changements globaux du profil pour rafraîchir l'UI
    // final latestUser = ref.watch(profileControllerProvider).value ?? user;

    return Column(
      children: [
        Row(
          children: [
            _buildAvatarSection(context, ref),
            const SizedBox(width: 16),
            _buildUserInfoSection(context, ref),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
              icon: const Icon(Icons.settings, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarSection(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final notifier = ref.read(profileControllerProvider.notifier);
        final imageData = await notifier.pickAvatarImage();
        
        if (imageData == null || !context.mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AvatarPreviewDialog(
            imageBytes: imageData['bytes'],
            imageName: imageData['name'],
            onConfirm: () {
              Navigator.pop(dialogContext);
              // L'upload devrait idéalement déclencher un état de chargement
              ref.read(profileControllerProvider.notifier).uploadAvatarImage(
                imageData['bytes'],
                imageData['name'],
              );
            },
            onCancel: () => Navigator.pop(dialogContext),
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AutoRefreshAvatar(
            // Utilise une clé unique ou l'URL pour forcer le rafraîchissement
            avatarUrl: user['avatar_url'], 
            size: 70,
          ),
          _buildCameraIcon(),
          _buildVerificationBadge(),
        ],
      ),
    );
  }

  Widget _buildCameraIcon() {
    return Positioned(
      bottom: 0,
      left: 0,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.amber,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.camera_alt, size: 12, color: Colors.black),
      ),
    );
  }

  Widget _buildVerificationBadge() {
    final bool isEligible = user['is_verified'] == true || 
                            user['account_type'] != 'ordinaire' || 
                            user['has_certified_shop'] == true;

    if (!isEligible) return const SizedBox.shrink();

    return Positioned(
      bottom: -5,
      right: -2,
      child: VerificationBadge(
        type: VerificationBadge.fromSellerData(
          isVerified: user['is_verified'] == true,
          accountType: user['account_type'] ?? 'ordinaire',
          hasCertifiedShop: user['has_certified_shop'] == true,
        ),
        size: 24,
      ),
    );
  }

  Widget _buildUserInfoSection(BuildContext context, WidgetRef ref) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  user["name"] ?? "Utilisateur Oli",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => EditNameDialog(
                    currentName: user["name"] ?? "Utilisateur Oli",
                  ),
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          Text(
            user["phone"] ?? "Non renseigné",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _buildBadgesRow(),
          const SizedBox(height: 8),
          _buildAddressDisplay(),
        ],
      ),
    );
  }

  Widget _buildBadgesRow() {
    return Wrap( // Wrap est plus sûr que Row si tu as beaucoup de badges
      spacing: 8,
      runSpacing: 4,
      children: [
        if (user['account_type'] == 'entreprise' || user['has_certified_shop'] == true)
          _buildBadge('Entreprise', const Color(0xFFD4A500).withOpacity(0.2), const Color(0xFFD4A500)),
        if (user['account_type'] == 'premium')
          _buildBadge('Premium ⭐', const Color(0xFF00BA7C).withOpacity(0.2), const Color(0xFF00BA7C)),
        if (user['is_seller'] == true)
          _buildBadge('Vendeur', Colors.white24),
      ],
    );
  }

  Widget _buildAddressDisplay() {
    return Consumer(
      builder: (context, ref, child) {
        final defaultAddr = ref.watch(defaultAddressProvider);
        if (defaultAddr != null) {
          return Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 12),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  defaultAddr.fullAddress,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }
        return const Text(
          "Pas d'adresse enregistrée",
          style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
        );
      },
    );
  }

  Widget _buildBadge(String text, Color bgColor, [Color textColor = Colors.white]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
