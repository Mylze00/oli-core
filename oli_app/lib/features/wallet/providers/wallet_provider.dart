import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';
import '../models/transaction_model.dart';

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
    this.error
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
    try {
      // Appels parallèles au lieu de séquentiels (#12)
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
      }

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

  Future<bool> deposit({required double amount, required String provider, required String phone}) async {
    return _performTransaction(ApiConfig.walletDeposit, {
      'amount': amount,
      'provider': provider,
      'phoneNumber': phone
    });
  }

  Future<bool> withdraw({required double amount, required String provider, required String phone}) async {
    return _performTransaction(ApiConfig.walletWithdraw, {
      'amount': amount,
      'provider': provider,
      'phoneNumber': phone
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
