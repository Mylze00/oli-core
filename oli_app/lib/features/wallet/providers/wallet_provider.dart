import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';
import '../models/transaction_model.dart';
import '../../../core/services/hive_cache_service.dart';

// --- Résultat du dépôt Mobile Money ---
class DepositResult {
  final bool success;
  final String? oliOrderId;   // Pour le polling de statut
  final double? netAmountFC;  // Montant net crédité
  final String? error;

  const DepositResult({
    required this.success,
    this.oliOrderId,
    this.netAmountFC,
    this.error,
  });
}

// --- STATE ---
class WalletState {
  final double balance;
  final List<WalletTransaction> transactions;
  final bool isLoading;
  final String? error;

  WalletState({
    this.balance = 0.0,
    this.transactions = const [],
    this.isLoading = false,
    this.error,
  });

  WalletState copyWith({
    double? balance,
    List<WalletTransaction>? transactions,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// --- PROVIDER ---
final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref);
});

// --- NOTIFIER ---
class WalletNotifier extends StateNotifier<WalletState> {
  final Ref _ref;

  WalletNotifier(this._ref) : super(WalletState());

  Dio get _dio => _ref.read(dioProvider);

  Future<void> loadWalletData() async {
    state = state.copyWith(isLoading: true, error: null);

    // --- CACHE OFFLINE-FIRST ---
    try {
      final cachedBal = HiveCacheService.getCache('wallet_balance_cache');
      final cachedHist = HiveCacheService.getCache('wallet_history_cache');
      
      double bal = state.balance;
      List<WalletTransaction> hist = state.transactions;
      
      if (cachedBal != null) {
        bal = double.tryParse(cachedBal.toString()) ?? bal;
      }
      if (cachedHist != null && cachedHist is List) {
        hist = cachedHist.map((e) => WalletTransaction.fromJson(e)).toList();
      }
      
      if (cachedBal != null || cachedHist != null) {
        state = state.copyWith(balance: bal, transactions: hist);
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lecture cache wallet: $e');
    }
    // ---------------------------

    try {
      final results = await Future.wait([
        _dio.get(ApiConfig.walletBalance),
        _dio.get(ApiConfig.walletTransactions),
      ]);

      final balRes = results[0];
      final histRes = results[1];

      double balance = 0.0;
      if (balRes.statusCode == 200) {
        balance = double.parse(balRes.data['balance'].toString());
      }

      List<WalletTransaction> transactions = [];
      if (histRes.statusCode == 200) {
        final List list = histRes.data is List ? histRes.data : [];
        transactions = list.map((e) => WalletTransaction.fromJson(e)).toList();
        HiveCacheService.setCache('wallet_history_cache', list);
      }

      HiveCacheService.setCache('wallet_balance_cache', balance.toString());

      state = state.copyWith(
        isLoading: false,
        balance: balance,
        transactions: transactions,
      );
    } catch (e) {
      debugPrint('❌ Erreur loadWalletData: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Dépôt Mobile Money via Unipesa
  /// Retourne un [DepositResult] avec l'oliOrderId pour le polling du statut
  Future<DepositResult> deposit({
    required double amount,
    required String provider,
    required String phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post(ApiConfig.unipesaDeposit, data: {
        'amountFC': amount,
        'phone': phone,
      });

      state = state.copyWith(isLoading: false);

      if (response.statusCode == 200) {
        final data = response.data;
        return DepositResult(
          success: true,
          oliOrderId: data['oliOrderId'] as String?,
          netAmountFC: (data['netAmountFC'] as num?)?.toDouble() ?? amount,
        );
      } else {
        final errMsg = response.data['error'] ?? 'Erreur inconnue';
        state = state.copyWith(error: errMsg.toString());
        return DepositResult(success: false, error: errMsg.toString());
      }
    } on DioException catch (e) {
      final errMsg = e.response?.data?['error'] ?? e.message ?? 'Erreur réseau';
      state = state.copyWith(isLoading: false, error: errMsg.toString());
      return DepositResult(success: false, error: errMsg.toString());
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return DepositResult(success: false, error: e.toString());
    }
  }

  Future<bool> withdraw({
    required double amount,
    required String provider,
    required String phone,
  }) async {
    return _performTransaction(ApiConfig.walletWithdraw, {
      'amount': amount,
      'provider': provider,
      'phoneNumber': phone,
    });
  }

  Future<bool> transfer({
    required double amount,
    required String recipientPhone,
    String? note,
  }) async {
    return _performTransaction(ApiConfig.walletTransfer, {
      'amount': amount,
      'recipient_phone': recipientPhone,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<bool> depositByCard({
    required String cardNumber,
    required String expiryDate,
    required String cvv,
    required String cardholderName,
    required double amount,
  }) async {
    return _performTransaction(ApiConfig.walletDepositCard, {
      'amount': amount,
      'cardNumber': cardNumber,
      'expiryDate': expiryDate,
      'cvv': cvv,
      'cardholderName': cardholderName,
    });
  }

  Future<bool> _performTransaction(String url, Map<String, dynamic> body) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post(url, data: body);

      if (response.statusCode == 200) {
        await loadWalletData();
        return true;
      } else {
        final err = response.data;
        state = state.copyWith(isLoading: false, error: err['error'] ?? 'Erreur inconnue');
        return false;
      }
    } on DioException catch (e) {
      final errMsg = e.response?.data?['error'] ?? e.message ?? 'Erreur réseau';
      state = state.copyWith(isLoading: false, error: errMsg.toString());
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}
