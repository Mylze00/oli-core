import 'package:flutter/material.dart';

/// Page "À propos d'Oli"
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('À propos d\'Oli'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --- LOGO ---
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blueAccent, Colors.purpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text('OLI', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
              ),
            ),

            const SizedBox(height: 24),

            // --- NOM ET VERSION ---
            const Text('Oli Marketplace', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Version 1.0.0', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
            ),

            const SizedBox(height: 32),

            // --- DESCRIPTION ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Oli est une marketplace moderne qui connecte acheteurs et vendeurs '
                'dans un environnement sécurisé et intuitif. Notre mission est de '
                'faciliter le commerce entre particuliers tout en garantissant '
                'des transactions sûres et transparentes.\n\n'
                '🛒 Achetez en toute confiance\n'
                '💰 Vendez facilement\n'
                '🔒 Paiements sécurisés\n'
                '📦 Livraison suivie',
                style: TextStyle(color: Colors.white70, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // --- STATISTIQUES ---
            Row(
              children: [
                Expanded(child: _buildStatCard('10K+', 'Utilisateurs')),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('50K+', 'Produits')),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('99%', 'Satisfaction')),
              ],
            ),

            const SizedBox(height: 32),

            // --- ÉQUIPE ---
            _buildSectionTitle('Notre Équipe'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildTeamMember('Paolice', 'Fondateur & CEO', Icons.person),
                  const Divider(color: Colors.white10),
                  _buildTeamMember('Équipe Tech', 'Développement', Icons.code),
                  const Divider(color: Colors.white10),
                  _buildTeamMember('Support', 'Service Client', Icons.headset_mic),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- RÉSEAUX SOCIAUX ---
            _buildSectionTitle('Suivez-nous'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton(Icons.facebook, Colors.blue),
                const SizedBox(width: 16),
                _buildSocialButton(Icons.camera_alt, Colors.pink),
                const SizedBox(width: 16),
                _buildSocialButton(Icons.alternate_email, Colors.lightBlue),
                const SizedBox(width: 16),
                _buildSocialButton(Icons.link, Colors.blueGrey),
              ],
            ),

            const SizedBox(height: 32),

            // --- LIENS LÉGAUX ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildLinkTile('Politique de confidentialité', Icons.privacy_tip_outlined),
                  const Divider(color: Colors.white10),
                  _buildLinkTile('Conditions d\'utilisation', Icons.description_outlined),
                  const Divider(color: Colors.white10),
                  _buildLinkTile('Licences open source', Icons.code),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- COPYRIGHT ---
            Text(
              '© 2024 Oli. Tous droits réservés.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.blueAccent, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTeamMember(String name, String role, IconData icon) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blueAccent.withOpacity(0.2),
        child: Icon(icon, color: Colors.blueAccent),
      ),
      title: Text(name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(role, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    );
  }

  Widget _buildSocialButton(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildLinkTile(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
      onTap: () {},
    );
  }
}
