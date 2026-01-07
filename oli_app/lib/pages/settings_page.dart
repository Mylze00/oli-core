import 'package:flutter/material.dart';

/// Page "Paramètres"
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  String _selectedLanguage = 'Français';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- COMPTE ---
          _buildSectionTitle('Compte'),
          _buildCard([
            _buildListTile(
              icon: Icons.person_outline,
              title: 'Modifier le profil',
              subtitle: 'Nom, photo, informations',
              onTap: () => _showEditProfileDialog(),
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.lock_outline,
              title: 'Changer le mot de passe',
              onTap: () => _showChangePasswordDialog(),
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.email_outlined,
              title: 'Changer l\'email',
              subtitle: 'user@email.com',
              onTap: () => _showChangeEmailDialog(),
            ),
          ]),

          const SizedBox(height: 24),

          // --- NOTIFICATIONS ---
          _buildSectionTitle('Notifications'),
          _buildCard([
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined, color: Colors.blueAccent),
              title: const Text('Notifications push', style: TextStyle(color: Colors.white)),
              value: _notificationsEnabled,
              onChanged: (v) => setState(() => _notificationsEnabled = v),
              activeColor: Colors.blueAccent,
            ),
            _buildDivider(),
            SwitchListTile(
              secondary: const Icon(Icons.mail_outline, color: Colors.orange),
              title: const Text('Notifications email', style: TextStyle(color: Colors.white)),
              value: _emailNotifications,
              onChanged: (v) => setState(() => _emailNotifications = v),
              activeColor: Colors.blueAccent,
            ),
            _buildDivider(),
            SwitchListTile(
              secondary: const Icon(Icons.sms_outlined, color: Colors.green),
              title: const Text('Notifications SMS', style: TextStyle(color: Colors.white)),
              value: _smsNotifications,
              onChanged: (v) => setState(() => _smsNotifications = v),
              activeColor: Colors.blueAccent,
            ),
          ]),

          const SizedBox(height: 24),

          // --- PRÉFÉRENCES ---
          _buildSectionTitle('Préférences'),
          _buildCard([
            _buildListTile(
              icon: Icons.language,
              title: 'Langue',
              trailing: Text(_selectedLanguage, style: const TextStyle(color: Colors.grey)),
              onTap: () => _showLanguageDialog(),
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.attach_money,
              title: 'Devise',
              trailing: const Text('USD (\$)', style: TextStyle(color: Colors.grey)),
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 24),

          // --- CONFIDENTIALITÉ ---
          _buildSectionTitle('Confidentialité et Sécurité'),
          _buildCard([
            _buildListTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Politique de confidentialité',
              onTap: () => _showPrivacyPolicy(),
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.description_outlined,
              title: 'Conditions d\'utilisation',
              onTap: () => _showTerms(),
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.delete_outline,
              title: 'Supprimer mon compte',
              titleColor: Colors.red,
              onTap: () => _showDeleteAccountDialog(),
            ),
          ]),

          const SizedBox(height: 24),

          // --- APP INFO ---
          _buildSectionTitle('Application'),
          _buildCard([
            _buildListTile(
              icon: Icons.info_outline,
              title: 'Version',
              trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
              onTap: () {},
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.cached,
              title: 'Vider le cache',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache vidé')),
                );
              },
            ),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? Colors.blueAccent),
      title: Text(title, style: TextStyle(color: titleColor ?? Colors.white)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)) : null,
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: Colors.white10, indent: 56);
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: 'Utilisateur');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Modifier le profil', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Nom',
            labelStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour')));
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Changer le mot de passe', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPasswordField('Mot de passe actuel'),
            const SizedBox(height: 12),
            _buildPasswordField('Nouveau mot de passe'),
            const SizedBox(height: 12),
            _buildPasswordField('Confirmer'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Changer')),
        ],
      ),
    );
  }

  Widget _buildPasswordField(String label) {
    return TextField(
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showChangeEmailDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Changer l\'email', style: TextStyle(color: Colors.white)),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Nouvel email',
            labelStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Enregistrer')),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Choisir la langue', style: TextStyle(color: Colors.white)),
        children: ['Français', 'English', 'Español', 'العربية', 'Lingala'].map((lang) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() => _selectedLanguage = lang);
              Navigator.pop(context);
            },
            child: Row(
              children: [
                if (lang == _selectedLanguage) const Icon(Icons.check, color: Colors.blueAccent, size: 18),
                if (lang != _selectedLanguage) const SizedBox(width: 18),
                const SizedBox(width: 12),
                Text(lang, style: const TextStyle(color: Colors.white)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showPrivacyPolicy() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _PolicyPage(title: 'Politique de confidentialité')));
  }

  void _showTerms() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _PolicyPage(title: 'Conditions d\'utilisation')));
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Supprimer le compte', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Cette action est irréversible. Toutes vos données seront supprimées.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _PolicyPage extends StatelessWidget {
  final String title;
  const _PolicyPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
          'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
          'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris '
          'nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in '
          'reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla '
          'pariatur. Excepteur sint occaecat cupidatat non proident, sunt in '
          'culpa qui officia deserunt mollit anim id est laborum.\n\n'
          '• Protection des données personnelles\n'
          '• Utilisation des cookies\n'
          '• Droits des utilisateurs\n'
          '• Politique de remboursement\n'
          '• Responsabilités\n\n'
          'Pour toute question, contactez-nous à support@oli.com',
          style: const TextStyle(color: Colors.white70, height: 1.6),
        ),
      ),
    );
  }
}
