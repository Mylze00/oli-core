import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../config/api_config.dart';
import '../../../../models/product_model.dart'; 
import '../../../../widgets/verification_badge.dart';
import '../../../chat/chat_page.dart';
import '../../../../core/user/user_provider.dart';
import '../../../user/providers/user_activity_provider.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../features/cart/providers/cart_provider.dart';
import '../../../../features/user/providers/favorites_provider.dart';

class ProductDetailsPage extends ConsumerStatefulWidget {
  final Product product;
  const ProductDetailsPage({super.key, required this.product});
  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  int _currentImageIndex = 0;
  // bool _isFollowing = false; // Plus besoin de variable locale

  void _shareProduct() {
    debugPrint("📤 [DEBUG] Bouton Partage cliqué");
    final p = widget.product;
    // Récupérer le formateur de prix
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    final priceUsd = double.tryParse(p.price) ?? 0.0;
    final formattedPrice = exchangeNotifier.formatProductPrice(priceUsd);
    
    final String text = "Regarde ce produit sur Oli : ${p.name}\n$formattedPrice\nhttps://oli-app.web.app/product/${p.id}";
    Share.share(text).then((result) {
      debugPrint("📤 [DEBUG] Partage terminé: ${result.status}");
    }).catchError((e) {
      debugPrint("❌ [DEBUG] Erreur Partage: $e");
    });
  }

