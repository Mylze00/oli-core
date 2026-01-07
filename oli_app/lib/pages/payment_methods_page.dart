import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Page "Méthodes de Paiement" - Stripe + Mobile Money Ready
class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  // Mock data - À remplacer par vraies données (API + Stripe)
  final List<SavedCard> _savedCards = [
    SavedCard(id: '1', last4: '4242', brand: 'Visa', expiryMonth: 12, expiryYear: 2025, isDefault: true),
  ];

  final List<MobileMoneyAccount> _mobileMoneyAccounts = [
    MobileMoneyAccount(id: '1', provider: MobileMoneyProvider.mpesa, phoneNumber: '+243 820 000 000', isDefault: false),
  ];

  final List<BankAccount> _bankAccounts = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Méthodes de Paiement'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- CARTES BANCAIRES ---
          _buildSectionHeader('Cartes bancaires', Icons.credit_card, Colors.blue),
          if (_savedCards.isEmpty)
            _buildEmptyCard('Aucune carte enregistrée')
          else
            ..._savedCards.map((card) => _buildCardTile(card)),
          _buildAddButton('Ajouter une carte', Icons.add_card, () => _showAddCardDialog()),

          const SizedBox(height: 24),

          // --- MOBILE MONEY ---
          _buildSectionHeader('Mobile Money', Icons.phone_android, Colors.green),
          if (_mobileMoneyAccounts.isEmpty)
            _buildEmptyCard('Aucun compte Mobile Money')
          else
            ..._mobileMoneyAccounts.map((account) => _buildMobileMoneyTile(account)),
          _buildAddButton('Ajouter Mobile Money', Icons.add, () => _showAddMobileMoneyDialog()),

          const SizedBox(height: 24),

          // --- COMPTES BANCAIRES ---
          _buildSectionHeader('Comptes bancaires (Virement)', Icons.account_balance, Colors.orange),
          if (_bankAccounts.isEmpty)
            _buildEmptyCard('Aucun compte bancaire')
          else
            ..._bankAccounts.map((account) => _buildBankAccountTile(account)),
          _buildAddButton('Ajouter un compte', Icons.add_business, () => _showAddBankAccountDialog()),

          const SizedBox(height: 32),

          // --- INFO SÉCURITÉ ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Paiements sécurisés', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Vos données sont chiffrées et protégées par Stripe.',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(message, style: TextStyle(color: Colors.grey.shade600)),
      ),
    );
  }

  Widget _buildCardTile(SavedCard card) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: card.isDefault ? Border.all(color: Colors.blueAccent, width: 1.5) : null,
      ),
      child: Row(
        children: [
          _getCardBrandIcon(card.brand),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('•••• ${card.last4}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    if (card.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Par défaut', style: TextStyle(color: Colors.blueAccent, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text('Expire ${card.expiryMonth.toString().padLeft(2, '0')}/${card.expiryYear}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            color: const Color(0xFF2A2A2A),
            onSelected: (value) {
              if (value == 'default') _setDefaultCard(card);
              if (value == 'delete') _deleteCard(card);
            },
            itemBuilder: (context) => [
              if (!card.isDefault) const PopupMenuItem(value: 'default', child: Text('Définir par défaut', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMoneyTile(MobileMoneyAccount account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: account.isDefault ? Border.all(color: Colors.green, width: 1.5) : null,
      ),
      child: Row(
        children: [
          _getMobileMoneyIcon(account.provider),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(account.provider.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    if (account.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Par défaut', style: TextStyle(color: Colors.green, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(account.phoneNumber, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            color: const Color(0xFF2A2A2A),
            onSelected: (value) {
              if (value == 'default') _setDefaultMobileMoney(account);
              if (value == 'delete') _deleteMobileMoney(account);
            },
            itemBuilder: (context) => [
              if (!account.isDefault) const PopupMenuItem(value: 'default', child: Text('Définir par défaut', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankAccountTile(BankAccount account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: Colors.orange, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.bankName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('•••• ${account.last4}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteBankAccount(account),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blueAccent,
          side: const BorderSide(color: Colors.blueAccent),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _getCardBrandIcon(String brand) {
    Color color;
    String text;
    switch (brand.toLowerCase()) {
      case 'visa':
        color = Colors.blue;
        text = 'VISA';
        break;
      case 'mastercard':
        color = Colors.orange;
        text = 'MC';
        break;
      default:
        color = Colors.grey;
        text = brand.substring(0, 2).toUpperCase();
    }
    return Container(
      width: 48,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Center(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10))),
    );
  }

  Widget _getMobileMoneyIcon(MobileMoneyProvider provider) {
    Color color;
    switch (provider) {
      case MobileMoneyProvider.mpesa:
        color = Colors.green;
        break;
      case MobileMoneyProvider.orangeMoney:
        color = Colors.orange;
        break;
      case MobileMoneyProvider.airtelMoney:
        color = Colors.red;
        break;
      case MobileMoneyProvider.mtn:
        color = Colors.yellow;
        break;
    }
    return Container(
      width: 48,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.phone_android, color: color, size: 20),
    );
  }

  // =====================================================
  // STRIPE INTEGRATION - ADD CARD DIALOG
  // =====================================================
  void _showAddCardDialog() {
    final cardNumberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ajouter une carte', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 20),

            // Numéro de carte
            _buildTextField(
              controller: cardNumberController,
              label: 'Numéro de carte',
              hint: '4242 4242 4242 4242',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
                _CardNumberFormatter(),
              ],
            ),
            const SizedBox(height: 16),

            // Expiry & CVV
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: expiryController,
                    label: 'Expiration',
                    hint: 'MM/AA',
                    keyboardType: TextInputType.number,
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
                    controller: cvvController,
                    label: 'CVV',
                    hint: '123',
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Nom sur la carte
            _buildTextField(
              controller: nameController,
              label: 'Nom sur la carte',
              hint: 'JEAN DUPONT',
              textCapitalization: TextCapitalization.characters,
            ),

            const SizedBox(height: 24),

            // Bouton valider
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _processStripeCard(
                  cardNumberController.text,
                  expiryController.text,
                  cvvController.text,
                  nameController.text,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Ajouter la carte'),
              ),
            ),

            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Sécurisé par Stripe', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.grey),
        hintStyle: TextStyle(color: Colors.grey.shade700),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blueAccent)),
      ),
    );
  }

  /// STRIPE: Processus d'ajout de carte
  /// TODO: Intégrer via flutter_stripe package
  /// 1. Envoyer les données à votre backend
  /// 2. Backend crée un PaymentMethod via Stripe API
  /// 3. Attacher le PaymentMethod au Customer
  Future<void> _processStripeCard(String number, String expiry, String cvv, String name) async {
    // Validation basique
    if (number.replaceAll(' ', '').length < 16) {
      _showError('Numéro de carte invalide');
      return;
    }

    Navigator.pop(context);

    // Simuler appel API
    // En production: utiliser flutter_stripe pour créer un PaymentMethod
    // final paymentMethod = await Stripe.instance.createPaymentMethod(
    //   params: PaymentMethodParams.card(
    //     paymentMethodData: PaymentMethodData(billingDetails: ...),
    //   ),
    // );
    // Puis envoyer paymentMethod.id au backend

    setState(() {
      _savedCards.add(SavedCard(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        last4: number.replaceAll(' ', '').substring(12),
        brand: _detectCardBrand(number),
        expiryMonth: int.parse(expiry.split('/')[0]),
        expiryYear: 2000 + int.parse(expiry.split('/')[1]),
        isDefault: _savedCards.isEmpty,
      ));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Carte ajoutée avec succès')),
    );
  }

  String _detectCardBrand(String number) {
    final clean = number.replaceAll(' ', '');
    if (clean.startsWith('4')) return 'Visa';
    if (clean.startsWith('5')) return 'Mastercard';
    if (clean.startsWith('3')) return 'Amex';
    return 'Card';
  }

  // =====================================================
  // MOBILE MONEY INTEGRATION
  // =====================================================
  void _showAddMobileMoneyDialog() {
    MobileMoneyProvider? selectedProvider;
    final phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ajouter Mobile Money', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),

              // Sélection opérateur
              const Text('Opérateur', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: MobileMoneyProvider.values.map((provider) {
                  final isSelected = selectedProvider == provider;
                  return ChoiceChip(
                    label: Text(provider.displayName),
                    selected: isSelected,
                    onSelected: (selected) => setModalState(() => selectedProvider = selected ? provider : null),
                    selectedColor: Colors.green,
                    backgroundColor: Colors.white10,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Numéro de téléphone
              _buildTextField(
                controller: phoneController,
                label: 'Numéro de téléphone',
                hint: '+243 820 000 000',
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedProvider != null ? () => _processMobileMoney(selectedProvider!, phoneController.text) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Ajouter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// MOBILE MONEY: Processus d'ajout
  /// TODO: Intégrer via API opérateur (M-Pesa, Orange Money, etc.)
  /// 1. Envoyer numéro au backend
  /// 2. Backend envoie OTP via API opérateur
  /// 3. Utilisateur vérifie OTP
  Future<void> _processMobileMoney(MobileMoneyProvider provider, String phone) async {
    if (phone.isEmpty) {
      _showError('Numéro requis');
      return;
    }

    Navigator.pop(context);

    // En production: envoyer OTP et vérifier
    // final response = await api.sendMobileMoneyOtp(phone, provider);
    // Afficher dialogue OTP
    // Vérifier OTP puis sauvegarder

    setState(() {
      _mobileMoneyAccounts.add(MobileMoneyAccount(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        provider: provider,
        phoneNumber: phone,
        isDefault: _mobileMoneyAccounts.isEmpty,
      ));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${provider.displayName} ajouté avec succès')),
    );
  }

  // =====================================================
  // BANK ACCOUNT
  // =====================================================
  void _showAddBankAccountDialog() {
    final bankNameController = TextEditingController();
    final ibanController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ajouter un compte bancaire', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 20),

            _buildTextField(controller: bankNameController, label: 'Nom de la banque', hint: 'Ex: Rawbank'),
            const SizedBox(height: 16),
            _buildTextField(controller: ibanController, label: 'IBAN / Numéro de compte', hint: 'XX00 0000 0000 0000'),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (bankNameController.text.isEmpty || ibanController.text.isEmpty) {
                    _showError('Tous les champs sont requis');
                    return;
                  }
                  Navigator.pop(context);
                  setState(() {
                    _bankAccounts.add(BankAccount(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      bankName: bankNameController.text,
                      last4: ibanController.text.substring(ibanController.text.length - 4),
                    ));
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte ajouté')));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Ajouter'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _setDefaultCard(SavedCard card) {
    setState(() {
      for (var c in _savedCards) {
        c.isDefault = c.id == card.id;
      }
    });
  }

  void _deleteCard(SavedCard card) {
    setState(() => _savedCards.remove(card));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carte supprimée')));
  }

  void _setDefaultMobileMoney(MobileMoneyAccount account) {
    setState(() {
      for (var a in _mobileMoneyAccounts) {
        a.isDefault = a.id == account.id;
      }
    });
  }

  void _deleteMobileMoney(MobileMoneyAccount account) {
    setState(() => _mobileMoneyAccounts.remove(account));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte supprimé')));
  }

  void _deleteBankAccount(BankAccount account) {
    setState(() => _bankAccounts.remove(account));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte supprimé')));
  }
}

// =====================================================
// MODELS
// =====================================================

class SavedCard {
  final String id;
  final String last4;
  final String brand;
  final int expiryMonth;
  final int expiryYear;
  bool isDefault;

  SavedCard({
    required this.id,
    required this.last4,
    required this.brand,
    required this.expiryMonth,
    required this.expiryYear,
    this.isDefault = false,
  });
}

enum MobileMoneyProvider {
  mpesa('M-Pesa'),
  orangeMoney('Orange Money'),
  airtelMoney('Airtel Money'),
  mtn('MTN Mobile Money');

  final String displayName;
  const MobileMoneyProvider(this.displayName);
}

class MobileMoneyAccount {
  final String id;
  final MobileMoneyProvider provider;
  final String phoneNumber;
  bool isDefault;

  MobileMoneyAccount({
    required this.id,
    required this.provider,
    required this.phoneNumber,
    this.isDefault = false,
  });
}

class BankAccount {
  final String id;
  final String bankName;
  final String last4;

  BankAccount({required this.id, required this.bankName, required this.last4});
}

// =====================================================
// INPUT FORMATTERS
// =====================================================

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('/', '');
    if (text.length >= 2) {
      return TextEditingValue(
        text: '${text.substring(0, 2)}/${text.substring(2)}',
        selection: TextSelection.collapsed(offset: text.length + 1),
      );
    }
    return newValue;
  }
}
