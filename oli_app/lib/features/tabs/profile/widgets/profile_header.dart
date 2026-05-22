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
    return Column(
      children: [
        // Top Bar (Location Badge aligned to right)
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  "Kinshasa", 
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 30), // Espace pour descendre l'avatar

        // Main content centered
        Column(
          children: [
            _buildAvatarSection(context, ref),
            const SizedBox(height: 12),
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
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(
              (user["name"] ?? "Utilisateur Oli").toString().toUpperCase(),
              style: const TextStyle(
                color: Colors.white, // Modifié pour être visible sur tous les fonds
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0C2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars, size: 12, color: Color(0xFFD4A500)),
                  SizedBox(width: 3),
                  Text(
                    "GOLD MEMBRE",
                    style: TextStyle(
                      color: Color(0xFFD4A500),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70, size: 18),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "Bio: Entrepreneur passionné | Tech & Business",
          style: TextStyle(
            color: Colors.white.withOpacity(0.8), // Modifié pour mode sombre
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        _buildAddressDisplay(),
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
          "📍 Kinshasa, Gombe",
          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
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
