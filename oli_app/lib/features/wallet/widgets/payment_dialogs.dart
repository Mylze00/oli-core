import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wallet_provider.dart';

/// Dialog pour sélectionner la méthode de paiement (Mobile Money ou Carte)
class PaymentMethodSelectionDialog extends StatefulWidget {
  const PaymentMethodSelectionDialog({super.key});

  @override
  State<PaymentMethodSelectionDialog> createState() => _PaymentMethodSelectionDialogState();
}

class _PaymentMethodSelectionDialogState extends State<PaymentMethodSelectionDialog> {
  String _paymentMethod = 'mobile'; // 'mobile' or 'card'

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recharger mon wallet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choisissez votre méthode de paiement:'),
          const SizedBox(height: 16),
          _PaymentMethodOption(
            icon: Icons.phone_android,
            title: 'Mobile Money',
            subtitle: 'Orange Money, M-Pesa, Airtel',
            isSelected: _paymentMethod == 'mobile',
            onTap: () => setState(() => _paymentMethod = 'mobile'),
          ),
          const SizedBox(height: 12),
          _PaymentMethodOption(
            icon: Icons.credit_card,
            title: 'Carte Bancaire',
            subtitle: 'Visa, Mastercard',
            isSelected: _paymentMethod == 'card',
            onTap: () => setState(() => _paymentMethod = 'card'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, _paymentMethod);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E7DBA),
          ),
          child: const Text('Continuer'),
        ),
      ],
    );
  }
}

class _PaymentMethodOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF1E7DBA) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? const Color(0xFF1E7DBA).withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1E7DBA) : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? const Color(0xFF1E7DBA) : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF1E7DBA),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialog pour paiement par carte bancaire
class CardPaymentDialog extends ConsumerStatefulWidget {
  const CardPaymentDialog({super.key});

  @override
  ConsumerState<CardPaymentDialog> createState() => _CardPaymentDialogState();
}

class _CardPaymentDialogState extends ConsumerState<CardPaymentDialog> {
  final _amountCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _formatCardNumber(String value) {
    final text = value.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) {
        buffer.write(' ');
      }
    }
    final formatted = buffer.toString();
    _cardNumberCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _formatExpiry(String value) {
    final text = value.replaceAll('/', '');
    if (text.length >= 2) {
      final formatted = '${text.substring(0, 2)}/${text.substring(2)}';
      _expiryCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paiement par Carte'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sandbox: Utilisez 4242 4242 4242 4242 pour succès, 4000 xxxx xxxx xxxx pour échec',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cardNumberCtrl,
              keyboardType: TextInputType.number,
              maxLength: 19,
              onChanged: _formatCardNumber,
              decoration: const InputDecoration(
                labelText: 'Numéro de carte',
                hintText: '1234 5678 9012 3456',
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiryCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    onChanged: _formatExpiry,
                    decoration: const InputDecoration(
                      labelText: 'MM/YY',
                      hintText: '12/25',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cvvCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nom du titulaire',
                hintText: 'JOHN DOE',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _processPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E7DBA),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Payer'),
        ),
      ],
    );
  }

  Future<void> _processPayment() async {
    setState(() => _errorMessage = null);

    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Montant invalide');
      return;
    }

    final cardNumber = _cardNumberCtrl.text.replaceAll(' ', '');
    if (cardNumber.length != 16) {
      setState(() => _errorMessage = 'Numéro de carte invalide');
      return;
    }

    final expiry = _expiryCtrl.text;
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(expiry)) {
      setState(() => _errorMessage = 'Date expiration invalide (MM/YY)');
      return;
    }

    final cvv = _cvvCtrl.text;
    if (cvv.length < 3) {
      setState(() => _errorMessage = 'CVV invalide');
      return;
    }

    setState(() => _isLoading = true);

    final notifier = ref.read(walletProvider.notifier);
    final success = await notifier.depositByCard(
      cardNumber: cardNumber,
      expiryDate: expiry,
      cvv: cvv,
      cardholderName: _nameCtrl.text.isEmpty ? 'Card Holder' : _nameCtrl.text,
      amount: amount,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rechargement réussi!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final error = ref.read(walletProvider).error;
        setState(() => _errorMessage = error ?? 'Échec du paiement');
      }
    }
  }
}
