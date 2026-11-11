import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';
import '../models/transaction_model.dart';
import '../../../core/services/hive_cache_service.dart';
import 'dart:async';

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
  Timer? _syncTimer;

  WalletNotifier(this._ref) : super(WalletState()) {
    _startBackgroundSync();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void _startBackgroundSync() {
    // Actualisation silencieuse toutes les 15 secondes
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      loadWalletData(background: true);
    });
  }

  Dio get _dio => _ref.read(dioProvider);

  Future<void> loadWalletData({bool background = false}) async {
    if (!background) {
      state = state.copyWith(isLoading: true, error: null);
    }

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
        final balVal = balRes.data['balanceFC'] ?? balRes.data['balance'] ?? 0;
        balance = double.parse(balVal.toString());
      }

      List<WalletTransaction> transactions = [];
      if (histRes.statusCode == 200) {
        dynamic data = histRes.data;
        List list = [];
        if (data is List) {
          list = data;
        } else if (data is Map && data.containsKey('transactions')) {
          list = data['transactions'] as List;
        }
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
      if (!background) {
        debugPrint('❌ Erreur loadWalletData: $e');
        state = state.copyWith(isLoading: false, error: e.toString());
      }
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

  /// Retrait Mobile Money via Unipesa
  /// Retourne un [DepositResult] avec l'oliOrderId pour le polling du statut
  Future<DepositResult> withdraw({
    required double amount,
    required String provider,
    required String phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post(ApiConfig.walletWithdraw, data: {
        'amountFC': amount,
        'provider': provider,
        'phone': phone,
      });

      state = state.copyWith(isLoading: false);

      if (response.statusCode == 200) {
        final data = response.data;
        return DepositResult(
          success: true,
          oliOrderId: data['oliOrderId'] as String?,
          netAmountFC: (data['amountFC'] as num?)?.toDouble() ?? amount,
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

  /// Transfert P2P vers le compte [receiverId].
  /// [idempotencyKey] : clé unique de cet envoi (voir [newTransferKey]). Si la
  /// requête est rejouée (réseau coupé, double appui), le serveur ne débite
  /// qu'une seule fois.
  Future<bool> transfer({
    required double amount,
    required int receiverId,
    required String idempotencyKey,
    String? note,
  }) async {
    return _performTransaction(
      ApiConfig.walletTransfer,
      {
        'amount': amount,
        'receiverId': receiverId,
        if (note != null && note.isNotEmpty) 'note': note,
      },
      headers: {'Idempotency-Key': idempotencyKey},
    );
  }

  /// Cherche un compte Oli par numéro (0812…, +243…) ou ID Oli (OLI-1234-5678).
  /// Renvoie le compte trouvé, ou un message d'erreur à afficher.
  Future<({Map<String, dynamic>? user, String? error})> resolveRecipient(
      String identifier) async {
    try {
      final response = await _dio.get(
        ApiConfig.walletResolveRecipient,
        queryParameters: {'identifier': identifier},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return (user: Map<String, dynamic>.from(response.data['user'] as Map), error: null);
      }
      return (user: null, error: 'Aucun compte Oli trouvé');
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['error']?.toString() : null;
      return (user: null, error: message ?? 'Recherche impossible. Vérifiez votre connexion.');
    } catch (_) {
      return (user: null, error: 'Recherche impossible. Vérifiez votre connexion.');
    }
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

  Future<bool> _performTransaction(String url, Map<String, dynamic> body,
      {Map<String, String>? headers}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post(url,
          data: body, options: headers == null ? null : Options(headers: headers));

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

/// Nouvelle clé anti-doublon pour un envoi d'argent (32 caractères aléatoires).
/// À générer une fois par envoi et à réutiliser si l'utilisateur réessaie.
String newTransferKey() {
  final random = Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
}
