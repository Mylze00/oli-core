import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/verification_badge.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
import '../../../user/providers/profile_controller.dart';
import '../../../user/widgets/edit_name_dialog.dart';
import '../../../user/providers/address_provider.dart';
import '../../../settings/screens/settings_page.dart';
import '../../../../config/api_config.dart';

class ProfileHeader extends ConsumerWidget {
  final Map<String, dynamic> user;

  const ProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Row(
          children: [
            // Avatar with Badge
            GestureDetector(
              onTap: () => ref.read(profileControllerProvider.notifier).updateAvatar(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AutoRefreshAvatar(
                    avatarUrl: user['avatar_url'],
                    size: 70,
                  ),
                  Positioned(
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
                  ),
                  // Verification Badge Overlay
                  if (user['is_verified'] == true || user['account_type'] != 'ordinaire' || user['has_certified_shop'] == true)
                    Positioned(
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
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // User Info & Badges
            Expanded(
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
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => EditNameDialog(
                              currentName: user["name"] ?? "Utilisateur Oli",
                            ),
                          );
                        },
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Phone Number
                  Text(
                    user["phone"] ?? "Non renseigné",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13, 
                      fontWeight: FontWeight.w500
                    ),
                  ),

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (user['account_type'] == 'entreprise' || user['has_certified_shop'] == true)
                         _buildBadge('Entreprise', const Color(0xFFD4A500).withOpacity(0.2), const Color(0xFFD4A500)),
                      
                      if (user['account_type'] == 'premium')
                         _buildBadge('Premium ⭐', const Color(0xFF00BA7C).withOpacity(0.2), const Color(0xFF00BA7C)),

                      if (user['is_seller'] == true) ...[
                         const SizedBox(width: 8),
                         _buildBadge('Vendeur', Colors.white24),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Default Address
                  Consumer(
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
                  ),
                ],
              ),
            ),
            
            // Settings Icon
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
              icon: const Icon(Icons.settings, color: Colors.white),
            ),
          ],
        ),
      ],
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
