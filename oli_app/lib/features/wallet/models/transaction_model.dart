class WalletTransaction {
  final int id;
  final String type; // 'deposit', 'withdrawal'
  final double amount;
  final double balanceAfter;
  final String? provider;
  final String? reference;
  final String status;
  final String description;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.provider,
    this.reference,
    required this.status,
    required this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'],
      type: json['type'],
      amount: double.parse(json['amount'].toString()),
      balanceAfter: double.parse(json['balance_after'].toString()),
      provider: json['provider'],
      reference: json['reference'],
      status: json['status'],
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
