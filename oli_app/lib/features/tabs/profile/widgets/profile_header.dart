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
import '../../../../core/providers/location_provider.dart';

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
          child: Consumer(
            builder: (context, ref, child) {
              final locationAsync = ref.watch(userLocationProvider);
              final defaultAddr = ref.watch(defaultAddressProvider);
              final fallbackCity = defaultAddr?.ville ?? user['city']?.toString() ?? "Kinshasa";

              String displayText = fallbackCity;
              if (locationAsync is AsyncData && locationAsync.value != null) {
                final parts = locationAsync.value!.split(',');
                displayText = parts.last.trim(); // Get just the city/town part for the badge
              }

              return GestureDetector(
                onTap: () => ref.refresh(userLocationProvider), // Permet de rafraîchir en cliquant
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (locationAsync is AsyncLoading)
                        const SizedBox(
                          width: 14, 
                          height: 14, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                        )
                      else
                        const Icon(Icons.location_on, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        displayText.isEmpty ? "Kinshasa" : displayText, 
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 10), // Espace pour descendre l'avatar

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
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: AutoRefreshAvatar(
              avatarUrl: user['avatar_url'], 
              size: 80,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF1E2430),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection(BuildContext context, WidgetRef ref) {
    final badgeType = VerificationBadge.fromUser(user);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              (user["username"] ?? user["name"] ?? "Utilisateur Oli").toString().toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (badgeType != null) ...[
              const SizedBox(width: 4),
              VerificationBadge(type: badgeType, size: 16),
            ],
            const SizedBox(width: 4),
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
        if (user["bio"] != null && user["bio"].toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  user["bio"].toString(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                _buildAddressDisplay(user),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 6),
          _buildAddressDisplay(user),
        ],
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

  Widget _buildAddressDisplay(Map<String, dynamic> user) {
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
        
        final city = user['city']?.toString();
        
        return Text(
          city != null && city.isNotEmpty ? "📍 $city" : "📍 Kinshasa, Gombe",
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
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