  @override
  void initState() {
    super.initState();
    // 🔍 Tracking "Produits Consultés"
    Future.microtask(() {
      ref.read(userActivityProvider.notifier).addToVisited(widget.product);
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
              productId: p.id,
              productName: p.name,
              productPrice: double.tryParse(p.price),
              productImage: p.images.isNotEmpty ? p.images.first : null,
              otherAvatarUrl: p.sellerAvatar,
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

  void _toggleFollow() {
    ref.read(favoritesProvider.notifier).toggleFavorite(widget.product);
    final isFav = ref.read(favoritesProvider.notifier).isFavorite(widget.product.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(!isFav ? "Vous suivez maintenant cet objet" : "Suivi annulé"), // Logique inversée car toggle a déjà eu lieu
        duration: const Duration(seconds: 1),
      )
    );
  }
  
  void _addToCart() {
    final p = widget.product;
    final cartItem = CartItem(
      productId: p.id,
      productName: p.name,
      price: double.tryParse(p.price) ?? 0.0,
      imageUrl: p.images.isNotEmpty ? p.images.first : null,
      sellerName: p.seller,
    );
    
    ref.read(cartProvider.notifier).addItem(cartItem);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Produit ajouté au panier"),
        action: SnackBarAction(
          label: 'VOIR PANIER', 
          onPressed: () => Navigator.pop(context) // Retour au dashboard pour aller au panier ou push CartPage
        ),
        duration: const Duration(seconds: 2),
      )
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

  String _calculateDeliveryDate(String deliveryTime) {
    try {
      // Extraire le nombre de jours (ex: "3 jours" -> 3)
      final RegExp regExp = RegExp(r'\d+');
      final match = regExp.firstMatch(deliveryTime);
      
      if (match != null) {
        final int days = int.parse(match.group(0)!);
        final DateTime deliveryDate = DateTime.now().add(Duration(days: days));
        
        // Formatage manuel (Sans intl) : JJ/MM/AAAA
        final String day = deliveryDate.day.toString().padLeft(2, '0');
        final String month = deliveryDate.month.toString().padLeft(2, '0');
        final String year = deliveryDate.year.toString();
        
        return "Le $day/$month/$year";
      }
    } catch (e) {
      debugPrint("Erreur calcul date livraison: $e");
    }
    return deliveryTime; // Fallback si pas de chiffre trouvé
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isFollowing = ref.watch(favoritesProvider.notifier).isFavorite(p.id);
    // Pour que le bouton se mette à jour, on doit watch la liste
    ref.watch(favoritesProvider);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Détails - ${p.name.substring(0, p.name.length > 10 ? 10 : p.name.length)}", style: const TextStyle(color: Colors.white, fontSize: 16)),
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
                        fit: BoxFit.fill,
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
          // BLOC VENDEUR OU BOUTIQUE
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Row(children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                   CircleAvatar(
                     radius: 25, 
                     backgroundColor: Colors.blueAccent, 
                     backgroundImage: p.shopName != null && p.shopVerified 
                        ? null // TODO: Add Shop Logo if available in model
                        : p.sellerAvatar != null 
                            ? NetworkImage(p.sellerAvatar!) 
                            : null,
                     child: (p.shopName == null && p.sellerAvatar == null)
                        ? Text(p.seller.isNotEmpty ? p.seller[0] : '?', style: const TextStyle(color: Colors.white, fontSize: 20))
                        : null,
                   ),
                   // Verification Badge Overlay
                   if (p.sellerIsVerified || p.sellerAccountType != 'ordinaire' || p.sellerHasCertifiedShop || p.shopVerified)
                     Positioned(
                       bottom: -4, 
                       right: -4, 
                       child: VerificationBadge(
                         type: p.shopVerified 
                           ? BadgeType.gold
                           : VerificationBadge.fromSellerData(
                               isVerified: p.sellerIsVerified,
                               accountType: p.sellerAccountType,
                               hasCertifiedShop: p.sellerHasCertifiedShop,
                             ),
                         size: 20,
                       ),
                     ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    (p.shopName ?? p.seller).toUpperCase(), 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)
                  ),
                  if (p.shopName != null)
                   const Text('CONFIANCE GARANTIE', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('${p.totalBuyerRatings}% d\'évaluation positive', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.black, size: 30),
                onPressed: _openChat,
              ),
            ]),
          ),
          // BANNIÈRE PRIX (Design amélioré)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Mêmes marges que bloc vendeur
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E7DBA),
              borderRadius: BorderRadius.circular(15), // Mêmes arrondis que bloc vendeur
            ),
            child: Builder(
              builder: (context) {
                final exchangeState = ref.watch(exchangeRateProvider); // Pour la réactivité
                final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
                
                final double priceUsd = double.tryParse(p.price) ?? 0.0;
                final double? discountPriceUsd = p.discountPrice;
                final bool hasDiscount = discountPriceUsd != null && discountPriceUsd > 0;
                
                if (hasDiscount) {
                   final displayDiscount = exchangeState.selectedCurrency == Currency.USD
                      ? discountPriceUsd!
                      : exchangeNotifier.convertAmount(discountPriceUsd!, from: Currency.USD);
                   
                   final displayOriginal = exchangeState.selectedCurrency == Currency.USD
                      ? priceUsd
                      : exchangeNotifier.convertAmount(priceUsd, from: Currency.USD);
                   
                   final formattedDiscount = exchangeNotifier.formatAmount(displayDiscount, currency: exchangeState.selectedCurrency);
                   final formattedOriginal = exchangeNotifier.formatAmount(displayOriginal, currency: exchangeState.selectedCurrency);
                   
                   // Calculate percentage
                   int percent = 0;
                   if (priceUsd > 0) {
                     percent = (((priceUsd - discountPriceUsd) / priceUsd) * 100).round();
                   }
                   
                   return Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         crossAxisAlignment: CrossAxisAlignment.center,
                         children: [
                           Text(
                             formattedDiscount, 
                             style: const TextStyle(color: Colors.white, fontSize: 45, fontWeight: FontWeight.bold)
                           ),
                           if (percent > 0)
                             Container(
                               margin: const EdgeInsets.only(left: 10),
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                               decoration: BoxDecoration(
                                 color: Colors.orange,
                                 borderRadius: BorderRadius.circular(10),
                               ),
                               child: Text(
                                 "-$percent%",
                                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                               ),
                             ),
                         ],
                       ),
                       Text(
                         "Au lieu de $formattedOriginal",
                         style: const TextStyle(
                           color: Colors.white70, 
                           fontSize: 18, 
                           decoration: TextDecoration.lineThrough,
                           decorationColor: Colors.white70,
                         )
                       ),
                       if (p.discountEndDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _DiscountTimer(endDate: p.discountEndDate!),
                          )
                     ],
                   );
                }
                
                return Center(
                  child: Text(
                    exchangeNotifier.formatProductPrice(priceUsd), 
                    style: const TextStyle(color: Colors.white, fontSize: 45, fontWeight: FontWeight.bold)
                  )
                );
              }
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Builder(
                builder: (context) {
                  final exchangeState = ref.watch(exchangeRateProvider); // Pour la réactivité
                  final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
                  return Text(
                    "${exchangeNotifier.formatProductPrice(p.deliveryPrice)} de livraison", 
                    style: const TextStyle(color: Colors.white70, fontSize: 14)
                  );
                }
              ),
              Text("Livraison estimée : ${_calculateDeliveryDate(p.deliveryTime)}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
                child: OutlinedButton(
                  onPressed: _addToCart, 
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
                  ), 
                  child: const Text("Ajouter au panier", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton(
                  onPressed: _toggleFollow, 
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isFollowing ? Colors.blueAccent : Colors.white70), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
                  ), 
                  child: Text(
                    isFollowing ? "OBJET SUIVI" : "Suivre cet objet", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isFollowing ? Colors.blueAccent : Colors.white)
                  )
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              
              // TABLE DE PROVENANCE
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("PROVENANCE & DÉTAILS", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    Table(
                      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2)},
                      border: TableBorder(horizontalInside: BorderSide(color: Colors.white.withOpacity(0.05))),
                      children: [
                        _buildProvenanceRow("Localisation", p.location ?? "Non spécifié"),
                        _buildProvenanceRow("Vendeur", p.shopName ?? p.seller),
                        _buildProvenanceRow("Type Vendeur", p.sellerAccountType.toUpperCase()),
                        _buildProvenanceRow("Expédition", "Depuis ${p.location ?? 'l\'entrepôt'}"),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
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

  TableRow _buildProvenanceRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _DiscountTimer extends StatefulWidget {
  final DateTime endDate;
  const _DiscountTimer({required this.endDate});

  @override
  State<_DiscountTimer> createState() => _DiscountTimerState();
}

class _DiscountTimerState extends State<_DiscountTimer> {
  late Duration _timeLeft;
  Timer? _timerTicker;
  
  @override
  void initState() {
    super.initState();
    _updateTime();
    _timerTicker = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }
  
  void _updateTime() {
    final now = DateTime.now();
    if (widget.endDate.isBefore(now)) {
      _timeLeft = Duration.zero;
      _timerTicker?.cancel();
    } else {
      setState(() {
        _timeLeft = widget.endDate.difference(now);
      });
    }
  }
  
  @override
  void dispose() {
    _timerTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft.inSeconds <= 0) return const SizedBox.shrink();
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final formatted = "${twoDigits(_timeLeft.inHours)}h ${twoDigits(_timeLeft.inMinutes.remainder(60))}m ${twoDigits(_timeLeft.inSeconds.remainder(60))}s";
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.redAccent, size: 16),
          const SizedBox(width: 6),
          Text(
            "Expire dans : $formatted",
            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }
}
