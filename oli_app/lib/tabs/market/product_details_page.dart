import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/product_model.dart';
import '../../chat/chat_page.dart';
import '../../core/user/user_provider.dart';

class ProductDetailsPage extends ConsumerStatefulWidget {
  final Product product;
  const ProductDetailsPage({super.key, required this.product});
  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  int _currentImageIndex = 0;
  bool _isFollowing = false;

  void _shareProduct() {
    debugPrint("📤 [DEBUG] Bouton Partage cliqué");
    final p = widget.product;
    final String text = "Regarde ce produit sur Oli : ${p.name}\n${p.price}\$\nhttps://oli-app.web.app/product/${p.id}";
    Share.share(text).then((result) {
      debugPrint("📤 [DEBUG] Partage terminé: ${result.status}");
    }).catchError((e) {
      debugPrint("❌ [DEBUG] Erreur Partage: $e");
    });
  }

  void _openChat() {
    debugPrint("💬 [DEBUG] Bouton Chat cliqué");
    final p = widget.product;
    final userState = ref.read(userProvider);
    
    userState.when(
      data: (user) {
        debugPrint("💬 [DEBUG] User actuel: ${user.id} | Seller: ${p.sellerId}");
        if (user.id.toString() == p.sellerId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Vous ne pouvez pas discuter avec vous-même !"))
          );
          return;
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              myId: user.id.toString(),
              otherId: p.sellerId,
              otherName: p.seller,
            ),
          ),
        );
      },
      loading: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chargement de votre profil..."))),
      error: (e, __) {
        debugPrint("❌ [DEBUG] Erreur userProvider: $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur profil: $e")));
      },
    );
  }

  void _showDebugInfo() {
    final p = widget.product;
    final userState = ref.read(userProvider);
    final myId = userState.value?.id.toString() ?? "Inconnu";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Debug Info (V1.1)"),
        content: Text(
          "Produit ID: ${p.id}\n"
          "Vendeur ID: ${p.sellerId}\n"
          "Vendeur Nom: ${p.seller}\n"
          "Mon ID: $myId\n"
          "Images: ${p.images.length}"
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Détails (INT-V1.1) - ${p.name.substring(0, p.name.length > 10 ? 10 : p.name.length)}", style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, size: 18),
            onPressed: _showDebugInfo,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          Stack(children: [
            Container(
              color: const Color(0xFF1A1A1A),
              height: 400,
              width: double.infinity,
              child: p.images.isEmpty
                  ? const Center(child: Icon(Icons.image, size: 60, color: Colors.grey))
                  : PageView.builder(
                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                      itemCount: p.images.length,
                      itemBuilder: (c, i) => Image.network(
                        p.images[i], 
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                    ),
            ),
            Positioned(
              top: 10, right: 16,
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.9), 
                  child: IconButton(
                    icon: const Icon(Icons.ios_share, color: Colors.black, size: 18),
                    onPressed: _shareProduct,
                  )
                ),
                const SizedBox(width: 10),
                CircleAvatar(backgroundColor: Colors.white.withOpacity(0.9), child: const Icon(Icons.shopping_cart_outlined, color: Colors.black, size: 18)),
              ]),
            ),
            if (p.images.length > 1)
              Positioned(
                bottom: 20, left: 0, right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(p.images.length, (i) => Container(width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(shape: BoxShape.circle, color: i == _currentImageIndex ? Colors.blueAccent : Colors.grey.withOpacity(0.5))))),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(p.name.toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          // BLOC VENDEUR
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Row(children: [
              Stack(
                children: [
                   CircleAvatar(radius: 25, backgroundColor: Colors.blueAccent, child: Text(p.seller.isNotEmpty ? p.seller[0] : '?', style: const TextStyle(color: Colors.white, fontSize: 20))),
                   Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Colors.blue, size: 16))),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.seller.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
                  Text('${p.totalBuyerRatings}% d\'évaluation positive', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.black, size: 30),
                onPressed: _openChat,
              ),
            ]),
          ),
          // BANNIÈRE PRIX
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: const Color(0xFF1E7DBA),
            child: Center(child: Text("${p.price}\$", style: const TextStyle(color: Colors.white, fontSize: 45, fontWeight: FontWeight.bold))),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${p.deliveryPrice}\$ de livraison", style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Text("Livraison estimée : ${p.deliveryTime}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const Divider(color: Colors.white24, height: 24),
              Text("Etat : ${p.condition}", style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 16),
              // BOUTONS D'ACTION
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Achat immédiat bientôt disponible")));
                  }, 
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E7DBA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), 
                  child: const Text("Achat immédiat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white70), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), child: const Text("Ajouter au panier", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton(
                  onPressed: _toggleFollow, 
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _isFollowing ? Colors.blueAccent : Colors.white70), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
                  ), 
                  child: Text(
                    _isFollowing ? "OBJET SUIVI" : "Suivre cet objet", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _isFollowing ? Colors.blueAccent : Colors.white)
                  )
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(onTap: () {}, child: const Text("Afficher la description complète", style: TextStyle(color: Colors.white, decoration: TextDecoration.underline))),
              const SizedBox(height: 8),
              Text("Quantité Disponible : ${p.quantity}", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 40),
            ]),
          ),
        ]),
      ),
    );
  }
}
