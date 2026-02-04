import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../models/shop_model.dart';
import '../../models/product_model.dart';
import '../../widgets/verification_badge.dart';
import 'providers/shop_products_provider.dart';
import '../marketplace/presentation/widgets/market_product_card.dart';
import '../marketplace/presentation/pages/product_details_page.dart';
import 'widgets/promo_carousel_widget.dart';
import '../tabs/dashboard/widgets/category_glass_section.dart';
import '../../../../providers/exchange_rate_provider.dart';
// Based on file location: features/shop/shop_details_page.dart
// Target: features/tabs/dashboard/widgets/category_glass_section.dart
import 'widgets/alibaba_search_bar.dart';
import 'widgets/enriched_seller_info.dart';
import 'widgets/popular_products_circles.dart';

import 'widgets/horizontal_product_section.dart';
import 'widgets/promotional_banners.dart';
// import '../tabs/dashboard/widgets/category_glass_section.dart'; // Already defined above or effectively replaced import.

import '../../config/api_config.dart';
import '../auth/providers/auth_controller.dart';
import '../../core/storage/secure_storage_service.dart';
import '../chat/chat_page.dart';  // Import ChatPage

class ShopDetailsPage extends ConsumerWidget {
  final Shop shop;

  const ShopDetailsPage({super.key, required this.shop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(shopProductsProvider(shop.id));

    // Logic for Discovery (Last 4 added)
    final allProducts = productsAsync.valueOrNull ?? [];
    final sortedByDate = List<Product>.from(allProducts)..sort((a, b) {
        final dateA = a.createdAt;
        final dateB = b.createdAt;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
    });
    final discoveryProducts = sortedByDate.take(4).toList();

    return _ShopDetailsPageContent(shop: shop, discoveryProducts: discoveryProducts);
  }
}

class _ShopDetailsPageContent extends ConsumerStatefulWidget {
  final Shop shop;
  final List<Product> discoveryProducts;

  const _ShopDetailsPageContent({required this.shop, required this.discoveryProducts});

  @override
  ConsumerState<_ShopDetailsPageContent> createState() => _ShopDetailsPageContentState();
}

class _ShopDetailsPageContentState extends ConsumerState<_ShopDetailsPageContent> with SingleTickerProviderStateMixin {
  bool _showCategories = false;
  bool _isUploading = false;
  String _selectedCategory = "Tout";
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final Map<String, String> _categories = {
    "Tout": "",
    "Nouveautés": "new",
    "Populaire": "popular",
    "Promotions": "promo",
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Charger plus de produits quand on est à 200px de la fin
      final notifier = ref.read(shopProductsNotifierProvider(widget.shop.id).notifier);
      notifier.loadMore();
    }
  }

  void _toggleCategories() {
    setState(() {
      _showCategories = !_showCategories;
    });
  }

  void _onCategorySelected(String label) {
    setState(() {
      _selectedCategory = label;
      _showCategories = false;
    });
    
    // Utiliser le provider pour filtrer côté serveur
    final filterType = _categories[label];
    final notifier = ref.read(shopProductsNotifierProvider(widget.shop.id).notifier);
    notifier.changeFilter(filterType);
  }

