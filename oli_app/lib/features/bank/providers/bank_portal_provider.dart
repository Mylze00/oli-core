import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';

// ─── Modèles ────────────────────────────────────────────────────────────────

class LedgerEntry {
  final String txId;
  final String txHash;
  final String? prevTxHash;
  final String txType;
  final double amount;
  final double feeAmount;
  final double balanceBefore;
  final double balanceAfter;
  final String status;
  final DateTime confirmedAt;
  final String? counterpartName;

  const LedgerEntry({
    required this.txId,
    required this.txHash,
    this.prevTxHash,
    required this.txType,
    required this.amount,
    required this.feeAmount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.status,
    required this.confirmedAt,
    this.counterpartName,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        txId:          j['tx_id']?.toString() ?? '',
        txHash:        j['tx_hash']?.toString() ?? '',
        prevTxHash:    j['prev_tx_hash']?.toString(),
        txType:        j['tx_type']?.toString() ?? '',
        amount:        (j['amount'] as num?)?.toDouble() ?? 0,
        feeAmount:     (j['fee_amount'] as num?)?.toDouble() ?? 0,
        balanceBefore: (j['balance_before'] as num?)?.toDouble() ?? 0,
        balanceAfter:  (j['balance_after'] as num?)?.toDouble() ?? 0,
        status:        j['status']?.toString() ?? '',
        confirmedAt:   j['confirmed_at'] != null
            ? DateTime.tryParse(j['confirmed_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        counterpartName: j['counterpart_name']?.toString(),
      );
}

class EscrowEntry {
  final String escrowRef;
  final int orderId;
  final double amountLocked;
  final double sellerAmount;
  final double delivererAmount;
  final double oliFee;
  final String status;
  final DateTime lockedAt;
  final String? buyerName;
  final String? sellerName;

  const EscrowEntry({
    required this.escrowRef,
    required this.orderId,
    required this.amountLocked,
    required this.sellerAmount,
    required this.delivererAmount,
    required this.oliFee,
    required this.status,
    required this.lockedAt,
    this.buyerName,
    this.sellerName,
  });

  factory EscrowEntry.fromJson(Map<String, dynamic> j) => EscrowEntry(
        escrowRef:       j['escrow_ref']?.toString() ?? '',
        orderId:         (j['order_id'] as num?)?.toInt() ?? 0,
        amountLocked:    (j['amount_locked'] as num?)?.toDouble() ?? 0,
        sellerAmount:    (j['seller_amount'] as num?)?.toDouble() ?? 0,
        delivererAmount: (j['deliverer_amount'] as num?)?.toDouble() ?? 0,
        oliFee:          (j['oli_fee'] as num?)?.toDouble() ?? 0,
        status:          j['status']?.toString() ?? '',
        lockedAt: j['locked_at'] != null
            ? DateTime.tryParse(j['locked_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        buyerName:  j['buyer_name']?.toString(),
        sellerName: j['seller_name']?.toString(),
      );
}

class SessionEntry {
  final String deviceType;
  final String? deviceModel;
  final String? city;
  final String? country;
  final DateTime startedAt;
  final DateTime lastSeenAt;
  final int actionCount;
  final int financialActions;
  final bool isSuspicious;

  const SessionEntry({
    required this.deviceType,
    this.deviceModel,
    this.city,
    this.country,
    required this.startedAt,
    required this.lastSeenAt,
    required this.actionCount,
    required this.financialActions,
    required this.isSuspicious,
  });

  factory SessionEntry.fromJson(Map<String, dynamic> j) => SessionEntry(
        deviceType:       j['device_type']?.toString() ?? 'unknown',
        deviceModel:      j['device_model']?.toString(),
        city:             j['city']?.toString(),
        country:          j['country']?.toString(),
        startedAt: DateTime.tryParse(j['started_at']?.toString() ?? '') ?? DateTime.now(),
        lastSeenAt: DateTime.tryParse(j['last_seen_at']?.toString() ?? '') ?? DateTime.now(),
        actionCount:      (j['action_count'] as num?)?.toInt() ?? 0,
        financialActions: (j['financial_actions'] as num?)?.toInt() ?? 0,
        isSuspicious:     j['is_suspicious'] == true,
      );
}

class BankPortalState {
  final bool isLoading;
  final String? error;

  // Identité
  final String? oliAddress;
  final bool bankActive;

  // Finances
  final double walletBalance;
  final double totalDeposited;
  final double totalWithdrawn;
  final double fundsInEscrow;
  final int totalTransactions;
  final int activeEscrows;

  // Trust
  final double? trustScore;
  final String? fraudRiskLevel;

  // Profil
  final String? name;
  final String? currency;
  final bool isFrozen;
  final DateTime? lastSessionAt;
  final String? lastDevice;

  // Collections
  final List<LedgerEntry> ledger;
  final List<EscrowEntry> escrows;
  final List<SessionEntry> sessions;

  const BankPortalState({
    this.isLoading = false,
    this.error,
    this.oliAddress,
    this.bankActive = true,
    this.walletBalance = 0,
    this.totalDeposited = 0,
    this.totalWithdrawn = 0,
    this.fundsInEscrow = 0,
    this.totalTransactions = 0,
    this.activeEscrows = 0,
    this.trustScore,
    this.fraudRiskLevel,
    this.name,
    this.currency = 'USD',
    this.isFrozen = false,
    this.lastSessionAt,
    this.lastDevice,
    this.ledger = const [],
    this.escrows = const [],
    this.sessions = const [],
  });

  BankPortalState copyWith({
    bool? isLoading,
    String? error,
    String? oliAddress,
    bool? bankActive,
    double? walletBalance,
    double? totalDeposited,
    double? totalWithdrawn,
    double? fundsInEscrow,
    int? totalTransactions,
    int? activeEscrows,
    double? trustScore,
    String? fraudRiskLevel,
    String? name,
    String? currency,
    bool? isFrozen,
    DateTime? lastSessionAt,
    String? lastDevice,
    List<LedgerEntry>? ledger,
    List<EscrowEntry>? escrows,
    List<SessionEntry>? sessions,
  }) => BankPortalState(
    isLoading:         isLoading       ?? this.isLoading,
    error:             error,
    oliAddress:        oliAddress      ?? this.oliAddress,
    bankActive:        bankActive      ?? this.bankActive,
    walletBalance:     walletBalance   ?? this.walletBalance,
    totalDeposited:    totalDeposited  ?? this.totalDeposited,
    totalWithdrawn:    totalWithdrawn  ?? this.totalWithdrawn,
    fundsInEscrow:     fundsInEscrow   ?? this.fundsInEscrow,
    totalTransactions: totalTransactions ?? this.totalTransactions,
    activeEscrows:     activeEscrows   ?? this.activeEscrows,
    trustScore:        trustScore      ?? this.trustScore,
    fraudRiskLevel:    fraudRiskLevel  ?? this.fraudRiskLevel,
    name:              name            ?? this.name,
    currency:          currency        ?? this.currency,
    isFrozen:          isFrozen        ?? this.isFrozen,
    lastSessionAt:     lastSessionAt   ?? this.lastSessionAt,
    lastDevice:        lastDevice      ?? this.lastDevice,
    ledger:            ledger          ?? this.ledger,
    escrows:           escrows         ?? this.escrows,
    sessions:          sessions        ?? this.sessions,
  );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class BankPortalNotifier extends StateNotifier<BankPortalState> {
  final Dio _dio;

  BankPortalNotifier(this._dio) : super(const BankPortalState());

  Future<void> loadPortal() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _dio.get(ApiConfig.bankPortal);
      final p   = res.data['portal'] as Map<String, dynamic>? ?? {};

      state = state.copyWith(
        isLoading:         false,
        oliAddress:        p['oli_address']?.toString(),
        bankActive:        p['bank_active'] != false,
        walletBalance:     (p['wallet_balance'] as num?)?.toDouble() ?? 0,
        totalDeposited:    (p['total_deposited'] as num?)?.toDouble() ?? 0,
        totalWithdrawn:    (p['total_withdrawn'] as num?)?.toDouble() ?? 0,
        fundsInEscrow:     (p['funds_in_escrow'] as num?)?.toDouble() ?? 0,
        totalTransactions: (p['total_transactions'] as num?)?.toInt() ?? 0,
        activeEscrows:     (p['active_escrows'] as num?)?.toInt() ?? 0,
        trustScore:        (p['trust_score'] as num?)?.toDouble(),
        fraudRiskLevel:    p['fraud_risk_level']?.toString(),
        name:              p['name']?.toString(),
        currency:          p['currency']?.toString() ?? 'USD',
        isFrozen:          p['is_frozen'] == true,
        lastDevice:        p['last_device']?.toString(),
        lastSessionAt:     p['last_session_at'] != null
            ? DateTime.tryParse(p['last_session_at'].toString())
            : null,
        ledger: (p['ledger'] as List<dynamic>? ?? [])
            .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        escrows: (p['active_escrows_detail'] as List<dynamic>? ?? [])
            .map((e) => EscrowEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        sessions: (p['recent_sessions'] as List<dynamic>? ?? [])
            .map((e) => SessionEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> verifyTx(String txHash) async {
    try {
      final res = await _dio.get(ApiConfig.bankVerify(txHash));
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final bankPortalProvider = StateNotifierProvider<BankPortalNotifier, BankPortalState>((ref) {
  final dio = ref.watch(dioProvider);
  return BankPortalNotifier(dio);
});
