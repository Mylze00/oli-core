import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/verification_badge.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
import '../../../user/providers/profile_controller.dart';
import '../../../user/widgets/edit_name_dialog.dart';
import '../../../user/providers/address_provider.dart';
import '../../../settings/screens/settings_page.dart';
import '../../../../config/api_config.dart';
import 'package:oli_app/features/tabs/profile/screens/verification_landing_page.dart';
import 'avatar_preview_dialog.dart';

class ProfileHeader extends ConsumerWidget {
  final Map<String, dynamic> user;

  const ProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // Settings icon top-right
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.settings, color: Colors.white70, size: 22),
          ),
        ),
        // Main content centered
        Column(
          children: [
            _buildAvatarSection(context, ref),
            const SizedBox(height: 14),
            _buildUserInfoSection(context, ref),
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
    final badgeType = VerificationBadge.fromUser(user);

    if (badgeType == null) return const SizedBox.shrink();

    return Positioned(
      bottom: -6,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2), // White border for visibility
            color: Colors.white,
          ),
          child: VerificationBadge(
            type: badgeType,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
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
              icon: const Icon(Icons.edit, color: Colors.white70, size: 16),
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
        const SizedBox(height: 4),
        Text(
          user["phone"] ?? "Non renseigné",
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        _buildBadgesRow(),
        const SizedBox(height: 6),
        _buildAddressDisplay(),
        if (user['is_verified'] != true && user['account_type'] == 'ordinaire') ...[
           const SizedBox(height: 12),
           GestureDetector(
             onTap: () => Navigator.push(
               context, 
               MaterialPageRoute(builder: (_) => const VerificationLandingPage()) 
             ),
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(20),
                 border: Border.all(color: Colors.blue, width: 1.5),
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: const [
                   Icon(Icons.verified, size: 14, color: Colors.blue),
                   SizedBox(width: 6),
                   Text("Obtenir la certification", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                 ],
               ),
             ),
           ),
        ]
      ],
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
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 12),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  defaultAddr.fullAddress,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        }
        return const Text(
          "Pas d'adresse enregistrée",
          style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
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
