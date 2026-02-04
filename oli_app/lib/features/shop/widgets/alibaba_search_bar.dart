import 'dart:async';
import 'package:flutter/material.dart';

/// Barre de recherche style Alibaba avec placeholder animé
class AlibabaSearchBar extends StatefulWidget {
  final TextEditingController searchController;
  final VoidCallback? onBackPressed;
  final VoidCallback? onCartPressed;
  final VoidCallback? onSharePressed;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onChatPressed;
  final Function(String)? onSubmitted;
  final List<String> shopProductNames; // Noms de produits pour le placeholder animé

  const AlibabaSearchBar({
    super.key,
    required this.searchController,
    this.onBackPressed,
    this.onCartPressed,
    this.onSharePressed,
    this.onCameraPressed,
    this.onFavoritePressed,
    this.onChatPressed,
    this.onSubmitted,
    this.shopProductNames = const [],
  });

  @override
  State<AlibabaSearchBar> createState() => _AlibabaSearchBarState();
}

class _AlibabaSearchBarState extends State<AlibabaSearchBar> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Timer? _textScrollTimer;
  int _currentProductIndex = 0;
  bool _isTextFieldFocused = false;
  final FocusNode _focusNode = FocusNode();
  double _slideOffset = 0.0;
  double _textOpacity = 1.0;

  // Liste par défaut si aucun produit fourni
  List<String> get _productNames {
    if (widget.shopProductNames.isNotEmpty) {
      return widget.shopProductNames;
    }
    return [
      "Rechercher des produits...",
      "Maccoffee classic...",
      "Dairy milk chocolate...",
      "Heineken Beer 5%...",
      "Everyday cut macaroni...",
    ];
  }

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _animationController.addListener(() {
      setState(() {
        _slideOffset = -20 * _animationController.value;
        _textOpacity = 1 - _animationController.value;
      });
    });

    _focusNode.addListener(() {
      setState(() {
        _isTextFieldFocused = _focusNode.hasFocus;
      });
    });

    // Démarrer le timer pour le défilement des textes
    _startTextScrollTimer();
  }

  void _startTextScrollTimer() {
    _textScrollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isTextFieldFocused && widget.searchController.text.isEmpty && mounted) {
        _animateToNextProduct();
      }
    });
  }

  void _animateToNextProduct() async {
    // Animer la sortie vers le haut
    await _animationController.forward();
    
    if (!mounted) return;
    
    // Changer le texte
    setState(() {
      _currentProductIndex = (_currentProductIndex + 1) % _productNames.length;
    });
    
    // Reset et animer l'entrée depuis le bas
    _animationController.reset();
    _slideOffset = 20; // Commence depuis le bas
    _textOpacity = 0;
    
    // Animation d'entrée fluide
    const steps = 10;
    for (int i = 0; i <= steps; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 40));
      setState(() {
        _slideOffset = 20 * (1 - i / steps);
        _textOpacity = i / steps;
      });
    }
  }

  @override
  void dispose() {
    _textScrollTimer?.cancel();
    _animationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Conteneur principal recherche (aligné avec l'avatar à gauche)
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Dropdown "Cette boutique"
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Cette boutique",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 18),
                        ],
                      ),
                    ),
                    // Champ de recherche avec placeholder animé
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // Placeholder animé (affiché seulement si pas de texte et pas de focus)
                          if (!_isTextFieldFocused && widget.searchController.text.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Transform.translate(
                                offset: Offset(0, _slideOffset),
                                child: Opacity(
                                  opacity: _textOpacity.clamp(0.0, 1.0),
                                  child: Text(
                                    _productNames[_currentProductIndex],
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          // Champ de texte
                          TextField(
                            controller: widget.searchController,
                            focusNode: _focusNode,
                            onSubmitted: widget.onSubmitted,
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: _isTextFieldFocused ? "Rechercher des produits..." : "",
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    // Icône caméra
                    GestureDetector(
                      onTap: widget.onCameraPressed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.camera_alt_outlined, color: Colors.grey.shade600, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Icône panier
            GestureDetector(
              onTap: widget.onCartPressed,
              child: Icon(Icons.shopping_cart_outlined, color: Colors.grey.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            // Icône partage
            GestureDetector(
              onTap: widget.onSharePressed,
              child: Icon(Icons.open_in_new, color: Colors.grey.shade700, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
