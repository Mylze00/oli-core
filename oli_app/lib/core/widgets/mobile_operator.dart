import 'package:flutter/material.dart';

/// Opérateur Mobile Money d'un numéro congolais, reconnu à son préfixe.
/// Mêmes préfixes que le serveur (src/services/unipesa.service.js, _detectProvider).
enum MobileOperator {
  vodacom('M-Pesa', 'Vodacom', 'assets/images/operators/mpesa.png'),
  orange('Orange Money', 'Orange', 'assets/images/operators/orange_money.png'),
  airtel('Airtel Money', 'Airtel', 'assets/images/operators/airtel_money.png'),
  africell('Afrimoney', 'Africell', 'assets/images/operators/afrimoney.png'),
  unknown('Mobile Money', 'Mobile Money', null);

  /// Nom du service de paiement (ex. « M-Pesa »).
  final String serviceName;

  /// Nom du réseau (ex. « Vodacom »).
  final String networkName;

  /// Logo du service, ou null si le réseau n'est pas reconnu.
  final String? asset;

  const MobileOperator(this.serviceName, this.networkName, this.asset);

  static MobileOperator fromPhone(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    var local = digits.startsWith('243') ? digits.substring(3) : digits;
    if (!local.startsWith('0')) local = '0$local';
    if (local.length < 3) return MobileOperator.unknown;
    final prefix = local.substring(0, 3);
    if (const ['081', '082', '083'].contains(prefix)) return MobileOperator.vodacom;
    if (const ['084', '085', '089', '080'].contains(prefix)) return MobileOperator.orange;
    if (const ['099', '097', '098'].contains(prefix)) return MobileOperator.airtel;
    if (const ['090', '088', '086'].contains(prefix)) return MobileOperator.africell;
    return MobileOperator.unknown;
  }
}

/// Numéro lisible : +243 82 708 8682.
String formatCongoPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  var local = digits.startsWith('243') ? digits.substring(3) : digits;
  if (local.startsWith('0')) local = local.substring(1);
  if (local.length != 9) return phone;
  return '+243 ${local.substring(0, 2)} ${local.substring(2, 5)} ${local.substring(5)}';
}

/// Logo de l'opérateur d'un numéro, sur une pastille blanche arrondie
/// (les logos sont prévus pour un fond clair, y compris en mode sombre).
class OperatorLogo extends StatelessWidget {
  final String? phone;
  final double size;

  const OperatorLogo({super.key, required this.phone, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final operator = MobileOperator.fromPhone(phone);
    final radius = BorderRadius.circular(size * 0.26);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: operator.asset == null
          ? Icon(Icons.phone_android_rounded, size: size * 0.55, color: const Color(0xFF5F6673))
          : Image.asset(
              operator.asset!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.phone_android_rounded, size: size * 0.55, color: const Color(0xFF5F6673)),
            ),
    );
  }
}
