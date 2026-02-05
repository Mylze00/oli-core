import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Pour le Timer
import '../../../models/order_model.dart';
// import '../../../core/config/api_config.dart'; // Si disponible

class StripePaymentPage extends StatefulWidget {
  final Order order;

  const StripePaymentPage({super.key, required this.order});

  @override
  State<StripePaymentPage> createState() => _StripePaymentPageState();
}

class _StripePaymentPageState extends State<StripePaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  // URL du backend (Render Production)
  static const String _baseUrl = 'https://oli-core.onrender.com'; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Paiement Sécurisé'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Si on quitte, on retourne à l'accueil ou on prévient que la commande est en attente
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
      body: _isSuccess ? _buildSuccessView() : _buildPaymentForm(),
    );
  }

  Widget _buildPaymentForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Montant
            Center(
              child: Column(
                children: [
                  const Text('Montant à payer', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    '\$${widget.order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Carte
            const Text('Informations de carte', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            _buildTextField(
              controller: _cardNumberController,
              label: 'Numéro de carte',
              hint: '4242 4242 4242 4242',
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
                _CardNumberFormatter(),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _expiryController,
                    label: 'Expiration',
                    hint: 'MM/AA',
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      _ExpiryDateFormatter(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _cvvController,
                    label: 'CVV',
                    hint: '123',
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nameController,
              label: 'Nom sur la carte',
              hint: 'JEAN DUPONT',
              textCapitalization: TextCapitalization.characters,
            ),

            const SizedBox(height: 40),

            // Erreur
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),

            // Bouton Payer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Payer Maintenant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 20),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Paiement sécurisé par Stripe (Simulé)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 24),
          const Text('Paiement Réussi !', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Votre commande #${widget.order.id} a été payée.', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
            child: const Text('Retour à l\'accueil'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.grey),
        hintStyle: TextStyle(color: Colors.grey.shade700),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // VALIDATION STRICTE SIMULATION
    // Refuser les cartes qui ne sont pas des cartes de test Stripe valides (4242...)
    final cleanCardNumber = _cardNumberController.text.replaceAll(' ', '');
    final expiry = _expiryController.text;
    final cvv = _cvvController.text;

    bool isValid = true;
    String errorMsg = "";

    // 1. Check Numéro
    if (!cleanCardNumber.startsWith('4242')) {
       isValid = false;
       errorMsg = "Carte refusée. (Mode Test: Utilisez 4242...)";
    }
    
    // 2. Check CVV
    else if (cvv != '123') {
       isValid = false;
       errorMsg = "CVV invalide. (Mode Test: Utilisez 123)";
    }

    // 3. Check Date Expiration
    else if (expiry.length == 5 && expiry.contains('/')) {
       final parts = expiry.split('/');
       final month = int.tryParse(parts[0]) ?? 0;
       final year = int.tryParse(parts[1]) ?? 0;
       final now = DateTime.now();
       final currentYear = now.year % 100; // 2 digits
       
       if (month < 1 || month > 12) {
          isValid = false;
          errorMsg = "Mois invalide.";
       } else if (year < currentYear || (year == currentYear && month < now.month)) {
          isValid = false;
          errorMsg = "Carte expirée.";
       }
    } else {
       isValid = false;
       errorMsg = "Date invalide.";
    }

    if (!isValid) {
      await Future.delayed(const Duration(seconds: 1)); // Petit délai pour effet réaliste
      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // 1. Créer le PaymentIntent via notre backend
      final url = Uri.parse('$_baseUrl/api/payment/create-payment-intent');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': (widget.order.totalAmount * 100).toInt(), // En centimes
          'currency': 'usd',
          'metadata': {
            'orderId': widget.order.id, // IMPORTANT: Pour le lien Webhook
          }
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final clientSecret = data['client_secret'];

      if (clientSecret == null) throw Exception('Pas de client_secret reçu');

      // 2. Simuler la confirmation Stripe (Côté client)
      // Normalement ici on utilise Stripe.instance.confirmPayment(...)
      // Pour la simulation, on attend juste un peu
      await Future.delayed(const Duration(seconds: 2));

      // 3. Simuler l'envoi du Webhook (Optionnel: Le backend le fait manuellement pour l'instant via Postman/Curl, 
      // ou on peut appeler l'endpoint webhook nous même pour tester le flux complet d'un coup)
      // Pour être propre, on va appeler notre propre endpoint webhook de simulation
      
      await http.post(
        Uri.parse('$_baseUrl/api/payment/webhook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'payment_intent.succeeded',
          'data': {
            'object': data // On renvoie l'objet PaymentIntent complet reçu
          }
        }),
      );

      // Succès
      if (mounted) {
        setState(() {
          _isSuccess = true;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Échec du paiement: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// Formatters
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length));
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write('/');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length));
  }
}
