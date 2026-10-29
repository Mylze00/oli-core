import 'dart:math';
import 'package:flutter/material.dart';

class WesternUnionSuccessDialog extends StatelessWidget {
  final String operationType; // ENVOIE or RETRAIT
  final String amount;
  final String targetCountry;
  final String senderName;
  final String receiverName;
  final String? mtcnCode;
  final String paymentMethod;
  final String accountNumber;

  const WesternUnionSuccessDialog({
    super.key,
    required this.operationType,
    required this.amount,
    required this.targetCountry,
    required this.senderName,
    required this.receiverName,
    this.mtcnCode,
    required this.paymentMethod,
    required this.accountNumber,
  });

  @override
  Widget build(BuildContext context) {
    final reference = mtcnCode != null && mtcnCode!.isNotEmpty
        ? mtcnCode!
        : "${1000 + Random().nextInt(9000)}-${1000 + Random().nextInt(9000)}-${1000 + Random().nextInt(9000)}";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 36),
            ),
            const SizedBox(height: 14),

            Text(
              operationType == "ENVOIE"
                  ? "Demande d'envoi enregistrée !"
                  : "Demande de retrait enregistrée !",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D2338),
              ),
            ),
            const SizedBox(height: 6),

            Text(
              "Votre dossier Western Union est en cours de traitement.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Summary container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildRow("Référence / MTCN", reference, isBold: true),
                  const Divider(height: 12),
                  _buildRow("Montant", amount, isBold: true),
                  const Divider(height: 12),
                  _buildRow("Pays", targetCountry),
                  const Divider(height: 12),
                  _buildRow("Expéditeur", senderName),
                  const Divider(height: 12),
                  _buildRow("Bénéficiaire", receiverName),
                  const Divider(height: 12),
                  _buildRow("Canal", paymentMethod),
                  const Divider(height: 12),
                  _buildRow("Numéro de compte", accountNumber),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Close button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog
                  Navigator.of(context).pop(); // return to WU home
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF163750),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  "Terminer",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
