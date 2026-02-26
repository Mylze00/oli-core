import 'package:flutter/material.dart';
import '../../wallet/services/biometric_service.dart';

/// Bottom sheet affiché dans le chat pour demander de l'argent à l'autre utilisateur
class RequestFundsSheet extends StatefulWidget {
  final String recipientName;
  final Function(double amount, String? note) onRequest;

  const RequestFundsSheet({
    super.key,
    required this.recipientName,
    required this.onRequest,
  });

  @override
  State<RequestFundsSheet> createState() => _RequestFundsSheetState();
}

class _RequestFundsSheetState extends State<RequestFundsSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Montant invalide');
      return;
    }

    // Biométrie
    final ok = await biometricService.authenticate(
      reason: 'Confirmer la demande de ${amount.toStringAsFixed(0)} FC',
    );
    if (!ok) {
      setState(() => _error = 'Authentification échouée');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      await widget.onRequest(amount, _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim());
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Titre
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.request_page_outlined, color: Colors.orange.shade600, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Demander de l\'argent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('à ${widget.recipientName}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Montant
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 28),
                suffixText: 'FC',
                suffixStyle: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.primaryColor, width: 2),
                ),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),

            const SizedBox(height: 12),

            // Note optionnelle
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                hintText: 'Motif (optionnel)…',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.notes_rounded, color: Colors.grey.shade400, size: 18),
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),

            const SizedBox(height: 20),

            // Bouton
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_isLoading ? 'Envoi…' : 'Envoyer la demande'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
