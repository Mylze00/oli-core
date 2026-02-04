import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../config/api_config.dart';
import 'market_view.dart';
import 'seller_profile_page.dart'; // Importer la page de profil

import '../../../../models/product_model.dart'; 
import '../../../../widgets/verification_badge.dart';
import '../../../chat/chat_page.dart';
import '../../../../core/user/user_provider.dart';
import '../../../user/providers/user_activity_provider.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../features/cart/providers/cart_provider.dart';
import '../../../../features/user/providers/favorites_provider.dart';
import '../../../../features/checkout/screens/checkout_page.dart';

class ProductDetailsPage extends ConsumerStatefulWidget {
  final Product product;
  const ProductDetailsPage({super.key, required this.product});
  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  int _currentImageIndex = 0;
  
  Widget _buildPaymentLogo(String path) {
    return Container(
      // margin: const EdgeInsets.only(right: 6), // Removed to let Wrap handle spacing
      width: 42,
      height: 27,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
      ),
      padding: const EdgeInsets.all(2),
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => const Icon(Icons.error, size: 10, color: Colors.red),
      ),
    );
  }

  Widget _buildProtectionWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Protection des commandes OLI",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          
          // Paiements sécurisés
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_outlined, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Paiements sécurisés", style: TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildPaymentLogo('assets/images/operators/orange_money.png'),
                        _buildPaymentLogo('assets/images/operators/mpesa.png'),
                        _buildPaymentLogo('assets/images/operators/airtel_money.png'),
                        _buildPaymentLogo('assets/images/operators/afrimoney.png'),
                        _buildPaymentLogo('assets/images/operators/visa.png'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Livraison
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 12),
              const Text("Livraison via OLI Logistics", style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),

          // Remboursement
          Row(
            children: [
              const Icon(Icons.currency_exchange, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 12),
              const Text("Protection de remboursement", style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),

          // Footer
          const Text(
            "Seules les commandes passées et payées via OLI sont protégées gratuitement par OLI Assurance",
            style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
  ShippingOption? _selectedShipping; 
  bool _showFullDescription = false; 
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
    // 🚀 Initialisation des options dynamiques
    if (widget.product.shippingOptions.isNotEmpty) {
      _selectedShipping = widget.product.shippingOptions.first;
    } else {
        // Repli pour les anciens produits (création d'une option "Standard" simulée)
        _selectedShipping = ShippingOption(
            methodId: 'standard', 
            label: 'Standard', 
            time: widget.product.deliveryTime, 
            cost: widget.product.deliveryPrice
        );
    }
    
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
      deliveryPrice: _selectedShipping?.cost ?? 0.0,
      deliveryMethod: _selectedShipping?.label ?? 'Standard',
    );
    
    ref.read(cartProvider.notifier).addItem(cartItem);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('${p.name} ajouté au panier')),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      )
    );
  }

  /// Achat immédiat - Navigue directement vers le checkout avec ce produit
  void _buyNow(Product p) {
    // Calculer le prix effectif (avec réduction si applicable)
    final basePrice = double.tryParse(p.price) ?? 0.0;
    // Utiliser discountPrice si disponible, sinon le prix de base
    final effectivePrice = (p.discountPrice != null && p.discountPrice! > 0)
        ? p.discountPrice!
        : basePrice;
    
    final directItem = CartItem(
      productId: p.id,
      productName: p.name,
      price: effectivePrice,
      quantity: 1,
      imageUrl: p.images.isNotEmpty ? p.images.first : null,
      sellerName: p.seller,
      deliveryPrice: _selectedShipping?.cost ?? p.deliveryPrice,
      deliveryMethod: _selectedShipping?.label ?? 'Standard',
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(directPurchaseItem: directItem),
      ),
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
                CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.9), 
                  child: IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black, size: 18),
                    onPressed: () {
                      final p = widget.product;
                      ref.read(cartProvider.notifier).addItem(
                        CartItem(
                          productId: p.id.toString(),
                          productName: p.name,
                          price: double.tryParse(p.price) ?? 0.0,
                          quantity: 1,
                          imageUrl: p.images.isNotEmpty ? p.images.first : null,
                          sellerName: p.seller,
                        ),
                      );
                      final count = ref.read(cartItemCountProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 8),
                              const Text('Produit ajouté au panier'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          margin: const EdgeInsets.all(16),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        p.name, 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility, color: Colors.white54, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "${p.viewCount}", 
                            style: const TextStyle(color: Colors.white70, fontSize: 12)
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // BLOC VENDEUR OU BOUTIQUE
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(15)
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () {
                   debugPrint("👉 [DEBUG] Clic Profil Vendeur. SellerID: '${p.sellerId}'");
                   if (p.sellerId.isNotEmpty) {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => SellerProfilePage(sellerId: p.sellerId.trim())));
                   } else {
                     debugPrint("❌ [DEBUG] Seller ID est vide !");
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil vendeur indisponible")));
                   }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                         CircleAvatar(
                           radius: 25, 
                           backgroundColor: Colors.blueAccent, 
                           backgroundImage: p.shopName != null && p.shopVerified 
                              ? null // TODO : Ajouter le logo de la boutique s'il est disponible dans le modèle
                              : p.sellerAvatar != null 
                                  ? NetworkImage(p.sellerAvatar!) 
                                  : null,
                           child: (p.shopName == null && p.sellerAvatar == null)
                              ? Text(p.seller.isNotEmpty ? p.seller[0] : '?', style: const TextStyle(color: Colors.white, fontSize: 20))
                              : null,
                         ),
                         // Badge de vérification superposé - only for certified
                         if (p.sellerHasCertifiedShop || 
                             p.sellerAccountType == 'entreprise' ||
                             p.sellerAccountType == 'certifie' ||
                             p.sellerIsVerified ||
                             p.shopVerified)
                           Positioned(
                             bottom: -4, 
                             right: -4, 
                             child: VerificationBadge(
                               type: (p.shopVerified || p.sellerHasCertifiedShop || p.sellerAccountType == 'entreprise')
                                   ? BadgeType.gold
                                   : BadgeType.blue,
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
                        
                        // Stats vendeur
                        Row(
                          children: [
                             Text('${p.totalBuyerRatings}% positif', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                             const SizedBox(width: 8),
                             Text('• ${p.sellerSalesCount} ventes', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.black, size: 30),
                      onPressed: _openChat,
                    ),
                  ]),
                ),
              ),
            ),
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
              // LOGIQUE CHOIX LIVRAISON
              if (p.shippingOptions.isNotEmpty) ...[
                  _DynamicDeliverySelector(
                    options: p.shippingOptions,
                    selectedOption: _selectedShipping,
                    onChanged: (option) {
                      setState(() => _selectedShipping = option);
                    },
                  ),
                  const SizedBox(height: 16),
              ] else if (p.expressDeliveryPrice != null) ...[
                 // FALLBACK LEGACY : Si pas de shippingOptions mais expressPrice existe (vieux produits)
                 _DeliveryMethodSelector(
                   standardPrice: p.deliveryPrice,
                   expressPrice: p.expressDeliveryPrice!,
                   deliveryTime: p.deliveryTime,
                   onMethodChanged: (method, price) {
                     // On simule une shipping option pour la compatibilité panier
                     setState(() {
                         _selectedShipping = ShippingOption(
                             methodId: method.toLowerCase(),
                             label: method,
                             time: method == 'Standard' ? p.deliveryTime : '24h',
                             cost: price
                         );
                     });
                   },
                 ),
                 const SizedBox(height: 16),
              ] else ...[
                // Affichage simple si rien du tout (super vieux produits)
                Builder(
                  builder: (context) {
                    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
                    return Text(
                      "${exchangeNotifier.formatProductPrice(p.deliveryPrice)} de livraison", 
                      style: const TextStyle(color: Colors.white70, fontSize: 14)
                    );
                  }
                ),
                Text("Livraison estimée : ${_calculateDeliveryDate(p.deliveryTime)}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const Divider(color: Colors.white24, height: 24),
              ],
              
              Text("Etat : ${p.condition}", style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 16),
              // BOUTONS D'ACTION
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () => _buyNow(p), 
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

              // WIDGET PROTECTION OLI
              _buildProtectionWidget(),

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
                        _buildProvenanceRow(
                          "Vendeur", 
                          p.seller, 
                          isLink: true,
                          onTap: () {
                             if (p.sellerId.isNotEmpty) {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => SellerProfilePage(sellerId: p.sellerId.trim())));
                             }
                          }
                        ),
                        _buildProvenanceRow("Type Vendeur", p.sellerAccountType.toUpperCase()),
                        _buildProvenanceRow("Mise en ligne", _getTimeSinceUpload(p.createdAt)),
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


  String _getTimeSinceUpload(DateTime? createdAt) {
    if (createdAt == null) return "Récemment";
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 1) return "Il y a ${diff.inDays} jours";
    if (diff.inDays == 1) return "Hier";
    if (diff.inHours > 0) return "Il y a ${diff.inHours} heures";
    return "Il y a quelques minutes";
  }

  TableRow _buildProvenanceRow(String label, String value, {bool isLink = false, VoidCallback? onTap}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ),
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              value, 
              style: TextStyle(
                color: isLink ? Colors.blueAccent : Colors.white, 
                fontSize: 13, 
                fontWeight: isLink ? FontWeight.bold : FontWeight.w500,
                decoration: isLink ? TextDecoration.underline : null,
              )
            ),
          ),
        ),
      ],
    );
  }
}

