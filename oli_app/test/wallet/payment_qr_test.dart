import 'package:flutter_test/flutter_test.dart';
import 'package:oli_app/features/wallet/utils/payment_qr.dart';

void main() {
  group('buildPaymentQrData', () {
    test('utilise l\'ID Oli et jamais le numéro', () {
      final data = buildPaymentQrData(idOli: 'OLI-5678-1234', phone: '+243812345678');
      expect(data, 'oli://pay?u=OLI-5678-1234');
      expect(data, isNot(contains('243812345678')));
    });

    test('ajoute un montant facultatif', () {
      expect(
        buildPaymentQrData(idOli: 'OLI-5678-1234', phone: '', amount: 5000),
        'oli://pay?u=OLI-5678-1234&amount=5000',
      );
    });

    test('repli sur le numéro pour un compte sans ID Oli', () {
      expect(buildPaymentQrData(idOli: '', phone: '+243812345678'), 'oli://pay?id=%2B243812345678');
    });

    test('null sans identifiant', () {
      expect(buildPaymentQrData(idOli: '', phone: ''), isNull);
    });
  });

  group('parsePaymentCode', () {
    test('lit le nouveau format avec montant', () {
      final code = parsePaymentCode('oli://pay?u=oli-5678-1234&amount=5000');
      expect(code?.identifier, 'OLI-5678-1234');
      expect(code?.amount, 5000);
    });

    test('lit le QR qu\'il génère lui-même (aller-retour)', () {
      final data = buildPaymentQrData(idOli: '', phone: '+243812345678')!;
      expect(parsePaymentCode(data)?.identifier, '+243812345678');
    });

    test('accepte les anciens QR, y compris un « + » lu comme espace', () {
      expect(parsePaymentCode('oli://pay?id= 243812345678')?.identifier, '+243812345678');
      expect(parsePaymentCode('oli://transfer?phone=0812345678')?.identifier, '+243812345678');
    });

    test('accepte une saisie manuelle', () {
      expect(parsePaymentCode('0812 345 678')?.identifier, '+243812345678');
      expect(parsePaymentCode('OLI-5678-1234')?.identifier, 'OLI-5678-1234');
    });

    test('refuse ce qui n\'est pas un code Oli', () {
      expect(parsePaymentCode('https://exemple.com'), isNull);
      expect(parsePaymentCode('oli://pay?u=n-importe-quoi'), isNull);
      expect(parsePaymentCode('oli://pay?u=OLI-5678-1234&amount=-3')?.amount, isNull);
      expect(parsePaymentCode(''), isNull);
    });
  });
}
