import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/exchange_rate_service.dart';

/// Énumération des devises supportées
enum Currency {
  USD,
  CDF,
}

extension CurrencyExtension on Currency {
  String get code {
    switch (this) {
      case Currency.USD:
        return 'USD';
      case Currency.CDF:
        return 'CDF';
    }
  }

  String get symbol {
    switch (this) {
      case Currency.USD:
        return '\$';
      case Currency.CDF:
        return 'FC';
    }
  }

  String get name {
    switch (this) {
      case Currency.USD:
        return 'Dollar américain';
      case Currency.CDF:
        return 'Franc congolais';
    }
  }
}

/// État du taux de change
class ExchangeRateState {
  final Currency selectedCurrency;
  final double? currentRate; // 1 USD = X CDF
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdate;

  ExchangeRateState({
    this.selectedCurrency = Currency.USD,
    this.currentRate,
    this.isLoading = false,
    this.error,
    this.lastUpdate,
  });

  ExchangeRateState copyWith({
    Currency? selectedCurrency,
    double? currentRate,
    bool? isLoading,
    String? error,
    DateTime? lastUpdate,
  }) {
    return ExchangeRateState(
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      currentRate: currentRate ?? this.currentRate,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

/// Provider pour gérer les taux de change
class ExchangeRateNotifier extends StateNotifier<ExchangeRateState> {
  final ExchangeRateService _service = ExchangeRateService();
  static const String _prefKey = 'selected_currency';

  ExchangeRateNotifier() : super(ExchangeRateState()) {
    _loadSavedCurrency();
    fetchCurrentRate();
  }

  /// Charger la devise sauvegardée
  Future<void> _loadSavedCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCurrency = prefs.getString(_prefKey);
      
      if (savedCurrency != null) {
        final currency = savedCurrency == 'USD' ? Currency.USD : Currency.CDF;
        state = state.copyWith(selectedCurrency: currency);
      }
    } catch (e) {
      print('[EXCHANGE PROVIDER] Erreur lors du chargement de la devise: $e');
    }
  }

  /// Sauvegarder la devise sélectionnée
  Future<void> _saveCurrency(Currency currency) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, currency.code);
    } catch (e) {
      print('[EXCHANGE PROVIDER] Erreur lors de la sauvegarde de la devise: $e');
    }
  }

  /// Changer la devise sélectionnée
  Future<void> setCurrency(Currency currency) async {
    state = state.copyWith(selectedCurrency: currency);
    await _saveCurrency(currency);
    
    // Rafraîchir le taux si nécessaire
    if (state.currentRate == null) {
      await fetchCurrentRate();
    }
  }

  /// Récupérer le taux actuel depuis l'API
  Future<void> fetchCurrentRate() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _service.getCurrentRate(from: 'USD', to: 'CDF');
      final rate = (data['rate'] as num).toDouble();

      state = state.copyWith(
        currentRate: rate,
        isLoading: false,
        lastUpdate: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors de la récupération du taux: $e',
      );
    }
  }

  /// Convertir un montant selon la devise sélectionnée
  double convertAmount(double amount, {Currency? from}) {
    final rate = state.currentRate ?? 2800.0; // Fallback

    // Si pas de devise source spécifiée, on utilise USD comme base
    final sourceCurrency = from ?? Currency.USD;

    // USD → CDF
    if (sourceCurrency == Currency.USD && state.selectedCurrency == Currency.CDF) {
      return amount * rate;
    }

    // CDF → USD
    if (sourceCurrency == Currency.CDF && state.selectedCurrency == Currency.USD) {
      return amount / rate;
    }

    // Même devise, pas de conversion
    return amount;
  }

  /// Formater un montant avec le symbole de devise
  String formatAmount(double amount, {Currency? currency}) {
    final curr = currency ?? state.selectedCurrency;
    
    // Formatage avec séparateur de milliers (espace)
    // RegExp pour insérer un espace tous les 3 chiffres
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final String Function(Match) mathFunc = (Match match) => '${match[1]} ';

    String formatted;
    if (curr == Currency.USD) {
      // Pour USD: on garde 2 décimales
      final parts = amount.toStringAsFixed(2).split('.');
      parts[0] = parts[0].replaceAllMapped(reg, mathFunc);
      formatted = parts.join('.');
      return '\$${formatted}';
    } else {
      // Pour CDF: pas de décimales
      formatted = amount.toStringAsFixed(0).replaceAllMapped(reg, mathFunc);
      return '${formatted} FC';
    }
  }

  /// Formater un prix de produit (toujours stocké en USD dans la DB)
  String formatProductPrice(double usdPrice) {
    if (state.selectedCurrency == Currency.USD) {
      return formatAmount(usdPrice, currency: Currency.USD);
    } else {
      final convertedPrice = convertAmount(usdPrice, from: Currency.USD);
      return formatAmount(convertedPrice, currency: Currency.CDF);
    }
  }
}

/// Provider global pour les taux de change
final exchangeRateProvider = StateNotifierProvider<ExchangeRateNotifier, ExchangeRateState>((ref) {
  return ExchangeRateNotifier();
});
