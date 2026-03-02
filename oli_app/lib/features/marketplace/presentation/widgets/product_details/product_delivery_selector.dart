import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../../../models/product_model.dart';
import '../../../../../../providers/exchange_rate_provider.dart';
import '../../../../../../config/api_config.dart';
import '../../../../../../core/storage/secure_storage_service.dart';

// Provider qui fetche les méthodes de livraison fraîches depuis le backend
final deliveryMethodsProvider = FutureProvider.family<List<ShippingOption>, String>((ref, productId) async {
  final storage = SecureStorageService();
  final token = await storage.getToken();
  final dio = Dio();
  try {
    final response = await dio.get(
      '${ApiConfig.baseUrl}/api/delivery-methods/product/$productId',
      options: token != null ? Options(headers: {'Authorization': 'Bearer $token'}) : null,
    );
    if (response.statusCode == 200 && response.data is List) {
      final List raw = response.data as List;
      return raw.map((e) => ShippingOption.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (e) {
    debugPrint('⚠️ deliveryMethods fetch error: $e');
  }
  return [];
});

class ProductDeliverySelector extends ConsumerStatefulWidget {
  final Product product;
  final ShippingOption? selectedShipping;
  final Function(ShippingOption) onShippingChanged;
  final Function(String method, double price) onLegacyMethodChanged;

  const ProductDeliverySelector({
    super.key,
    required this.product,
    required this.selectedShipping,
    required this.onShippingChanged,
    required this.onLegacyMethodChanged,
  });

  @override
  ConsumerState<ProductDeliverySelector> createState() => _ProductDeliverySelectorState();
}

class _ProductDeliverySelectorState extends ConsumerState<ProductDeliverySelector> {
  String _calculateDeliveryDate(String deliveryTime) {
    try {
      final RegExp regExp = RegExp(r'\d+');
      final match = regExp.firstMatch(deliveryTime);
      if (match != null) {
        final int days = int.parse(match.group(0)!);
        final DateTime deliveryDate = DateTime.now().add(Duration(days: days));
        final String day = deliveryDate.day.toString().padLeft(2, '0');
        final String month = deliveryDate.month.toString().padLeft(2, '0');
        final String year = deliveryDate.year.toString();
        return "Le $day/$month/$year";
      }
    } catch (e) {
      debugPrint("Erreur calcul date livraison: $e");
    }
    return deliveryTime;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.product;

    // Fetch frais via API
    final deliveryAsync = ref.watch(deliveryMethodsProvider(p.id));

    return deliveryAsync.when(
      loading: () => const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => _buildFallback(context, isDark, p),
      data: (liveOptions) {
        // Si l'API retourne des options → les utiliser (données fraîches admin)
        // Sinon fallback sur les options statiques du modèle
        final options = liveOptions.isNotEmpty
            ? liveOptions
            : p.shippingOptions;

        if (options.isNotEmpty) {
          // Auto-sélection si rien n'est sélectionné encore
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (widget.selectedShipping == null && options.isNotEmpty) {
              widget.onShippingChanged(options.first);
            }
          });
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DynamicDeliverySelector(
                options: options,
                selectedOption: widget.selectedShipping,
                onChanged: widget.onShippingChanged,
              ),
              const SizedBox(height: 16),
            ],
          );
        }

        return _buildFallback(context, isDark, p);
      },
    );
  }

  Widget _buildFallback(BuildContext context, bool isDark, Product p) {
    if (p.expressDeliveryPrice != null) {
      return Column(children: [
        _DeliveryMethodSelector(
          standardPrice: p.deliveryPrice,
          expressPrice: p.expressDeliveryPrice!,
          deliveryTime: p.deliveryTime,
          onMethodChanged: widget.onLegacyMethodChanged,
        ),
        const SizedBox(height: 16),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Consumer(builder: (context, ref, _) {
        final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
        return Text(
            "${exchangeNotifier.formatProductPrice(p.deliveryPrice)} de livraison",
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14));
      }),
      Text("Livraison estimée : ${_calculateDeliveryDate(p.deliveryTime)}",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14)),
      Divider(color: isDark ? Colors.white24 : Colors.black12, height: 24),
    ]);
  }
}

class _DynamicDeliverySelector extends StatelessWidget {
  final List<ShippingOption> options;
  final ShippingOption? selectedOption;
  final ValueChanged<ShippingOption> onChanged;

