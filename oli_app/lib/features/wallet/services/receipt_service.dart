import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction_model.dart';

/// Génère et affiche/partage un reçu PDF pour une transaction
class ReceiptService {
  /// Ouvre le viewer PDF (impression, partage, etc.)
  Future<void> showReceipt(BuildContext context, WalletTransaction tx) async {
    final pdfBytes = await _buildPdf(tx);
    if (!context.mounted) return;

    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'recu_oli_${tx.id}.pdf',
    );
  }

  /// Génère les bytes PDF du reçu
  Future<Uint8List> _buildPdf(WalletTransaction tx) async {
    final doc = pw.Document();
    final isCredit = tx.type == 'deposit' || tx.type == 'refund';
    final statusColor = tx.status == 'completed'
        ? PdfColors.green700
        : tx.status == 'failed'
            ? PdfColors.red700
            : PdfColors.orange700;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── En-tête ─────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'OLI CASH',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.Text(
                        'Reçu de transaction',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Text(
                      tx.status == 'completed'
                          ? '✓ Complété'
                          : tx.status == 'failed'
                              ? '✗ Échoué'
                              : '⏳ En attente',
                      style: pw.TextStyle(
                        color: statusColor,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 24),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 16),

              // ── Montant ────────────────────────────────────────────────
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      isCredit ? '+ ${tx.amount.toStringAsFixed(2)} \$' : '- ${tx.amount.toStringAsFixed(2)} \$',
                      style: pw.TextStyle(
                        fontSize: 36,
                        fontWeight: pw.FontWeight.bold,
                        color: isCredit ? PdfColors.green700 : PdfColors.red700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      tx.description,
                      style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 12),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 16),

              // ── Détails ────────────────────────────────────────────────
              _infoRow('Date', _formatDate(tx.createdAt)),
              _infoRow('Type', tx.type),
              if (tx.provider != null) _infoRow('Fournisseur', tx.provider!),
              if (tx.reference != null) _infoRow('Référence', tx.reference!),
              _infoRow('Solde après', '${tx.balanceAfter.toStringAsFixed(2)} \$'),
              _infoRow('N° Transaction', '#${tx.id}'),

              pw.SizedBox(height: 24),
              pw.Divider(color: PdfColors.grey200),
              pw.SizedBox(height: 12),

              // ── Footer ─────────────────────────────────────────────────
              pw.Center(
                child: pw.Text(
                  'Reçu généré par OLI — ${_formatDate(DateTime.now())}',
                  style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 9),
                ),
              ),
            ],
          );
        },
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 11)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

final receiptService = ReceiptService();
