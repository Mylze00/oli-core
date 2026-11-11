import '../../contacts/utils/phone_normalizer.dart';

/// Format d'un ID Oli : OLI-1234-5678.
final RegExp idOliPattern = RegExp(r'^OLI-\d{4}-\d{4}$', caseSensitive: false);

/// Contenu du QR « Recevoir ».
///
/// - Nouveau format : `oli://pay?u=<ID Oli>` — le numéro n'y figure pas.
/// - Repli pour un ancien compte sans ID Oli : `oli://pay?id=<téléphone>`.
/// - [amount] (FC) facultatif : `…&amount=5000`.
/// Renvoie null si le compte n'a ni ID Oli ni numéro.
String? buildPaymentQrData({required String idOli, required String phone, double? amount}) {
  final params = <String, String>{};
  if (idOli.isNotEmpty) {
    params['u'] = idOli;
  } else if (phone.isNotEmpty) {
    params['id'] = phone;
  } else {
    return null;
  }
  if (amount != null && amount > 0) params['amount'] = amount.toStringAsFixed(0);
  return Uri(scheme: 'oli', host: 'pay', queryParameters: params).toString();
}

/// Code de paiement lu dans un QR ou saisi à la main.
class PaymentCode {
  /// Numéro normalisé (+243…) ou ID Oli en majuscules.
  final String identifier;

  /// Montant demandé en FC, s'il y en a un.
  final double? amount;

  const PaymentCode(this.identifier, {this.amount});
}

/// Lit un QR Oli ou une saisie manuelle :
/// - `oli://pay?u=OLI-1234-5678[&amount=…]` (format actuel)
/// - `oli://pay?id=+243…` et `oli://transfer?phone=…` (anciens QR, toujours acceptés)
/// - un ID Oli ou un numéro tapé directement (0812…, +243…, 243…).
/// Renvoie null si ce n'est pas un code Oli valide.
PaymentCode? parsePaymentCode(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final uri = Uri.tryParse(text);
  if (uri != null && uri.scheme == 'oli') {
    final amount = double.tryParse(uri.queryParameters['amount'] ?? '');
    final validAmount = amount != null && amount > 0 ? amount : null;

    String? value;
    if (uri.host == 'pay') {
      value = uri.queryParameters['u'] ?? uri.queryParameters['id'];
    } else if (uri.host == 'transfer') {
      value = uri.queryParameters['phone'];
    }
    // Un « + » non encodé est lu comme un espace dans les anciens QR.
    final identifier = value == null ? null : _identifier(value.replaceAll(' ', '+'));
    return identifier == null ? null : PaymentCode(identifier, amount: validAmount);
  }

  final identifier = _identifier(text);
  return identifier == null ? null : PaymentCode(identifier);
}

String? _identifier(String value) {
  final upper = value.trim().toUpperCase();
  if (idOliPattern.hasMatch(upper)) return upper;
  return normalizePhone(value);
}
