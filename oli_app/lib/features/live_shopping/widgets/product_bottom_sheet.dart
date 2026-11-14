import 'package:oli_app/core/widgets/oli_image.dart';
import '../../../widgets/cart_added_toast.dart';
import '../../../core/theme/oli_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../models/product_model.dart';
import '../../../providers/exchange_rate_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../models/video_sale_model.dart';
import '../../marketplace/presentation/pages/product_details_page.dart';

/// Bottom sheet affichant les détails du produit lié à la vidéo
class ProductBottomSheet extends ConsumerStatefulWidget {
  final VideoSale video;

  const ProductBottomSheet({super.key, required this.video});

  @override
  ConsumerState<ProductBottomSheet> createState() => _ProductBottomSheetState();
}

class _ProductBottomSheetState extends ConsumerState<ProductBottomSheet> {
  bool _isLoadingProduct = false;

  Future<Product> _fetchProduct(String productId) async {
    final response = await http.get(Uri.parse('${ApiConfig.products}/$productId'));
    if (response.statusCode != 200) {
      throw Exception('Produit introuvable');
    }
    final data = jsonDecode(response.body);
    // data peut être { product: {...} } ou juste {...}
    return Product.fromJson(data['product'] ?? data);
  }

  Future<bool> _hasVariants(String productId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/variants/public/$productId'),
    );
    if (response.statusCode != 200) return false;
    final data = jsonDecode(response.body);
    return data is List && data.isNotEmpty;
  }

  /// Ferme le volet et ouvre la fiche produit en conservant l'origine vidéo.
  void _openProductDetails(NavigatorState navigator, Product product) {
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsPage(
          product: product,
          originVideoId: widget.video.id,
        ),
      ),
    );
  }

  CartItem _buildCartItem(Product product) {
    final basePrice = double.tryParse(product.price) ?? 0.0;
    final discount = product.discountPrice;
    final shipping = product.shippingOptions.isNotEmpty ? product.shippingOptions.first : null;
    return CartItem(
      productId: product.id,
      productName: product.name,
      price: (discount != null && discount > 0) ? discount : basePrice,
      imageUrl: product.images.isNotEmpty ? product.images.first : null,
      sellerName: product.seller,
      sellerId: product.sellerId,
      deliveryPrice: shipping?.cost ?? product.deliveryPrice,
      deliveryMethod: shipping?.label ?? 'Standard',
      originVideoId: widget.video.id,
    );
  }

  /// Charge le produit, puis exécute [action] ; affiche une erreur en cas d'échec.
  Future<void> _withProduct(
    Future<void> Function(Product product, String productId) action,
  ) async {
    final productId = widget.video.productId;
    if (productId == null || _isLoadingProduct) return;

    setState(() => _isLoadingProduct = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action(await _fetchProduct(productId), productId);
    } catch (e) {
      debugPrint('Erreur produit Live Shopping: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Impossible de charger les détails du produit'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingProduct = false);
      }
    }
  }

  Future<void> _viewProduct() {
    final navigator = Navigator.of(context);
    return _withProduct((product, _) async => _openProductDetails(navigator, product));
  }

  /// Ajoute le produit au panier. Un produit à variantes passe par sa fiche,
  /// car le client doit d'abord choisir une option.
  Future<void> _addToCart() {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cart = ref.read(cartProvider.notifier);

    return _withProduct((product, productId) async {
      if (await _hasVariants(productId)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Choisissez une option pour ce produit')),
        );
        _openProductDetails(navigator, product);
        return;
      }

      cart.addItem(_buildCartItem(product));
      navigator.pop();
      CartAddedToast.show(navigator.context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    final soldByOtherSeller =
        video.productSellerName != null && video.productSellerName != video.sellerName;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Contenu
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image produit + infos
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image produit
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[850],
                        child: video.productImages != null && video.productImages!.isNotEmpty
                            ? OliImage.network(
                                video.productImages!.first,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_outlined,
                                  color: Colors.white30,
                                  size: 40,
                                ),
                              )
                            : const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.white30,
                                size: 40,
                              ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Infos produit
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.productName ?? 'Produit',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          if (video.productPrice != null)
                            Text(
                              exchangeNotifier.formatProductPrice(video.productPrice!),
                              style: const TextStyle(
                                color: OliPalette.blueOnDark,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          const SizedBox(height: 8),
                          // Vendeur
                          if (soldByOtherSeller)
                            Text(
                              'Vendu par ${video.productSellerName}',
                              style: const TextStyle(color: Colors.white60, fontSize: 13),
                            )
                          else
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.grey[800],
                                backgroundImage: video.sellerAvatar != null
                                    ? NetworkImage(video.sellerAvatar!)
                                    : null,
                                child: video.sellerAvatar == null
                                    ? const Icon(Icons.person, size: 14, color: Colors.white54)
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                video.sellerName,
                                style: const TextStyle(color: Colors.white60, fontSize: 13),
                              ),
                              if (video.sellerCertified) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.verified, color: Colors.blue[400], size: 14),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Boutons d'action
                Row(
                  children: [
                    // Voir le produit
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoadingProduct ? null : _viewProduct,
                        icon: _isLoadingProduct 
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.visibility_outlined, size: 18),
                        label: Text(_isLoadingProduct ? 'Chargement...' : 'Voir le produit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Ajouter au panier
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingProduct ? null : _addToCart,
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text('Ajouter au panier'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OliPalette.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
