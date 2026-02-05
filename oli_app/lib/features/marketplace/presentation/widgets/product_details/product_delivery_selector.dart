import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../models/product_model.dart';
import '../../../../../../providers/exchange_rate_provider.dart';

class ProductDeliverySelector extends StatelessWidget {
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
    final p = product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.shippingOptions.isNotEmpty) ...[
          _DynamicDeliverySelector(
            options: p.shippingOptions,
            selectedOption: selectedShipping,
            onChanged: onShippingChanged,
          ),
          const SizedBox(height: 16),
        ] else if (p.expressDeliveryPrice != null) ...[
          _DeliveryMethodSelector(
            standardPrice: p.deliveryPrice,
            expressPrice: p.expressDeliveryPrice!,
            deliveryTime: p.deliveryTime,
            onMethodChanged: onLegacyMethodChanged,
          ),
          const SizedBox(height: 16),
        ] else ...[
          Consumer(builder: (context, ref, _) {
            final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
            return Text(
                "${exchangeNotifier.formatProductPrice(p.deliveryPrice)} de livraison",
                style: const TextStyle(color: Colors.white70, fontSize: 14));
          }),
          Text("Livraison estimée : ${_calculateDeliveryDate(p.deliveryTime)}",
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const Divider(color: Colors.white24, height: 24),
        ],
      ],
    );
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text("CHOISISSEZ VOTRE LIVRAISON",
                style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          ...options.map((opt) => _buildOption(context, opt)).toList(),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, ShippingOption opt) {
    final bool isSelected = selectedOption?.methodId == opt.methodId;

    return InkWell(
      onTap: () => onChanged(opt),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.blueAccent : Colors.white54,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opt.label,
                      style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold)),
                  Text("Arrivée estimée : ${_formatDate(opt.time)}",
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
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
                    color: opt.cost == 0 ? Colors.greenAccent : Colors.white,
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
    final int? days = int.tryParse(deliveryTime);
    if (days != null) {
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
      'Jan',
      'Fév',
      'Mars',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc'
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          _buildOption(
            title: "Standard",
            subtitle:
                "Livraison estimée : ${_calculateDate(widget.deliveryTime)}",
            price: widget.standardPrice,
            isSelected: _selectedEvent == 'Standard',
            onTap: () {
              setState(() => _selectedEvent = 'Standard');
              widget.onMethodChanged('Standard', widget.standardPrice);
            },
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildOption(
            title: "Express (24h)",
            subtitle: "Livraison ultra-rapide",
            price: widget.expressPrice,
            color: Colors.orangeAccent,
            isSelected: _selectedEvent == 'Express',
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

    final int? days = int.tryParse(deliveryTime);
    if (days != null) {
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
      'Jan',
      'Fév',
      'Mars',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc'
    ];
    return months[month - 1];
  }

  Widget _buildOption({
    required String title,
    required String subtitle,
    required double price,
    required bool isSelected,
    required VoidCallback onTap,
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
              color: isSelected ? color : Colors.white54,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: isSelected ? color : Colors.white,
                          fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Consumer(builder: (context, ref, _) {
              final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
              return Text(
                exchangeNotifier.formatProductPrice(price),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              );
            }),
          ],
        ),
      ),
    );
  }
}
