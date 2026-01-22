import 'dart:async';
import 'package:flutter/material.dart';

class DynamicSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;
  final List<String> productNames;

  const DynamicSearchBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.productNames = const [],
  });

  @override
  State<DynamicSearchBar> createState() => _DynamicSearchBarState();
}

class _DynamicSearchBarState extends State<DynamicSearchBar> {
  late List<String> _placeholders;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initPlaceholders();
    _startTimer();
  }

  void _initPlaceholders() {
    if (widget.productNames.isNotEmpty) {
      _placeholders = widget.productNames.map((n) => n).toList();
    } else {
      _placeholders = [
        "Rechercher un produit...",
        "iPhone 15",
        "Chaussures Nike",
        "Groupe Électrogène",
        "Robe de soirée",
        "Toyota Ist",
      ];
    }
  }

  @override
  void didUpdateWidget(DynamicSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.productNames != oldWidget.productNames && widget.productNames.isNotEmpty) {
      _initPlaceholders();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _placeholders.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // 1. Placeholder Animé (Positionné derrière ou géré via InputDecoration ?)
          // Pour un meilleur contrôle de l'anim, on le met en Stack sous le TextField transparent
          // Mais le TextField a son propre hint.
          // Astuce : On utilise un TextField sans hint, et on affiche l'anim derrière si le text est vide.
          
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.only(left: 48), // Espace pour l'icone search
              child: Center(
                child: Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.controller,
                        builder: (context, value, child) {
                          // Si l'utilisateur tape du texte, on cache l'animation
                          if (value.text.isNotEmpty) return const SizedBox.shrink();
                          
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                            child: Text(
                              _placeholders[_currentIndex],
                              key: ValueKey<int>(_currentIndex),
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Le vrai TextField (Transparent)
          TextField(
            controller: widget.controller,
            textInputAction: TextInputAction.search,
            onSubmitted: widget.onSubmitted,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              // Hint text vide car géré manuellement
              hintText: '', 
              prefixIcon: const Icon(Icons.search, color: Colors.orange, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.black54, size: 20),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Recherche par image bientôt disponible")));
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