  const _DynamicDeliverySelector({
    required this.options,
    required this.selectedOption,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.blue.withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text("CHOISISSEZ VOTRE LIVRAISON",
                style: const TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          ...options.map((opt) => _buildOption(context, opt, isDark)).toList(),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, ShippingOption opt, bool isDark) {
    final bool isSelected = selectedOption?.methodId == opt.methodId;

    return InkWell(
      onTap: () => onChanged(opt),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.06))),
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.blueAccent : (isDark ? Colors.white54 : Colors.black38),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opt.label,
                      style: TextStyle(
                          color: isSelected ? Colors.blueAccent : (isDark ? Colors.white : Colors.black87),
                          fontWeight: FontWeight.bold)),
                  Text("Arrivée estimée : ${_formatDate(opt.time)}",
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12)),
                ],
              ),
            ),
            Consumer(builder: (context, ref, _) {
              final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
              return Text(
                opt.cost == 0
                    ? "GRATUIT"
                    : exchangeNotifier.formatProductPrice(opt.cost),
                style: TextStyle(
                    color: opt.cost == 0 ? Colors.greenAccent : (isDark ? Colors.white : Colors.black87),
                    fontWeight: FontWeight.bold),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatDate(String deliveryTime) {
    if (deliveryTime.isEmpty) return "Inconnue";
    final match = RegExp(r'\d+').firstMatch(deliveryTime);
    if (match != null) {
      final int days = int.parse(match.group(0)!);
      final date = DateTime.now().add(Duration(days: days));
      return "${_getDayName(date.weekday)} ${date.day} ${_getMonthName(date.month)}";
    }
    return deliveryTime;
  }

  String _getDayName(int weekday) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return months[month - 1];
  }
}

class _DeliveryMethodSelector extends StatefulWidget {
  final double standardPrice;
  final double expressPrice;
  final String deliveryTime;
  final Function(String method, double price) onMethodChanged;

  const _DeliveryMethodSelector({
    required this.standardPrice,
    required this.expressPrice,
    required this.deliveryTime,
    required this.onMethodChanged,
  });

  @override
  State<_DeliveryMethodSelector> createState() =>
      _DeliveryMethodSelectorState();
}

class _DeliveryMethodSelectorState extends State<_DeliveryMethodSelector> {
  String _selectedEvent = 'Standard';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMethodChanged('Standard', widget.standardPrice);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white24 : Colors.blue.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          _buildOption(
            title: "Standard",
            subtitle: "Livraison estimée : ${_calculateDate(widget.deliveryTime)}",
            price: widget.standardPrice,
            isSelected: _selectedEvent == 'Standard',
            isDark: isDark,
            onTap: () {
              setState(() => _selectedEvent = 'Standard');
              widget.onMethodChanged('Standard', widget.standardPrice);
            },
          ),
          Divider(height: 1, color: isDark ? Colors.white24 : Colors.black12),
          _buildOption(
            title: "Express (24h)",
            subtitle: "Livraison ultra-rapide",
            price: widget.expressPrice,
            color: Colors.orangeAccent,
            isSelected: _selectedEvent == 'Express',
            isDark: isDark,
            onTap: () {
              setState(() => _selectedEvent = 'Express');
              widget.onMethodChanged('Express', widget.expressPrice);
            },
          ),
        ],
      ),
    );
  }

  String _calculateDate(String deliveryTime) {
    if (deliveryTime.isEmpty) return "Inconnue";
    final match = RegExp(r'\d+').firstMatch(deliveryTime);
    if (match != null) {
      final int days = int.parse(match.group(0)!);
      final date = DateTime.now().add(Duration(days: days));
      return "${_getDayName(date.weekday)} ${date.day} ${_getMonthName(date.month)}";
    }
    return deliveryTime;
  }

  String _getDayName(int weekday) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return months[month - 1];
  }

  Widget _buildOption({
    required String title,
    required String subtitle,
    required double price,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    Color color = Colors.blueAccent,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? color : (isDark ? Colors.white54 : Colors.black38),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: isSelected ? color : (isDark ? Colors.white : Colors.black87),
                          fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12)),
                ],
              ),
            ),
            Consumer(builder: (context, ref, _) {
              final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
              return Text(
                exchangeNotifier.formatProductPrice(price),
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
              );
            }),
          ],
        ),
      ),
    );
  }
}
