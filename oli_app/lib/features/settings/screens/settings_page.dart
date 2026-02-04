import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../config/api_config.dart';
import '../../../core/user/user_provider.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/biometric_service.dart';
import '../../../providers/exchange_rate_provider.dart';

/// Page "Paramètres"
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  Future<void> _loadBiometricSettings() async {
    final isEnabled = await _biometricService.isBiometricEnabled();
    final isAvailable = await _biometricService.canCheckBiometrics();
    if (mounted) {
      setState(() {
        _biometricEnabled = isEnabled;
        _biometricAvailable = isAvailable;
      });
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      // Si on active, vérifier d'abord que l'appareil supporte la biométrie
      final isSupported = await _biometricService.isDeviceSupported();
      if (!isSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La biométrie n\'est pas disponible sur cet appareil'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Authentifier pour confirmer l'activation
      final authenticated = await _biometricService.authenticate(
        reason: 'Confirmez votre identité pour activer la biométrie',
      );
      
      if (!authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentification échouée'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // Sauvegarder le choix
    await _biometricService.setBiometricEnabled(enable);
    setState(() => _biometricEnabled = enable);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enable ? 'Biométrie activée' : 'Biométrie désactivée'),
        backgroundColor: enable ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final exchangeState = ref.watch(exchangeRateProvider);
    final String selectedCurrency = exchangeState.selectedCurrency.code;
    final String selectedLanguage = 'Français'; // TODO: Make dynamic later
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Paramètres'),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.white))),
        data: (user) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- COMPTE ---
            _buildSectionTitle('Compte'),
            _buildCard([
              _buildListTile(
                icon: Icons.person_outline,
                title: 'Modifier le profil',
                subtitle: user.name,
                onTap: () => _showEditProfileDialog(user.name),
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.lock_outline,
                title: 'Changer le mot de passe',
                onTap: () => _showChangePasswordDialog(),
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.phone_android,
                title: 'Numéro de téléphone',
                subtitle: user.phone ?? 'Non défini',
                onTap: () {},
              ),
            ]),

            const SizedBox(height: 24),

            // --- SÉCURITÉ BIOMÉTRIQUE ---
            _buildSectionTitle('Sécurité'),
            _buildCard([
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint, color: Colors.green),
                title: const Text('Connexion biométrique', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  _biometricAvailable 
                    ? 'Face ID / Empreinte digitale' 
                    : 'Non disponible sur cet appareil',
                  style: TextStyle(
                    color: _biometricAvailable ? Colors.grey : Colors.orange,
                    fontSize: 12,
                  ),
                ),
                value: _biometricEnabled,
                onChanged: _biometricAvailable ? _toggleBiometric : null,
                activeColor: Colors.green,
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
                trailing: Text(selectedLanguage, style: const TextStyle(color: Colors.grey)),
                onTap: () => _showLanguageDialog(),
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.attach_money,
                title: 'Devise',
                trailing: Text(selectedCurrency, style: const TextStyle(color: Colors.grey)),
                onTap: () => _showCurrencyDialog(),
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
      ), // end ListView
      ), // end data callback
    ); // end Scaffold
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

  void _showEditProfileDialog(String currentName) {
    final nameController = TextEditingController(text: currentName);
    bool isLoading = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext), 
              child: const Text('Annuler')
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le nom ne peut pas être vide'), backgroundColor: Colors.red),
                  );
                  return;
                }
                
                setDialogState(() => isLoading = true);
                
                try {
                  final token = await SecureStorageService().getToken();
                  final response = await http.post(
                    Uri.parse('${ApiConfig.baseUrl}/auth/update-profile'),
                    headers: {
                      'Content-Type': 'application/json',
                      if (token != null) 'Authorization': 'Bearer $token',
                    },
                    body: jsonEncode({'name': newName}),
                  );
                  
                  if (response.statusCode == 200) {
                    Navigator.pop(dialogContext);
                    // Rafraîchir les données utilisateur
                    ref.invalidate(userProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profil mis à jour !'), backgroundColor: Colors.green),
                    );
                  } else {
                    final error = jsonDecode(response.body)['error'] ?? 'Erreur inconnue';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $error'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur réseau: $e'), backgroundColor: Colors.red),
                  );
                } finally {
                  setDialogState(() => isLoading = false);
                }
              },
              child: isLoading 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Mot de passe', style: TextStyle(color: Colors.white)),
        content: const Text(
          'La connexion OLI utilise uniquement la vérification par SMS (OTP).\n\nVotre compte est sécurisé par votre numéro de téléphone.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Compris')
          ),
        ],
      ),
    );
  }

  void _showCurrencyDialog() {
    // Import Currency from exchange_rate_provider.dart
    final currencies = [Currency.USD, Currency.CDF];
    final currentCurrency = ref.read(exchangeRateProvider).selectedCurrency;
    
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Choisir la devise', style: TextStyle(color: Colors.white)),
        children: currencies.map((currency) {
          final isSelected = currency == currentCurrency;
          return SimpleDialogOption(
            onPressed: () {
              ref.read(exchangeRateProvider.notifier).setCurrency(currency);
              Navigator.pop(context);
            },
            child: Row(
              children: [
                if (isSelected) const Icon(Icons.check, color: Colors.blueAccent, size: 18),
                if (!isSelected) const SizedBox(width: 18),
                const SizedBox(width: 12),
                Text('${currency.name} (${currency.symbol})', style: const TextStyle(color: Colors.white)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Langue', style: TextStyle(color: Colors.white)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Row(
              children: [
                Icon(Icons.check, color: Colors.blueAccent, size: 18),
                SizedBox(width: 12),
                Text('Français', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SimpleDialogOption(
            child: Row(
              children: [
                SizedBox(width: 18),
                SizedBox(width: 12),
                Text('English (Bientôt)', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
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
