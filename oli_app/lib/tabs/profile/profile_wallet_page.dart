import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'dart:convert';
import '../../app/theme/theme_provider.dart';
import '../../pages/publish_article_page.dart';
import '../../pages/purchases_page.dart';
import '../../pages/favorites_page.dart';
import '../../pages/settings_page.dart';
import '../../pages/help_page.dart';
import '../../pages/about_page.dart';
import '../../pages/payment_methods_page.dart';
import '../../secure_storage_service.dart';
import '../../auth_controller.dart';

class ProfileAndWalletPage extends ConsumerStatefulWidget {
  const ProfileAndWalletPage({super.key});

  @override
  ConsumerState<ProfileAndWalletPage> createState() => _ProfileAndWalletPageState();
}

class _ProfileAndWalletPageState extends ConsumerState<ProfileAndWalletPage> {
  String _deliveryAddress = '';
  final _storage = SecureStorageService();

  // Action : Changer l'image de profil
  Future<void> _updateAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final token = await _storage.getToken();
      var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/auth/upload-avatar'));
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(await http.MultipartFile.fromPath('avatar', image.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        ref.read(authControllerProvider.notifier).fetchUserProfile();
      }
    }
  }

  // Action : Dialogue de Dépôt
  void _showDepositDialog(BuildContext context) async {
    final controller = TextEditingController();
    final token = await _storage.getToken();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Dépôt Wallet", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Montant (\$)", hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              await http.post(
                Uri.parse('${ApiConfig.baseUrl}/wallet/deposit'),
                headers: {
                  'Content-Type': 'application/json',
                  if (token != null) 'Authorization': 'Bearer $token',
                },
                body: jsonEncode({'amount': controller.text}),
              );
              ref.read(authControllerProvider.notifier).fetchUserProfile();
              Navigator.pop(context);
            },
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );
  }

  // Action : Dialogue Adresse de Livraison
  void _showDeliveryAddressDialog(BuildContext context) {
    final controller = TextEditingController(text: _deliveryAddress);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Adresse de livraison', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ex: 123 rue..., Quartier, Ville',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              setState(() => _deliveryAddress = controller.text);
              Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  // Action : Déconnexion
  void _logout(BuildContext context) async {
    await ref.read(authControllerProvider.notifier).logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Navigation helpers
  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isDarkMode = ref.watch(themeProvider);
    final user = authState.userData ?? {};
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    
    // Couleurs dynamiques
    final cardColor = isLight ? Colors.white : const Color(0xFF1A1A1A);
    final textColor = isLight ? Colors.black87 : Colors.white;
    final subtitleColor = isLight ? Colors.black54 : Colors.grey.shade500;

    // Si pas authentifié, afficher message
    if (!authState.isAuthenticated) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle_outlined, color: Colors.grey, size: 64),
              const SizedBox(height: 16),
              Text("Vous n'êtes pas connecté", style: TextStyle(color: textColor, fontSize: 18)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text("Se connecter"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner, color: textColor),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scanner QR - Fonctionnalité à venir')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textColor),
            onPressed: () => _navigateTo(const SettingsPage()),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // --- HEADER DYNAMIQUE ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _updateAvatar,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: user['avatar_url'] == null 
                          ? const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent])
                          : null,
                        image: user['avatar_url'] != null 
                          ? DecorationImage(image: NetworkImage(user['avatar_url']), fit: BoxFit.cover)
                          : null,
                      ),
                      child: user['avatar_url'] == null 
                        ? Center(child: Text(_getInitials(user), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)))
                        : null,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user["name"] ?? "Utilisateur", style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('Tél: ${user["phone"] ?? "N/A"}', style: TextStyle(color: subtitleColor, fontSize: 13)),
                        const SizedBox(height: 8),
                        _buildStatusBadge(textColor),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // --- ADRESSE DE LIVRAISON ---
            _buildMenuSection(cardColor, [
              ListTile(
                onTap: () => _showDeliveryAddressDialog(context),
                leading: const Icon(Icons.location_on, color: Colors.blueAccent),
                title: _deliveryAddress.isEmpty
                    ? const Text('Ajouter adresse de livraison', style: TextStyle(color: Colors.blueAccent, fontStyle: FontStyle.italic, fontSize: 15))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Adresse de livraison', style: TextStyle(color: subtitleColor, fontSize: 10)),
                          const SizedBox(height: 4),
                          Text(_deliveryAddress, style: TextStyle(color: textColor, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                trailing: const Icon(Icons.edit, color: Colors.blueAccent, size: 18),
              ),
            ]),

            const SizedBox(height: 10),

            // --- SECTION PAIEMENTS ---
            _buildMenuSection(cardColor, [
              _buildMenuItem(
                Icons.account_balance_wallet_outlined, 
                'Paiements et Services', 
                Colors.green, 
                textColor: textColor,
                trailing: 'Wallet: ${user["wallet"] ?? 0} \$',
                onTap: () => _showDepositDialog(context)
              ),
              _buildMenuItem(
                Icons.credit_card, 
                'Ajouter Carte VISA', 
                Colors.blue, 
                textColor: textColor,
                onTap: () => _navigateTo(const PaymentMethodsPage())
              ),
              _buildMenuItem(
                Icons.account_balance, 
                'Ajouter Compte Bancaire', 
                Colors.orange, 
                textColor: textColor,
                onTap: () => _navigateTo(const PaymentMethodsPage())
              ),
            ]),

            // --- ACTIVITÉS ---
            const _SectionTitle(title: 'Mes Activités'),
            _buildMenuSection(cardColor, [
              _buildMenuItem(
                Icons.add_box_outlined, 
                'Mettre en vente un objet', 
                Colors.blue,
                textColor: textColor,
                onTap: () => _navigateTo(const PublishArticlePage())
              ),
              _buildMenuItem(
                Icons.shopping_bag_outlined, 
                'Mes achats', 
                Colors.orange, 
                textColor: textColor,
                onTap: () => _navigateTo(const PurchasesPage())
              ),
              _buildMenuItem(
                Icons.favorite_border, 
                'Favoris et Suivis', 
                Colors.pink, 
                textColor: textColor,
                onTap: () => _navigateTo(const FavoritesPage())
              ),
            ]),

            // --- PARAMÈTRES ---
            const _SectionTitle(title: 'Paramètres'),
            _buildMenuSection(cardColor, [
              ListTile(
                onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                leading: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, color: Colors.amber),
                title: Text(isDarkMode ? 'Mode Sombre' : 'Mode Clair', style: TextStyle(color: textColor, fontSize: 15)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
              ),
            ]),

            // --- SUPPORT ---
            _buildMenuSection(cardColor, [
              _buildMenuItem(
                Icons.help_outline, 
                'Aide et support', 
                Colors.grey, 
                textColor: textColor,
                onTap: () => _navigateTo(const HelpPage())
              ),
              _buildMenuItem(
                Icons.info_outline, 
                'À propos d\'Oli', 
                Colors.grey, 
                textColor: textColor,
                onTap: () => _navigateTo(const AboutPage())
              ),
            ]),

            // --- DÉCONNEXION ---
            _buildMenuSection(cardColor, [
              _buildMenuItem(Icons.logout, 'Déconnexion', Colors.redAccent, textColor: Colors.redAccent, onTap: () => _logout(context)),
            ]),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  String _getInitials(Map<String, dynamic> user) {
    final name = user['name'] as String?;
    if (name != null && name.isNotEmpty) {
      final parts = name.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }
    final phone = user['phone'] as String?;
    if (phone != null && phone.length >= 2) {
      return phone.substring(phone.length - 2);
    }
    return '?';
  }

  Widget _buildStatusBadge(Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: textColor.withOpacity(0.2)), borderRadius: BorderRadius.circular(20)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_user, size: 14, color: Colors.blueAccent),
        SizedBox(width: 4),
        Text('Utilisateur Certifié', style: TextStyle(color: Colors.blueAccent, fontSize: 11)),
      ]),
    );
  }

  Widget _buildMenuSection(Color bgColor, List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
      child: Column(children: items),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, Color color, {String? trailing, Color? textColor, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: textColor ?? Colors.white, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) Text(trailing, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 5),
          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),
      child: Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
    );
  }
}