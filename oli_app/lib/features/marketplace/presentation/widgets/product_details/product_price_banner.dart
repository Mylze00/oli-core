import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../models/product_model.dart';
import '../../../../../../providers/exchange_rate_provider.dart';

class ProductPriceBanner extends ConsumerWidget {
  final Product product;

  const ProductPriceBanner({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exchangeState = ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    final p = product;

    final double priceUsd = double.tryParse(p.price) ?? 0.0;
    final double? discountPriceUsd = p.discountPrice;
    final bool hasDiscount = discountPriceUsd != null && discountPriceUsd > 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E7DBA),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Builder(builder: (context) {
        if (hasDiscount) {
          final displayDiscount = exchangeState.selectedCurrency == Currency.USD
              ? discountPriceUsd!
              : exchangeNotifier.convertAmount(discountPriceUsd!,
                  from: Currency.USD);

          final displayOriginal = exchangeState.selectedCurrency == Currency.USD
              ? priceUsd
              : exchangeNotifier.convertAmount(priceUsd, from: Currency.USD);

          final formattedDiscount = exchangeNotifier.formatAmount(
              displayDiscount,
              currency: exchangeState.selectedCurrency);
          final formattedOriginal = exchangeNotifier.formatAmount(
              displayOriginal,
              currency: exchangeState.selectedCurrency);

          // Calcul du pourcentage
          int percent = 0;
          if (priceUsd > 0) {
            percent =
                (((priceUsd - discountPriceUsd) / priceUsd) * 100).round();
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(formattedDiscount,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 45,
                          fontWeight: FontWeight.bold)),
                  if (percent > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text("-$percent%",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                ],
              ),
              Text("Au lieu de $formattedOriginal",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.white70,
                  )),
              if (p.discountEndDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _DiscountTimer(endDate: p.discountEndDate!),
                )
            ],
          );
        }

        return Center(
            child: Text(exchangeNotifier.formatProductPrice(priceUsd),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 45,
                    fontWeight: FontWeight.bold)));
      }),
    );
  }
}

class _DiscountTimer extends StatefulWidget {
  final DateTime endDate;
  const _DiscountTimer({required this.endDate});

  @override
  State<_DiscountTimer> createState() => _DiscountTimerState();
}

class _DiscountTimerState extends State<_DiscountTimer> {
  late Duration _timeLeft;
  Timer? _timerTicker;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timerTicker =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    if (widget.endDate.isBefore(now)) {
      _timeLeft = Duration.zero;
      _timerTicker?.cancel();
    } else {
      setState(() {
        _timeLeft = widget.endDate.difference(now);
      });
    }
  }

  @override
  void dispose() {
    _timerTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft.inSeconds <= 0) return const SizedBox.shrink();

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final formatted =
        "${twoDigits(_timeLeft.inHours)}h ${twoDigits(_timeLeft.inMinutes.remainder(60))}m ${twoDigits(_timeLeft.inSeconds.remainder(60))}s";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.redAccent, size: 16),
          const SizedBox(width: 6),
          Text("Expire dans : $formatted",
              style: const TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
