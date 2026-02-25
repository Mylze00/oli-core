import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../config/api_config.dart';
import '../../providers/market_provider.dart';
import 'market_view.dart';
import 'seller_profile_page.dart';

import '../../../../models/product_model.dart'; 
import '../../../../widgets/verification_badge.dart';
import '../../../chat/chat_page.dart';
import '../../../../core/user/user_provider.dart';
import '../../../user/providers/user_activity_provider.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../features/cart/providers/cart_provider.dart';
import '../../../../features/user/providers/favorites_provider.dart';
import '../../../../features/checkout/screens/checkout_page.dart';

// Importation des nouveaux widgets
import '../widgets/product_details/product_image_carousel.dart';
import '../widgets/product_details/product_seller_info.dart';
import '../widgets/product_details/product_price_banner.dart';
import '../widgets/product_details/product_delivery_selector.dart';
import '../widgets/product_details/product_action_buttons.dart';
import '../widgets/product_details/product_protection_widget.dart';

import '../widgets/product_details/product_provenance_table.dart';
import '../widgets/product_details/product_variant_selector.dart';
import '../../../../models/product_variant_model.dart';
import '../../../shop/screens/edit_product_page.dart';


class ProductDetailsPage extends ConsumerStatefulWidget {
  final Product product;
  const ProductDetailsPage({super.key, required this.product});
  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  ShippingOption? _selectedShipping;
  ProductVariant? _selectedVariant;

  void _shareProduct() {
      debugPrint("📤 [DEBUG] Bouton Partage cliqué");
      final p = widget.product;
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
    if (widget.product.shippingOptions.isNotEmpty) {
      _selectedShipping = widget.product.shippingOptions.first;
    } else {
        _selectedShipping = ShippingOption(
            methodId: 'standard', 
            label: 'Standard', 
            time: widget.product.deliveryTime, 
            cost: widget.product.deliveryPrice
        );
    }
    
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
              otherName: (p.shopName != null && p.shopName!.isNotEmpty) ? p.shopName! : p.seller, // Privilégier le nom de la boutique
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur profil: $e")));
      },
    );
  }

  void _toggleFollow() {
    ref.read(favoritesProvider.notifier).toggleFavorite(widget.product);
    final isFav = ref.read(favoritesProvider.notifier).isFavorite(widget.product.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(!isFav ? "Vous suivez maintenant cet objet" : "Suivi annulé"), 
        duration: const Duration(seconds: 1),
      )
    );
  }
  
  void _addToCart() {
    final p = widget.product;
    final basePrice = double.tryParse(p.price) ?? 0.0;
    final priceAdj = _selectedVariant?.priceAdjustment ?? 0.0;
    final effectivePrice = (p.discountPrice != null && p.discountPrice! > 0)
        ? p.discountPrice! + priceAdj
        : basePrice + priceAdj;
    
    final variantLabel = _selectedVariant != null
        ? '${_selectedVariant!.typeLabel}: ${_selectedVariant!.variantValue}'
        : null;
    
    final cartItem = CartItem(
      productId: p.id,
      productName: variantLabel != null ? '${p.name} ($variantLabel)' : p.name,
      price: effectivePrice,
      imageUrl: p.images.isNotEmpty ? p.images.first : null,
      sellerName: p.seller,
      sellerId: p.sellerId,
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

  void _buyNow() {
    final p = widget.product;
    final basePrice = double.tryParse(p.price) ?? 0.0;
    final priceAdj = _selectedVariant?.priceAdjustment ?? 0.0;
    final effectivePrice = (p.discountPrice != null && p.discountPrice! > 0)
        ? p.discountPrice! + priceAdj
        : basePrice + priceAdj;
    
    final variantLabel = _selectedVariant != null
        ? '${_selectedVariant!.typeLabel}: ${_selectedVariant!.variantValue}'
        : null;
    
    final directItem = CartItem(
      productId: p.id,
      productName: variantLabel != null ? '${p.name} ($variantLabel)' : p.name,
      price: effectivePrice,
      quantity: 1,
      imageUrl: p.images.isNotEmpty ? p.images.first : null,
      sellerName: p.seller,
      sellerId: p.sellerId,
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
        title: const Text("Debug Info (V2.0 Refactored)"),
        content: Text(
          "Produit ID: ${p.id}\n"
          "Vendeur ID: ${p.sellerId}\n"
          "Vendeur Nom: ${p.seller}\n"
          "Boutique: ${p.shopName}\n"
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
    final isFollowing = ref.watch(favoritesProvider.notifier).isFavorite(p.id);
    ref.watch(favoritesProvider);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Détails - ${p.name.substring(0, p.name.length > 10 ? 10 : p.name.length)}", style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Bouton Modifier (visible uniquement pour le propriétaire)
          Consumer(
            builder: (context, ref, _) {
              final userState = ref.watch(userProvider);
              return userState.maybeWhen(
                data: (user) {
                  if (user.id.toString() == p.sellerId) {
                    return IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.blueAccent),
                      tooltip: 'Modifier',
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditProductPage(product: p)),
                        );
                        if (result == true && mounted) {
                          ref.read(marketProductsProvider.notifier).fetchProducts();
                        }
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
                orElse: () => const SizedBox.shrink(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, size: 18),
            onPressed: _showDebugInfo,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          
          ProductImageCarousel(
            product: p, 
            onShare: _shareProduct
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
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
          ),

          ProductSellerInfo(
            product: p,
            onSellerTap: () {
               debugPrint("👉 [DEBUG] Clic Profil Vendeur. SellerID: '${p.sellerId}'");
               if (p.sellerId.isNotEmpty) {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => SellerProfilePage(sellerId: p.sellerId.trim())));
               } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil vendeur indisponible")));
               }
            },
            onChatTap: _openChat,
          ),

          ProductPriceBanner(product: p),

          // Sélecteur de variantes (taille, couleur, etc.)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ProductVariantSelector(
              productId: p.id,
              basePrice: double.tryParse(p.price) ?? 0.0,
              onVariantSelected: (variant) {
                setState(() => _selectedVariant = variant);
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                ProductDeliverySelector(
                  product: p,
                  selectedShipping: _selectedShipping,
                  onShippingChanged: (option) {
                    setState(() => _selectedShipping = option);
                  },
                  onLegacyMethodChanged: (method, price) {
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
                
                Text("Etat : ${p.condition}", style: const TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 16),
                
                ProductActionButtons(
                  onBuyNow: _buyNow,
                  onAddToCart: _addToCart,
                  onToggleFollow: _toggleFollow,
                  isFollowing: isFollowing,
                ),
                
                const SizedBox(height: 20),

                const ProductProtectionWidget(),

                const SizedBox(height: 20),
                
                // TABLE DE PROVENANCE
                ProductProvenanceTable(product: p),
                
                const SizedBox(height: 12),
                
                // Description du produit affichée directement
                const Text(
                  "Description",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (p.description.isNotEmpty)
                  _ExpandableDescription(description: p.description)
                else
                  const Text(
                    "Aucune description disponible.",
                    style: TextStyle(color: Colors.white38, fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                const SizedBox(height: 8),
                Text("Quantité Disponible : ${p.quantity}", style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 40),
              ]
            ),
          ),
        ]),
      ),
    );
  }


}

class _ExpandableDescription extends StatefulWidget {
  final String description;
  const _ExpandableDescription({required this.description});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.description,
          maxLines: _expanded ? null : 4,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? "Voir moins" : "Voir plus",
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