class _DeliveryMethodSelector extends StatefulWidget {
  final double standardPrice;
  final double expressPrice;
  final String deliveryTime;
  final Function(String method, double price) onMethodChanged;

  const _DeliveryMethodSelector({
    required this.standardPrice,
    required this.expressPrice,
    required this.deliveryTime,
    required this.onMethodChanged,
  });

  @override
  State<_DeliveryMethodSelector> createState() => _DeliveryMethodSelectorState();
}

class _DeliveryMethodSelectorState extends State<_DeliveryMethodSelector> {
  String _selectedEvent = 'Standard';

  @override
  void initState() {
    super.initState();
    // Sélection par défaut
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMethodChanged('Standard', widget.standardPrice);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          _buildOption(
            title: "Standard",
            subtitle: "Livraison estimée : ${_calculateDate(widget.deliveryTime)}",
            price: widget.standardPrice,
            isSelected: _selectedEvent == 'Standard',
            onTap: () {
              setState(() => _selectedEvent = 'Standard');
              widget.onMethodChanged('Standard', widget.standardPrice);
            },
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildOption(
            title: "Express (24h)",
            subtitle: "Livraison ultra-rapide",
            price: widget.expressPrice,
            color: Colors.orangeAccent,
            isSelected: _selectedEvent == 'Express',
            onTap: () {
              setState(() => _selectedEvent = 'Express');
              widget.onMethodChanged('Express', widget.expressPrice);
            },
          ),
        ],
      ),
    );
  }
  
  String _calculateDate(String deliveryTime) {
      if (deliveryTime.isEmpty) return "Inconnue";
      
      // Essayer de parser si c'est un nombre (nouveau format)
      final int? days = int.tryParse(deliveryTime);
      if (days != null) {
        final date = DateTime.now().add(Duration(days: days));
        return "${_getDayName(date.weekday)} ${date.day} ${_getMonthName(date.month)}";
      }
      
      // Sinon retourner le texte original (ancien format ex: "24-48h")
      return deliveryTime; 
  }

  String _getDayName(int weekday) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Fév', 'Mars', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return months[month - 1];
  }


  Widget _buildOption({
    required String title,
    required String subtitle,
    required double price,
    required bool isSelected,
    required VoidCallback onTap,
    Color color = Colors.blueAccent,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? color : Colors.white54,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? color : Colors.white, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Consumer(
              builder: (context, ref, _) {
                 final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
                 return Text(
                   exchangeNotifier.formatProductPrice(price),
                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                 );
              }
            ),
          ],
        ),
      ),
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