  Future<void> _pickAndUploadAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isUploading = true);
    
    try {
      final token = await SecureStorageService().getToken();
      if (token == null) return;

      // Read image as bytes for web compatibility
      final bytes = await picked.readAsBytes();
      final fileName = picked.name;

      final uri = Uri.parse('${ApiConfig.auth}/avatar-upload');
      var request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile.fromBytes('avatar', bytes, filename: fileName));

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar mis à jour !')));
        ref.read(authControllerProvider.notifier).fetchUserProfile();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $respStr')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _onSearchSubmitted(String query) {
     final notifier = ref.read(shopProductsNotifierProvider(widget.shop.id).notifier);
     notifier.changeSearch(query);
  }

  void _onFavoritePressed() {
    // TODO: Implement actual favorite logic via provider/API
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ajouté aux favoris ❤️")),
    );
  }

  void _onChatPressed() {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated || authState.userData == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connectez-vous pour chater")),
      );
      return;
    }

    final myId = authState.userData!['id'].toString();
    // Assuming shop.ownerId exists. If optional, handle it.
    // In Shop model ownerId might be String.
    
    if (widget.shop.ownerId == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de contacter ce vendeur")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          myId: myId,
          otherId: widget.shop.ownerId!, 
          otherName: widget.shop.name,
          otherAvatarUrl: widget.shop.logoUrl,
        ),
      ),
    );
  }

  Future<void> _pickAndUploadBanner() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final token = await SecureStorageService().getToken();
      if (token == null) return;

      // Read image as bytes for web compatibility
      final bytes = await picked.readAsBytes();
      final fileName = picked.name;

      final uri = Uri.parse('${ApiConfig.shops}/${widget.shop.id}');
      var request = http.MultipartRequest('PATCH', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile.fromBytes('banner', bytes, filename: fileName));

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bannière mise à jour !')));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $respStr')));
      }
    } catch (e) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
       if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Utiliser le nouveau provider avec pagination
    final productsState = ref.watch(shopProductsNotifierProvider(widget.shop.id));
    final authState = ref.watch(authControllerProvider);
    // Watch currency changes
    final exchangeState = ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    final isOwner = authState.isAuthenticated && 
                    authState.userData != null && 
                    // Compare IDs as Strings to be safe slightly tricky if types differ
                    (authState.userData!['id']?.toString() == widget.shop.ownerId);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        controller: _scrollController, // Ajouter le controller pour infinite scroll
        slivers: [
          // 1. BANNIÈRE ET HEADER
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            // Bouton retour glassmorphism personnalisé
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                   // Bannière
                  widget.shop.bannerUrl != null
                      ? Image.network(widget.shop.bannerUrl!, fit: BoxFit.cover)
                      : Container(color: Colors.grey[850]),
                  // Dégradé sombre
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black12, Colors.black87],
                      ),
                    ),
                  ),

                  // Edit Banner Button (Owner Only)
                  if (isOwner)
                    Positioned(
                      top: 40, right: 10,
                      child: GestureDetector(
                        onTap: _pickAndUploadBanner,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20)
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 20),
                        ),
                      ),
                    ),

                  // Logo et Infos
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        // Avatar Container with Edit Option
                        Stack(
                          children: [
                            Container(
                              width: 85, height: 85,
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: ClipOval(
                                child: widget.shop.logoUrl != null
                                    ? Image.network(widget.shop.logoUrl!, fit: BoxFit.cover)
                                    : const Icon(Icons.store, size: 40),
                              ),
                            ),
                            if (isOwner)
                              Positioned(
                                bottom: 0, right: 0,
                                child: GestureDetector(
                                  onTap: _pickAndUploadAvatar,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: EnrichedSellerInfo(
                            shop: widget.shop,
                            onInfoPressed: () {
                               ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Vendeur vérifié par notre équipe")),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                   if (_isUploading)
                     const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),

          // BARRE DE RECHERCHE STYLE ALIBABA
          SliverToBoxAdapter(
            child: AlibabaSearchBar(
              searchController: _searchController,
              onSubmitted: _onSearchSubmitted,
              onCameraPressed: () {
                // TODO: Implement camera search
              },
              onCartPressed: () {
                // TODO: Navigate to cart
              },
              onSharePressed: () {
                // TODO: Share shop
              },
              // Passer les noms de produits pour le placeholder animé
              shopProductNames: productsState.products.take(6).map((p) => p.name).toList(),
            ),
          ),



           if (widget.shop.description != null && widget.shop.description!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  widget.shop.description!,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ),
          
          // 2.1 PRODUITS POPULAIRES (8 produits aléatoires)
          SliverToBoxAdapter(
            child: PopularProductsCircles(
              products: productsState.products,
              onProductTap: (product) => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)),
              ),
            ),
          ),



          // 2.5 PROMO WIDGET
          SliverToBoxAdapter(
            child: PromoCarouselWidget(shopId: widget.shop.id),
          ),

          // 2.6 DISCOVERY WIDGET
          if (widget.discoveryProducts.isNotEmpty)
             SliverToBoxAdapter(
              child: HorizontalProductSection(
                title: "🚀 Nouveautés", 
                subtitle: "Fraîchement ajoutés à la boutique",
                products: widget.discoveryProducts,
                badgeText: "NEW",
                badgeColor: Colors.blue,
                gradient: [Colors.blue.withOpacity(0.2), Colors.purple.withOpacity(0.1)],
                formatPrice: (price) => ref.read(exchangeRateProvider.notifier).formatProductPrice(price),
              ),
            ),
          

          // 2.65 BEST SELLERS SECTION
          SliverToBoxAdapter(
            child: () {
              if (productsState.products.isEmpty) return const SizedBox.shrink();
              
              // Filter best sellers (top 6 by view count)
              final bestSellers = List<Product>.from(productsState.products);
              bestSellers.sort((a, b) => b.viewCount.compareTo(a.viewCount));
              final topSellers = bestSellers.take(6).where((p) => p.viewCount > 0).toList();
              
              if (topSellers.isEmpty) return const SizedBox.shrink();
              
              return HorizontalProductSection(
                title: "🔥 Les plus vus", 
                subtitle: "Les produits les plus populaires",
                products: topSellers,
                badgeText: "POPULAIRE",
                badgeColor: const Color(0xFFFF6B6B),
                gradient: [const Color(0xFFFF6B6B).withOpacity(0.2), const Color(0xFFFF9500).withOpacity(0.1)],
                formatPrice: (price) => ref.read(exchangeRateProvider.notifier).formatProductPrice(price),
              );
            }(),
          ),
          


          // 2.8 WIDGETS PROMOTIONNELS
          SliverToBoxAdapter(
            child: productsState.products.isEmpty
                ? const SizedBox.shrink()
                : PromotionalBanners(
                    products: productsState.products,
                    onCategorySelected: _onCategorySelected,
                  ),
          ),

          // CATEGORY BUTTON
           SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Produits de la boutique", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: _toggleCategories,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.category, size: 16, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text(_showCategories ? "Masquer" : "Catégories", style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (_showCategories)
             SliverToBoxAdapter(
              child: CategoryGlassSection(
                 categories: _categories, 
                 selectedCategory: _selectedCategory,
                 onCategorySelected: _onCategorySelected,
              ),
            ),

           // 3. GRILLE PRODUITS
          if (productsState.isLoading && productsState.products.isEmpty)
            // Loading initial
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            )
          else if (productsState.error != null && productsState.products.isEmpty)
            // Erreur sans produits
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        productsState.error ?? "Erreur de chargement",
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (productsState.products.isEmpty)
            // Aucun produit
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        _selectedCategory == "Tout"
                            ? "Aucun produit disponible"
                            : "Aucun produit dans cette catégorie",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            // Grille de produits
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                   crossAxisCount: 2,
                   childAspectRatio: 0.75,
                   crossAxisSpacing: 12,
                   mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = productsState.products[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))
                      ),
                      child: MarketProductCard(product: product),
                    );
                  },
                  childCount: productsState.products.length,
                ),
              ),
            ),

          // Loader pour infinite scroll (en bas pendant chargement de plus)
          if (productsState.isLoading && productsState.products.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
            ),

          // Message "Plus de produits" si tout est chargé
          if (!productsState.hasMore && productsState.products.isNotEmpty && !productsState.isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    "✓ Tous les produits affichés (${productsState.products.length})",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }





  Color _getCertificationColor(String accountType) {
    switch (accountType) {
      case 'premium':
        return const Color(0xFF00BA7C); // Green
      case 'entreprise':
        return const Color(0xFFD4A500); // Gold
      case 'certifie':
        return const Color(0xFF1DA1F2); // Blue
      default:
        return Colors.blueAccent;
    }
  }
}


