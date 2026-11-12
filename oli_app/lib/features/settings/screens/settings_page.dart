import 'package:flutter/material.dart';
import '../../../core/theme/oli_surface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../config/api_config.dart';
import '../../../core/user/user_provider.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/biometric_service.dart';
import '../../../core/services/hive_cache_service.dart';
import '../../../providers/exchange_rate_provider.dart';
import '../../tabs/profile/screens/identity_verification_page.dart';
import 'package:dio/dio.dart';
import '../../../core/router/network/dio_provider.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/screens/login_page.dart';
import '../../../core/theme/oli_glass.dart';

/// Page "Paramètres"
/// Couleurs des paramètres (kit commun), fixées au début de chaque construction.
late OliSurface _c;

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
    _loadNotificationPrefs();
  }

  /// Charge les préférences de notification enregistrées côté serveur.
  Future<void> _loadNotificationPrefs() async {
    try {
      final res = await ref.read(dioProvider).get(ApiConfig.userNotificationPrefs);
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = data['push'] == true;
        _emailNotifications = data['email'] == true;
        _smsNotifications = data['sms'] == true;
      });
    } catch (_) {
      // Hors ligne : on garde les valeurs par défaut
    }
  }

  /// Enregistre une préférence immédiatement. En cas d'échec, revient à la valeur précédente.
  Future<void> _setNotificationPref(
    String key,
    bool value,
    bool previous,
    void Function(bool) apply,
  ) async {
    setState(() => apply(value));
    try {
      await ref.read(dioProvider).put(
        ApiConfig.userNotificationPrefs,
        data: {key: value},
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => apply(previous));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Préférence non enregistrée, réessayez.')),
      );
    }
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
            backgroundColor: const Color(0xFF3A3A3C),
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
        backgroundColor: enable ? Colors.green : const Color(0xFF3A3A3C),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _c = OliSurface.of(context);
    final userAsync = ref.watch(userProvider);
    final exchangeState = ref.watch(exchangeRateProvider);
    final String selectedCurrency = exchangeState.selectedCurrency.code;
    final String selectedLanguage = 'Français'; // TODO: Make dynamic later
    
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'CreatoDisplay',
        ),
        appBarTheme: AppBarTheme.of(context).copyWith(
          titleTextStyle: TextStyle(
            fontFamily: 'CreatoDisplay',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _c.text,
          ),
        ),
        listTileTheme: ListTileTheme.of(context).copyWith(
          titleTextStyle: TextStyle(fontFamily: 'CreatoDisplay', fontSize: 15, color: _c.text),
          subtitleTextStyle: TextStyle(fontFamily: 'CreatoDisplay', fontSize: 12, color: _c.textSecondary),
        ),
      ),
      child: Scaffold(
        backgroundColor: _c.background,
        appBar: AppBar(
          backgroundColor: _c.background,
          elevation: 0,
          title: const Text('Paramètres', style: TextStyle(fontFamily: 'CreatoDisplay')),
        ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e', style: TextStyle(color: _c.text))),
        data: (user) {
          if (user == null) {
             return Center(child: Text('Vous devez être connecté', style: TextStyle(color: _c.text)));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
          children: [
            // --- COMPTE ---
            _buildSectionTitle('Compte'),
            _buildCard([
              _buildListTile(
                title: 'Nom d\'utilisateur',
                trailingText: '@${user.username ?? user.name}',
                onTap: () => _showEditProfileDialog(user.name, user.username, user.bio, user.city),
              ),
              _buildDivider(),
              _buildListTile(
                title: 'N° Téléphone',
                trailingText: user.phone ?? 'Non défini',
                onTap: () {},
              ),
              _buildDivider(),
              _buildListTile(
                title: 'ID',
                trailingText: user.idOli ?? 'OLI-UNKNOWN',
                showArrow: false,
                onTap: () {},
              ),
              _buildDivider(),
              _buildListTile(
                title: 'Compte',
                trailingWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(user.isVerified ? Icons.verified_user : Icons.error_outline, color: user.isVerified ? _c.success : _c.danger, size: 16),
                    const SizedBox(width: 4),
                    Text(user.isVerified ? 'Verifié' : 'Non verifié', style: TextStyle(color: user.isVerified ? _c.success : _c.danger, fontSize: 13)),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios, color: _c.textSecondary, size: 14),
                  ],
                ),
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const IdentityVerificationPage()));
                },
              ),
            ]),

            const SizedBox(height: 24),

            // --- SÉCURITÉ BIOMÉTRIQUE ---
            _buildSectionTitle('Sécurité'),
            _buildCard([
              SwitchListTile(
                secondary: Icon(Icons.fingerprint, color: _c.accent),
                title: Text('Connexion biométrique', style: TextStyle(color: _c.text, fontSize: 15, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  _biometricAvailable 
                    ? 'Face ID / Empreinte digitale' 
                    : 'Non disponible sur cet appareil',
                  style: TextStyle(
                    color: _c.textSecondary,
                    fontSize: 12,
                  ),
                ),
                value: _biometricEnabled,
                onChanged: _biometricAvailable ? _toggleBiometric : null,
                activeColor: _c.accent,
              ),
            ]),

            const SizedBox(height: 24),

            // --- NOTIFICATIONS ---
            _buildSectionTitle('Notifications'),
            _buildCard([
              SwitchListTile(
                secondary: Icon(Icons.notifications_outlined, color: _c.accent),
                title: Text('Notifications push', style: TextStyle(color: _c.text, fontSize: 15)),
                value: _notificationsEnabled,
                onChanged: (v) => _setNotificationPref('push', v, _notificationsEnabled, (x) { _notificationsEnabled = x; }),
                activeColor: _c.accent,
              ),
              _buildDivider(),
              SwitchListTile(
                secondary: Icon(Icons.mail_outline, color: _c.accent),
                title: Text('Notifications email', style: TextStyle(color: _c.text, fontSize: 15)),
                value: _emailNotifications,
                onChanged: (v) => _setNotificationPref('email', v, _emailNotifications, (x) { _emailNotifications = x; }),
                activeColor: _c.accent,
              ),
              _buildDivider(),
              SwitchListTile(
                secondary: Icon(Icons.sms_outlined, color: _c.accent),
                title: Text('Notifications SMS', style: TextStyle(color: _c.text, fontSize: 15)),
                value: _smsNotifications,
                onChanged: (v) => _setNotificationPref('sms', v, _smsNotifications, (x) { _smsNotifications = x; }),
                activeColor: _c.accent,
              ),
            ]),

            const SizedBox(height: 24),

            // --- PRÉFÉRENCES ---
            _buildSectionTitle('Préférences'),
            _buildCard([
              _buildListTile(
                icon: Icons.language,
                title: 'Langue',
                trailingText: selectedLanguage,
                iconColor: _c.accent,
                onTap: () => _showLanguageDialog(),
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.attach_money,
                title: 'Devise',
                trailingText: selectedCurrency,
                iconColor: _c.accent,
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
                iconColor: _c.accent,
                onTap: () => _showPrivacyPolicy(),
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.description_outlined,
                title: 'Conditions d\'utilisation',
                iconColor: _c.accent,
                onTap: () => _showTerms(),
              ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.delete_outline,
              title: 'Supprimer mon compte',
              titleColor: Colors.red,
              iconColor: Colors.red,
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
              trailingText: '1.0.0',
              showArrow: false,
              onTap: () {},
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.cached,
              title: 'Vider le cache',
              onTap: () async {
                await HiveCacheService.clearAll();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache local vidé')),
                );
              },
            ),
          ]),

          const SizedBox(height: 40),
        ],
      ); // end ListView
      }, // end data callback
      ), // end when
    ), // end Scaffold
    ); // end Theme
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: TextStyle(color: _c.textSecondary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _c.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    IconData? icon,
    required String title,
    String? subtitle,
    String? trailingText,
    Widget? trailingWidget,
    bool showArrow = true,
    Color? titleColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    Widget? trailing;
    if (trailingWidget != null) {
      trailing = trailingWidget;
    } else if (trailingText != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailingText, style: TextStyle(color: _c.textSecondary, fontSize: 13)),
          if (showArrow) ...[
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, color: _c.textSecondary, size: 14),
          ]
        ],
      );
    } else if (showArrow) {
      trailing = Icon(Icons.arrow_forward_ios, color: _c.textSecondary, size: 14);
    }

    return ListTile(
      leading: icon != null ? Icon(icon, color: iconColor ?? _c.accent) : null,
      title: Text(title, style: TextStyle(color: titleColor ?? _c.text, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: _c.textSecondary, fontSize: 12)) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: _c.border, indent: 56);
  }

  void _showEditProfileDialog(String currentName, String? currentUsername, String? currentBio, String? currentCity) {
    final nameController = TextEditingController(text: currentName);
    final usernameController = TextEditingController(text: currentUsername ?? '');
    final bioController = TextEditingController(text: currentBio ?? '');
    final cityController = TextEditingController(text: currentCity ?? '');
    bool isLoading = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(20),
          child: OliGlassPanel(
            child: SingleChildScrollView(
              child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Modifier profil', style: TextStyle(color: _c.text, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: usernameController,
                    style: TextStyle(color: _c.text),
                    decoration: oliGlassInputDecoration('Pseudo (public)'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: _c.text),
                    decoration: oliGlassInputDecoration('Nom complet (privé)'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: cityController,
                    style: TextStyle(color: _c.text),
                    decoration: oliGlassInputDecoration('Adresse de livraison'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: bioController,
                    style: TextStyle(color: _c.text),
                    decoration: oliGlassInputDecoration('Bio (facultatif)'),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: oliPrimaryButtonStyle(),
                        onPressed: isLoading ? null : () async {
                          final newName = nameController.text.trim();
                          final newUsername = usernameController.text.trim();
                          final newCity = cityController.text.trim();
                          final newBio = bioController.text.trim();
          
                          if (newName.isEmpty && newUsername.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Veuillez remplir au moins un nom ou pseudo'), backgroundColor: Colors.red),
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
                              body: jsonEncode({
                                'name': newName.isNotEmpty ? newName : null,
                                'username': newUsername.isNotEmpty ? newUsername : null,
                                'bio': newBio.isNotEmpty ? newBio : null,
                                'city': newCity.isNotEmpty ? newCity : null,
                              }),
                            );
                            
                            if (response.statusCode == 200) {
                              Navigator.pop(dialogContext);
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
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Enregistrer'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                      child: const Text('Annuler', style: TextStyle(color: OliPalette.textSecondary, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _c.card,
        title: Text('Mot de passe', style: TextStyle(color: _c.text)),
        content: Text(
          'La connexion OLI utilise uniquement la vérification par SMS (OTP).\n\nVotre compte est sécurisé par votre numéro de téléphone.',
          style: TextStyle(color: _c.textSecondary, height: 1.5),
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
        backgroundColor: _c.card,
        title: Text('Choisir la devise', style: TextStyle(color: _c.text)),
        children: currencies.map((currency) {
          final isSelected = currency == currentCurrency;
          return SimpleDialogOption(
            onPressed: () {
              ref.read(exchangeRateProvider.notifier).setCurrency(currency);
              Navigator.pop(context);
            },
            child: Row(
              children: [
                if (isSelected) Icon(Icons.check, color: _c.accent, size: 18),
                if (!isSelected) const SizedBox(width: 18),
                const SizedBox(width: 12),
                Text('${currency.name} (${currency.symbol})', style: TextStyle(color: _c.text)),
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
        backgroundColor: _c.card,
        title: Text('Langue', style: TextStyle(color: _c.text)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: Row(
              children: [
                Icon(Icons.check, color: _c.accent, size: 18),
                SizedBox(width: 12),
                Text('Français', style: TextStyle(color: _c.text)),
              ],
            ),
          ),
          SimpleDialogOption(
            child: Row(
              children: [
                SizedBox(width: 18),
                SizedBox(width: 12),
                Text('English (Bientôt)', style: TextStyle(color: _c.textSecondary)),
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _c.card,
        title: const Text('Supprimer le compte', style: TextStyle(color: Colors.red)),
        content: Text(
          'Cette action est irréversible. Vos informations personnelles seront effacées. '
          'Vos commandes et transactions passées sont conservées de façon anonyme '
          'pour nos obligations légales et comptables.',
          style: TextStyle(color: _c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteAccount();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  /// Appelle DELETE /user/account puis déconnecte et renvoie à l'écran de connexion.
  /// Si la suppression est bloquée (solde, commande en cours…), affiche les raisons.
  Future<void> _deleteAccount() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.delete(
        ApiConfig.userAccount,
        data: {'confirm': 'SUPPRIMER'},
      );

      await ref.read(authControllerProvider.notifier).logout();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final List<String> reasons = (data is Map && data['reasons'] is List)
          ? (data['reasons'] as List).map((r) => r.toString()).toList()
          : const [];
      final String message = reasons.isNotEmpty
          ? reasons.join('\n')
          : (data is Map && data['error'] != null
              ? data['error'].toString()
              : 'Erreur réseau. Veuillez réessayer.');

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _c.card,
          title: Text('Suppression impossible', style: TextStyle(color: _c.text)),
          content: Text(message, style: TextStyle(color: _c.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }
  }
}

class _PolicyPage extends StatelessWidget {
  final String title;
  const _PolicyPage({required this.title});

  @override
  Widget build(BuildContext context) {
    _c = OliSurface.of(context);
    return Scaffold(
      backgroundColor: _c.background,
      appBar: AppBar(backgroundColor: _c.background, title: Text(title)),
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
          style: TextStyle(color: _c.textSecondary, height: 1.6),
        ),
      ),
    );
  }
}
