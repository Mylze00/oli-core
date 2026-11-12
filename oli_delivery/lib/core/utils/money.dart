/// Montant en francs congolais, avec espaces des milliers : 4 621 FC.
String formatFc(dynamic amount) {
  final value = (amount is num) ? amount.toDouble() : double.tryParse('$amount') ?? 0.0;
  final digits = value.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]} ',
      );
  return '$digits FC';
}
