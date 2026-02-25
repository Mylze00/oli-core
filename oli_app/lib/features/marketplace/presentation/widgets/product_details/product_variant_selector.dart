import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../../config/api_config.dart';
import '../../../../../models/product_variant_model.dart';
import '../../../../../providers/exchange_rate_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget pour afficher et sélectionner les variantes d'un produit
class ProductVariantSelector extends ConsumerStatefulWidget {
  final String productId;
  final double basePrice;
  final ValueChanged<ProductVariant?> onVariantSelected;

  const ProductVariantSelector({
    super.key,
    required this.productId,
    required this.basePrice,
    required this.onVariantSelected,
  });

  @override
  ConsumerState<ProductVariantSelector> createState() => _ProductVariantSelectorState();
}

class _ProductVariantSelectorState extends ConsumerState<ProductVariantSelector> {
  List<ProductVariant> _variants = [];
  Map<String, List<ProductVariant>> _grouped = {};
  Map<String, ProductVariant?> _selections = {};
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchVariants();
  }

  Future<void> _fetchVariants() async {
    try {
      final url = '${ApiConfig.baseUrl}/api/variants/public/${widget.productId}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final variants = data.map((e) => ProductVariant.fromJson(e)).toList();

        // Grouper par type
        final grouped = <String, List<ProductVariant>>{};
        for (final v in variants) {
          grouped.putIfAbsent(v.variantType, () => []).add(v);
        }

        if (mounted) {
          setState(() {
            _variants = variants;
            _grouped = grouped;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() { _loading = false; });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement variantes: $e');
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  void _selectVariant(String type, ProductVariant variant) {
    setState(() {
      if (_selections[type]?.id == variant.id) {
        _selections.remove(type);
      } else {
        _selections[type] = variant;
      }
    });

    // Notifier le parent avec la dernière sélection (pour l'ajustement de prix)
    if (_selections.isNotEmpty) {
      // Prendre la variante avec le plus grand impact sur le prix
      final selected = _selections.values
          .where((v) => v != null)
          .reduce((a, b) => a!.priceAdjustment.abs() >= b!.priceAdjustment.abs() ? a : b);
      widget.onVariantSelected(selected);
    } else {
      widget.onVariantSelected(null);
    }
  }

  Color _getColorForValue(String value) {
    final lower = value.toLowerCase();
    final colors = {
      'noir': Colors.black, 'black': Colors.black,
      'blanc': Colors.white, 'white': Colors.white,
      'rouge': Colors.red, 'red': Colors.red,
      'bleu': Colors.blue, 'blue': Colors.blue,
      'vert': Colors.green, 'green': Colors.green,
      'jaune': Colors.amber, 'yellow': Colors.amber,
      'orange': Colors.orange,
      'rose': Colors.pink, 'pink': Colors.pink,
      'violet': Colors.purple, 'purple': Colors.purple,
      'gris': Colors.grey, 'grey': Colors.grey, 'gray': Colors.grey,
      'marron': Colors.brown, 'brown': Colors.brown,
      'beige': const Color(0xFFF5F5DC),
      'or': const Color(0xFFFFD700), 'gold': const Color(0xFFFFD700),
      'argent': const Color(0xFFC0C0C0), 'silver': const Color(0xFFC0C0C0),
    };
    return colors[lower] ?? Colors.blueAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 40,
        child: Center(child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        )),
      );
    }

    if (_variants.isEmpty || _hasError) {
      return const SizedBox.shrink();
    }

    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    // Séparer couleur et taille, puis les autres types
    final colorEntry = _grouped.entries.where((e) => e.key == 'color').firstOrNull;
    final sizeEntry  = _grouped.entries.where((e) => e.key == 'size').firstOrNull;
    final otherEntries = _grouped.entries
        .where((e) => e.key != 'color' && e.key != 'size')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Couleur | Taille sur la même ligne ──────────────────────────
        if (colorEntry != null || sizeEntry != null)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (colorEntry != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          colorEntry.value.first.typeLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildColorChips(colorEntry.value),
                      ],
                    ),
                  ),
                if (colorEntry != null && sizeEntry != null)
                  const VerticalDivider(
                    width: 24,
                    thickness: 1,
                    color: Colors.white12,
                  ),
                if (sizeEntry != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sizeEntry.value.first.typeLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildTextChips(sizeEntry.value, 'size', exchangeNotifier),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        if ((colorEntry != null || sizeEntry != null) && otherEntries.isNotEmpty)
          const SizedBox(height: 8),

        // ── Autres types de variantes (empilés) ─────────────────────────
        for (final entry in otherEntries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 2),
            child: Text(
              entry.value.first.typeLabel,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildTextChips(entry.value, entry.key, exchangeNotifier),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildColorChips(List<ProductVariant> variants) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: variants.map((v) {
        final isSelected = _selections['color']?.id == v.id;
        final color = _getColorForValue(v.variantValue);
        final isLight = color.computeLuminance() > 0.5;

        return GestureDetector(
          onTap: v.inStock ? () => _selectVariant('color', v) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.blueAccent : Colors.white38,
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 6)]
                  : null,
            ),
            child: !v.inStock
                ? CustomPaint(painter: _CrossPainter())
                : (isSelected
                    ? Icon(Icons.check, size: 12, color: isLight ? Colors.black : Colors.white)
                    : null),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextChips(List<ProductVariant> variants, String type, ExchangeRateNotifier exchangeNotifier) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: variants.map((v) {
        final isSelected = _selections[type]?.id == v.id;
        final outOfStock = !v.inStock;

        String label = v.variantValue;
        if (v.priceAdjustment != 0) {
          final adj = v.priceAdjustment;
          final formatted = exchangeNotifier.formatProductPrice(adj.abs());
          label += adj > 0 ? ' (+$formatted)' : ' (-$formatted)';
        }

        return GestureDetector(
          onTap: outOfStock ? null : () => _selectVariant(type, v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blueAccent.withOpacity(0.15)
                  : (outOfStock ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? Colors.blueAccent
                    : (outOfStock ? Colors.white12 : Colors.white24),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              outOfStock ? '$label (épuisé)' : label,
              style: TextStyle(
                color: outOfStock
                    ? Colors.white30
                    : (isSelected ? Colors.blueAccent : Colors.white),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                decoration: outOfStock ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Painter pour dessiner une croix sur les couleurs épuisées
class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.25),
      Offset(size.width * 0.75, size.height * 0.75),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width * 0.25, size.height * 0.75),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
