import 'package:flutter/material.dart';

/// Page "Aide et Support"
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Aide et Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- RECHERCHE ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher dans l\'aide...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                icon: Icon(Icons.search, color: Colors.grey),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- ACTIONS RAPIDES ---
          Row(
            children: [
              Expanded(child: _buildQuickAction(context, Icons.chat_bubble_outline, 'Chat', Colors.blueAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildQuickAction(context, Icons.email_outlined, 'Email', Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildQuickAction(context, Icons.phone_outlined, 'Appel', Colors.green)),
            ],
          ),

          const SizedBox(height: 24),

          // --- FAQ ---
          _buildSectionTitle('Questions fréquentes'),
          _buildFaqCard([
            _FaqItem(
              question: 'Comment passer une commande ?',
              answer: 'Parcourez le marché, sélectionnez un produit, choisissez la quantité et cliquez sur "Acheter maintenant". Suivez les étapes de paiement pour finaliser votre commande.',
            ),
            _FaqItem(
              question: 'Comment suivre ma livraison ?',
              answer: 'Allez dans "Mes Achats" depuis votre profil. Cliquez sur une commande en cours pour voir le suivi en temps réel.',
            ),
            _FaqItem(
              question: 'Comment demander un remboursement ?',
              answer: 'Contactez le vendeur via la messagerie. Si aucun accord n\'est trouvé, ouvrez un litige via "Mes Achats" > "Signaler un problème".',
            ),
            _FaqItem(
              question: 'Comment ajouter un moyen de paiement ?',
              answer: 'Depuis votre profil, accédez à "Paiements et Services" puis "Ajouter Carte VISA" ou "Ajouter Compte Bancaire".',
            ),
            _FaqItem(
              question: 'Comment vendre un produit ?',
              answer: 'Appuyez sur le bouton "+" en bas de l\'écran ou allez dans "Mettre en vente un objet" depuis votre profil. Remplissez les informations et publiez.',
            ),
          ]),

          const SizedBox(height: 24),

          // --- CATÉGORIES D'AIDE ---
          _buildSectionTitle('Catégories d\'aide'),
          _buildHelpCategories(context),

          const SizedBox(height: 24),

          // --- FORMULAIRE CONTACT ---
          _buildSectionTitle('Nous contacter'),
          _buildContactForm(context),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label - Fonctionnalité à venir')));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFaqCard(List<_FaqItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: items.map((item) => ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: Colors.blueAccent,
          collapsedIconColor: Colors.grey,
          title: Text(item.question, style: const TextStyle(color: Colors.white, fontSize: 14)),
          children: [
            Text(item.answer, style: const TextStyle(color: Colors.grey, height: 1.5)),
          ],
        )).toList(),
      ),
    );
  }

  Widget _buildHelpCategories(BuildContext context) {
    final categories = [
      {'icon': Icons.shopping_bag_outlined, 'label': 'Commandes', 'color': Colors.blue},
      {'icon': Icons.local_shipping_outlined, 'label': 'Livraison', 'color': Colors.orange},
      {'icon': Icons.payment_outlined, 'label': 'Paiements', 'color': Colors.green},
      {'icon': Icons.store_outlined, 'label': 'Vendre', 'color': Colors.purple},
      {'icon': Icons.security_outlined, 'label': 'Sécurité', 'color': Colors.red},
      {'icon': Icons.account_circle_outlined, 'label': 'Compte', 'color': Colors.teal},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aide ${cat['label']}'))),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 28),
                const SizedBox(height: 8),
                Text(cat['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sujet', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            dropdownColor: const Color(0xFF2A2A2A),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(color: Colors.white),
            items: ['Problème de commande', 'Problème de paiement', 'Signaler un vendeur', 'Autre'].map((s) {
              return DropdownMenuItem(value: s, child: Text(s));
            }).toList(),
            onChanged: (v) {},
          ),
          const SizedBox(height: 16),
          const Text('Message', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Décrivez votre problème...',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message envoyé ! Nous répondrons sous 24h.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Envoyer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  _FaqItem({required this.question, required this.answer});
}
