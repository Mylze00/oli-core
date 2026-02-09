import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../search/providers/visual_search_provider.dart';
import '../../../search/widgets/visual_search_results_page.dart';
import '../../../search/providers/search_history_provider.dart';
import '../../../search/providers/autocomplete_provider.dart';
import '../../../search/providers/search_filters_provider.dart';
import '../../../search/widgets/autocomplete_dropdown.dart';
import '../../../search/pages/search_results_page.dart';

class DynamicSearchBar extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;
  final List<Product> allProducts;

  const DynamicSearchBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.allProducts,
  });

  @override
  ConsumerState<DynamicSearchBar> createState() => _DynamicSearchBarState();
}

class _DynamicSearchBarState extends ConsumerState<DynamicSearchBar> {
  late List<String> _placeholders;
  int _currentIndex = 0;
  Timer? _timer;
  bool _showAutocomplete = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _initPlaceholders();
    _startTimer();
    widget.controller.addListener(_onTextChanged);
  }

  void _initPlaceholders() {
    if (widget.allProducts.isNotEmpty) {
      // Prendre des noms de produits aléatoires
      final productNames = widget.allProducts
          .take(7)
          .map((p) {
            final words = p.name.split(' ');
            if (words.length > 4) {
              return '${words.take(4).join(' ')}...';
            }
            return p.name;
          })
          .toList();
      
      _placeholders = [
        "Rechercher un produit...",
        ...productNames,
        "📷 Recherche par IA",
      ];
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
    if (widget.allProducts != oldWidget.allProducts && widget.allProducts.isNotEmpty) {
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

  void _onTextChanged() {
    final query = widget.controller.text;
    final history = ref.read(searchHistoryProvider);

    if (query.length >= 2) {
      // Générer suggestions
      ref.read(autocompleteProvider.notifier).getSuggestions(
            query,
            widget.allProducts,
            history,
          );
      _showAutocompleteDropdown();
    } else {
      _hideAutocompleteDropdown();
      ref.read(autocompleteProvider.notifier).clear();
    }
  }

  void _showAutocompleteDropdown() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48), // Sous la barre de recherche
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Consumer(
              builder: (context, ref, child) {
                final autocompleteState = ref.watch(autocompleteProvider);
                final history = ref.watch(searchHistoryProvider);

                if (autocompleteState.suggestions.isEmpty) {
                  return const SizedBox.shrink();
                }

                return AutocompleteDropdown(
                  suggestions: autocompleteState.suggestions,
                  historyItems: history,
                  query: autocompleteState.query,
                  onSuggestionTap: (suggestion) {
                    widget.controller.text = suggestion;
                    _hideAutocompleteDropdown();
                    _navigateToResults(suggestion);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideAutocompleteDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _navigateToResults(String query) {
    if (query.trim().isEmpty) return;

    // Ajouter à l'historique
    ref.read(searchHistoryProvider.notifier).add(query);

    // Naviguer vers la page de résultats
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsPage(
          initialQuery: query,
          allProducts: widget.allProducts,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hideAutocompleteDropdown();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            // Placeholder Animé
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.only(left: 48, right: 100),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, child) {
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

            // TextField
            TextField(
              controller: widget.controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                _hideAutocompleteDropdown();
                _navigateToResults(value);
              },
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: '',
                prefixIcon: const Icon(Icons.search, color: Colors.orange, size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge filtres
                    if (filters.hasActiveFilters)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${filters.activeFiltersCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    
                    // Caméra IA
                    Consumer(
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
                                  await ref.read(visualSearchProvider.notifier).searchByImage();

                                  final state = ref.read(visualSearchProvider);

                                  if (state.error != null) {
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
                                    if (context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => VisualSearchResultsPage(),
                                        ),
                                      );
                                    }
                                  } else if (state.error == null) {
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
                  ],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
