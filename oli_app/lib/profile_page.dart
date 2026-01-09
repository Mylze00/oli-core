import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';
import 'dart:convert';
import 'secure_storage_service.dart';
import 'home_page.dart';
import 'pages/publish_article_page.dart';
import 'app/theme/theme_provider.dart';
import 'features/wallet/screens/wallet_screen.dart';
import 'features/shop/screens/my_shops_screen.dart';
import 'features/delivery/screens/delivery_dashboard.dart';

// Provider qui récupère les données réelles du serveur
final userProfileProvider = FutureProvider((ref) async {
  final token = await SecureStorageService().getToken();
  final response = await http.get(
    Uri.parse('${ApiConfig.baseUrl}/auth/me'),
    headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    },
  );
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['user'] ?? data; // Supporte direct et enveloppé
  }
  throw Exception('Erreur de chargement');
});

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  String _deliveryAddress = '';

  // Action : Changer l'image de profil
  Future<void> _updateAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final token = await SecureStorageService().getToken();
      var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/auth/upload-avatar'));
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(await http.MultipartFile.fromPath('avatar', image.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        ref.invalidate(userProfileProvider); // Force le rafraîchissement
      }
    }
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
  void _logout(BuildContext context) {
    // TODO: Appeler l'API de déconnexion si nécessaire
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final isDarkMode = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: profileAsync.when(
        data: (user) => SingleChildScrollView(
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
                          ? Center(child: Text(user["initial"], style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)))
                          : null,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user["name"], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          Text('ID Oli: ${user["id_oli"]}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          const SizedBox(height: 8),
                          _buildStatusBadge(),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // --- ADRESSE DE LIVRAISON ---
              _buildMenuSection([
                ListTile(
                  onTap: () => _showDeliveryAddressDialog(context),
                  leading: const Icon(Icons.location_on, color: Colors.blueAccent),
                  title: _deliveryAddress.isEmpty
                      ? const Text('Ajouter adresse de livraison', style: TextStyle(color: Colors.blueAccent, fontStyle: FontStyle.italic, fontSize: 15))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Adresse de livraison', style: TextStyle(color: Colors.white70, fontSize: 10)),
                            const SizedBox(height: 4),
                            Text(_deliveryAddress, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                  trailing: const Icon(Icons.edit, color: Colors.blueAccent, size: 18),
                ),
              ]),

              const SizedBox(height: 10),

              // --- SECTION PAIEMENTS ---
              _buildMenuSection([
                _buildMenuItem(
                  Icons.account_balance_wallet_outlined, 
                  'Mon Wallet', 
                  Colors.green, 
                  trailing: '${user["wallet"]} \$',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()))
                ),
                _buildMenuItem(Icons.credit_card, 'Ajouter Carte VISA', Colors.blue, onTap: () {}),
                _buildMenuItem(Icons.account_balance, 'Ajouter Compte Bancaire', Colors.orange, onTap: () {}),
              ]),

              // --- ACTIVITÉS ---
              const _SectionTitle(title: 'Mes Activités'),
              _buildMenuSection([
                _buildMenuItem(
                  Icons.store, 'Mes Boutiques', Colors.purpleAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyShopsScreen()))
                ),
                _buildMenuItem(
                  Icons.add_box_outlined, 'Mettre en vente un objet', Colors.blue,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PublishArticlePage()))
                ),
                _buildMenuItem(Icons.shopping_bag_outlined, 'Mes achats', Colors.orange, onTap: () {}),
                _buildMenuItem(Icons.favorite_border, 'Favoris et Suivis', Colors.pink, onTap: () {}),
              ]),

              // --- ESPACE LIVREUR (Conditionnel) ---
              if (user['is_deliverer'] == true) ...[
                const _SectionTitle(title: 'Espace Livreur'),
                _buildMenuSection([
                  _buildMenuItem(
                    Icons.delivery_dining, 'Gestion des Courses', Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryDashboard()))
                  ),
                ]),
              ],

              // --- PARAMÈTRES ---
              const _SectionTitle(title: 'Paramètres'),
              _buildMenuSection([
                ListTile(
                  onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                  leading: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, color: Colors.amber),
                  title: Text(isDarkMode ? 'Mode Sombre' : 'Mode Clair', style: const TextStyle(color: Colors.white, fontSize: 15)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
                ),
              ]),

              // --- SUPPORT ---
              _buildMenuSection([
                _buildMenuItem(Icons.help_outline, 'Aide et support', Colors.grey, onTap: () {}),
                _buildMenuItem(Icons.info_outline, 'À propos d\'Oli', Colors.grey, onTap: () {}),
              ]),

              // --- DÉCONNEXION ---
              _buildMenuSection([
                _buildMenuItem(Icons.logout, 'Déconnexion', Colors.redAccent, onTap: () => _logout(context)),
              ]),

              const SizedBox(height: 30),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Erreur de connexion : $err", style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  // --- WIDGETS DE CONSTRUCTION (Badge, Section, Item) ---
  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.2)), borderRadius: BorderRadius.circular(20)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_user, size: 14, color: Colors.blueAccent),
        SizedBox(width: 4),
        Text('Utilisateur Certifié', style: TextStyle(color: Colors.white, fontSize: 11)),
      ]),
    );
  }

  Widget _buildMenuSection(List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
      child: Column(children: items),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, Color color, {String? trailing, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
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