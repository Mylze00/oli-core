import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/verification_badge.dart';
import '../providers/verification_controller.dart';

class VerificationLandingPage extends ConsumerWidget {
  const VerificationLandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Certification Oli"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildHeader(),
            const SizedBox(height: 40),
            _buildPlanCard(
              context,
              title: "Oli Certifié",
              price: "4.99\$ / mois",
              features: [
                "Badge bleu sur votre profil",
                "Priorité dans les recherches",
                "Support prioritaire 24/7",
              ],
              badgeType: BadgeType.blue,
              onTap: () async {
                 // Simulation simple flow
                 final success = await ref.read(verificationControllerProvider.notifier)
                     .upgradePlan('certified', 'orange_money'); // Mock payment method
                 
                 if (context.mounted) {
                   if (success) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Félicitations ! Vous êtes certifié.")));
                     Navigator.pop(context); // Retour au profil
                   } else {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de l'abonnement.")));
                   }
                 }
              },
            ),
            const SizedBox(height: 20),
            _buildPlanCard(
              context,
              title: "Oli Entreprise",
              price: "39\$ / mois",
              features: [
                "Badge doré exclusif",
                "Certification légale de votre entreprise",
                "Outils d'analyses avancés",
                "Gestion multi-utilisateurs"
              ],
              badgeType: BadgeType.gold,
              isPremium: true,
              onTap: () async {
                 // Simulation simple flow
                 final success = await ref.read(verificationControllerProvider.notifier)
                     .upgradePlan('enterprise', 'card'); // Mock payment method
                 
                 if (context.mounted) {
                   if (success) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Félicitations ! Votre entreprise est vérifiée.")));
                     Navigator.pop(context);
                   } else {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de l'abonnement.")));
                   }
                 }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: const [
        Text(
          "Renforcez votre crédibilité",
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 12),
        Text(
          "Obtenez un badge de vérification et débloquez des fonctionnalités exclusives pour votre compte ou votre entreprise.",
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String price,
    required List<String> features,
    required BadgeType badgeType,
    required VoidCallback onTap,
    bool isPremium = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: isPremium ? Border.all(color: Colors.amber, width: 2) : Border.all(color: Colors.white10),
        boxShadow: isPremium ? [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 20)] : [],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(price, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
               VerificationBadge(type: badgeType, size: 40),
            ],
          ),
          const Divider(color: Colors.white24, height: 32),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.check, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text(f, style: const TextStyle(color: Colors.white, fontSize: 14))),
              ],
            ),
          )),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium ? Colors.amber : Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isPremium ? "Devenir Entreprise" : "Obtenir la Certification",
              style: TextStyle(color: isPremium ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
