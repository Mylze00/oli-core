/// Mouvement du wallet, tel que renvoyé par GET /api/wallet/transactions.
class WalletTransaction {
  final int id;
  final String type; // deposit, withdrawal, transfer, payment, refund, reward, credit, fee, escrow_*…
  final double amount; // > 0 entrée, < 0 sortie
  final double balanceBefore;
  final double balanceAfter;
  final String currency;
  final String? provider;
  final String? reference;
  final String status; // completed, pending, failed, cancelled, reversed
  final String description;
  final DateTime createdAt;
  final int? orderId;
  final Map<String, dynamic> metadata;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.currency = 'FC',
    this.provider,
    this.reference,
    required this.status,
    required this.description,
    required this.createdAt,
    this.orderId,
    this.metadata = const {},
  });

  /// Frais prélevés (présents pour les retraits et transferts)
  double? get feeFC => _num(metadata['feeAmount']);

  /// Montant net (retrait : montant reçu sur le Mobile Money)
  double? get netFC => _num(metadata['netAmount']);

  String? get phoneNumber => metadata['phoneNumber']?.toString();

  static double? _num(dynamic v) => v == null ? null : double.tryParse(v.toString());

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'];
    return WalletTransaction(
      id: (json['id'] as num).toInt(),
      type: json['type'].toString(),
      amount: double.parse(json['amount'].toString()),
      balanceBefore: double.tryParse(json['balance_before']?.toString() ?? '') ?? 0,
      balanceAfter: double.parse(json['balance_after'].toString()),
      currency: (json['currency'] ?? 'FC').toString(),
      provider: json['provider']?.toString(),
      reference: json['reference']?.toString(),
      status: (json['status'] ?? 'completed').toString(),
      description: (json['description'] ?? '').toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
      orderId: json['order_id'] == null ? null : (json['order_id'] as num).toInt(),
      metadata: meta is Map<String, dynamic> ? meta : const {},
    );
  }
}
