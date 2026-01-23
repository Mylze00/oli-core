import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../search/providers/visual_search_provider.dart';
import '../../../search/widgets/visual_search_results_page.dart';

class DynamicSearchBar extends ConsumerStatefulWidget {
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
  ConsumerState<DynamicSearchBar> createState() => _DynamicSearchBarState();
}

class _DynamicSearchBarState extends ConsumerState<DynamicSearchBar> {
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
      // Limiter à 4 mots maximum
      _placeholders = widget.productNames.map((name) {
        final words = name.split(' ');
        if (words.length > 4) {
          return '${words.take(4).join(' ')}...';
        }
        return name;
      }).toList();
    } else {
      _placeholders = [
        "Rechercher un produit...",
        "iPhone 15 Pro",
        "Chaussures Nike Air",
        "Groupe Électrogène Honda",
        "Robe de soirée",
        "📷 Recherche par IA",
        "Toyota Ist 2010",
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
              padding: const EdgeInsets.only(left: 48, right: 48), // Espace pour les icônes
              child: Align(
                alignment: Alignment.centerLeft,
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
              suffixIcon: Consumer(
                builder: (context, ref, child) {
                  final searchState = ref.watch(visualSearchProvider);
                  
                  return IconButton(
                    icon: searchState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt, color: Colors.blue, size: 22),
                    tooltip: 'Rechercher par image',
                    onPressed: searchState.isLoading
                        ? null
                        : () async {
                            print('📷 Recherche visuelle lancée depuis SearchBar');
                            
                            // Lancer la recherche
                            await ref.read(visualSearchProvider.notifier).searchByImage();
                            
                            // Vérifier les résultats
                            final state = ref.read(visualSearchProvider);
                            
                            if (state.error != null) {
                              // Afficher l'erreur
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(state.error!),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            } else if (state.products.isNotEmpty) {
                              // Naviguer vers les résultats
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VisualSearchResultsPage(),
                                  ),
                                );
                              }
                            } else if (state.error == null) {
                              // Aucun produit mais pas d'erreur = recherche annulée
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Recherche annulée'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                  );
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
