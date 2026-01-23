import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/visual_search_provider.dart';
import 'visual_search_results_page.dart';

/// Bouton flottant pour la recherche visuelle
/// Affiche une icône de caméra et permet de rechercher par image
class VisualSearchButton extends ConsumerWidget {
  const VisualSearchButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(visualSearchProvider);

    return FloatingActionButton(
      heroTag: 'visual_search_fab',
      backgroundColor: const Color(0xFF1976D2),
      elevation: 6,
      onPressed: searchState.isLoading 
          ? null 
          : () async {
              print('🎯 Bouton recherche visuelle cliqué');
              
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
                // Naviguer vers la page de résultats
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VisualSearchResultsPage(),
                    ),
                  );
                }
              }
            },
      child: searchState.isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(
              Icons.camera_alt,
              color: Colors.white,
              size: 28,
            ),
    );
  }
}

/// Widget alternatif : Bouton dans la SearchBar
class VisualSearchIconButton extends ConsumerWidget {
  const VisualSearchIconButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(visualSearchProvider);

    return IconButton(
      icon: searchState.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.photo_camera, color: Colors.blue),
      tooltip: 'Rechercher par image',
      onPressed: searchState.isLoading
          ? null
          : () async {
              await ref.read(visualSearchProvider.notifier).searchByImage();
              
              final state = ref.read(visualSearchProvider);
              
              if (state.error == null && state.products.isNotEmpty && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VisualSearchResultsPage(),
                  ),
                );
              }
            },
    );
  }
}
