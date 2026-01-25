import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/exchange_rate_provider.dart';

/// Widget pour sélectionner la devise (USD ou CDF)
class CurrencySelectorWidget extends ConsumerWidget {
  const CurrencySelectorWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exchangeState = ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), // Réduit
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12), // Rayon réduit
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icône supprimée pour gain de place
          
          // Sélecteur USD -> $
          _CurrencyOption(
            label: '\$', // Label simplifié
            currency: Currency.USD,
            isSelected: exchangeState.selectedCurrency == Currency.USD,
            onTap: () => exchangeNotifier.setCurrency(Currency.USD),
          ),

          const SizedBox(width: 4),

          // Séparateur
          Container(
            width: 1,
            height: 20,
            color: Colors.grey[300],
          ),

          const SizedBox(width: 4),

          // Sélecteur CDF -> FC
          _CurrencyOption(
            label: 'FC',
            currency: Currency.CDF,
            isSelected: exchangeState.selectedCurrency == Currency.CDF,
            onTap: () => exchangeNotifier.setCurrency(Currency.CDF),
          ),

          // Indicateur de chargement
          if (exchangeState.isLoading) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Option de devise individuelle
class _CurrencyOption extends StatelessWidget {
  final Currency currency;
  final String label; // Nouveau paramètre pour texte custom
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyOption({
    required this.currency,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Padding réduit
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(8), // Rayon réduit
        ),
        child: Text(
          label, // Utilise le label court
          style: TextStyle(
            fontSize: 10, // Font size réduit (13 -> 10)
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

/// Widget pour afficher le taux de change actuel
class ExchangeRateInfoWidget extends ConsumerWidget {
  const ExchangeRateInfoWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exchangeState = ref.watch(exchangeRateProvider);

    if (exchangeState.currentRate == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 6),
          Text(
            '1 USD = ${exchangeState.currentRate!.toStringAsFixed(2)} FC',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[900],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (exchangeState.lastUpdate != null) ...[
            const SizedBox(width: 8),
            Text(
              _formatLastUpdate(exchangeState.lastUpdate!),
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatLastUpdate(DateTime lastUpdate) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdate);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes}min';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return 'Il y a ${difference.inDays}j';
    }
  }
}