class _DynamicDeliverySelector extends StatelessWidget {
  final List<ShippingOption> options;
  final ShippingOption? selectedOption;
  final ValueChanged<ShippingOption> onChanged;

  const _DynamicDeliverySelector({
    required this.options,
    required this.selectedOption,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text("CHOISISSEZ VOTRE LIVRAISON", 
              style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          ...options.map((opt) => _buildOption(context, opt)).toList(),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, ShippingOption opt) {
    final bool isSelected = selectedOption?.methodId == opt.methodId;

    return InkWell(
      onTap: () => onChanged(opt),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
          color: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.blueAccent : Colors.white54,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opt.label, 
                    style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
                  Text("Arrivée estimée : ${_formatDate(opt.time)}", 
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            // Utilisation du Consumer pour le prix formaté selon la devise
            Consumer(builder: (context, ref, _) {
              final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
              return Text(
                opt.cost == 0 ? "GRATUIT" : exchangeNotifier.formatProductPrice(opt.cost),
                style: TextStyle(
                  color: opt.cost == 0 ? Colors.greenAccent : Colors.white,
                  fontWeight: FontWeight.bold
                ),
              );
            }),
          ],
        ),
      ),
    );
  }



  String _formatDate(String deliveryTime) {
      if (deliveryTime.isEmpty) return "Inconnue";
      final int? days = int.tryParse(deliveryTime);
      if (days != null) {
        final date = DateTime.now().add(Duration(days: days));
        return "${_getDayName(date.weekday)} ${date.day} ${_getMonthName(date.month)}";
      }
      return deliveryTime; 
  }

  String _getDayName(int weekday) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Fév', 'Mars', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return months[month - 1];
  }
}
