import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/user/user_provider.dart';

class IdentityVerificationPage extends ConsumerWidget {
  const IdentityVerificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Statut du compte'),
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Non connecté', style: TextStyle(color: Colors.white)));
          }

          if (user.isVerified) {
            return _buildVerifiedState();
          } else {
            return _buildUnverifiedState(context);
          }
        },
      ),
    );
  }

  Widget _buildVerifiedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user, color: Colors.green, size: 80),
          const SizedBox(height: 16),
          const Text(
            'Compte Vérifié',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Votre identité a été confirmée avec succès.\nVous avez accès à toutes les fonctionnalités d\'OLI.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildUnverifiedState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.shield_outlined, color: Colors.orange, size: 80),
          const SizedBox(height: 16),
          const Text(
            'Vérification d\'identité',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pour débloquer toutes les fonctionnalités et sécuriser la plateforme, veuillez vérifier votre identité en fournissant une pièce d\'identité officielle.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 40),
          _buildUploadOption(context, Icons.badge, 'Carte d\'électeur', 'Recommandé'),
          const SizedBox(height: 16),
          _buildUploadOption(context, Icons.book, 'Passeport', null),
          const SizedBox(height: 16),
          _buildUploadOption(context, Icons.directions_car, 'Permis de conduire', null),
        ],
      ),
    );
  }

  Widget _buildUploadOption(BuildContext context, IconData icon, String title, String? badge) {
    return InkWell(
      onTap: () {
        // Logique de sélection de fichier à implémenter
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Ouverture de l\'appareil photo pour $title...'))
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueAccent, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                  if (badge != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text(badge, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.camera_alt, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
