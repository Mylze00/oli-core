import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/visual_search_provider.dart';
import '../../marketplace/presentation/widgets/market_product_card.dart';

/// Page affichant les résultats de la recherche visuelle
class VisualSearchResultsPage extends ConsumerWidget {
  const VisualSearchResultsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(visualSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche par Image'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Column(
        children: [
          // En-tête avec analyse de l'image
          if (searchState.analysis != null) _buildAnalysisHeader(searchState.analysis!),

          // Résultats
          Expanded(
            child: searchState.products.isEmpty
                ? _buildEmptyState()
                : _buildProductGrid(searchState.products),
          ),
        ],
      ),
    );
  }

  /// En-tête montrant l'analyse de l'IA
  Widget _buildAnalysisHeader(Map<String, dynamic> analysis) {
    final keywords = analysis['keywords'] as List? ?? [];
    final colors = analysis['colors'] as List? ?? [];
    final confidence = analysis['confidence'] ?? 0;
    final bestGuess = analysis['bestGuess'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade500, Colors.blue.shade700],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meilleure hypothèse
          if (bestGuess != null) ...[
            const Text(
              '🤖 Détection IA',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bestGuess,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Keywords détectés
          if (keywords.isNotEmpty) ...[
            const Text(
              'Mots-clés détectés',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keywords.take(5).map((kw) {
                final text = kw['text'] ?? '';
                final conf = kw['confidence'] ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$text ($conf%)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Couleurs
          if (colors.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Couleurs dominantes',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: colors.take(3).map((colorData) {
                final name = colorData['name'] ?? 'inconnu';
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// État vide
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Aucun produit trouvé',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Essayez avec une autre image',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// Grille de produits
  Widget _buildProductGrid(List products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${products.length} produit${products.length > 1 ? 's' : ''} trouvé${products.length > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return MarketProductCard(product: products[index]);
            },
          ),
        ),
      ],
    );
  }
}
