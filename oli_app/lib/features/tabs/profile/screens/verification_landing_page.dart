import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../widgets/verification_badge.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../providers/verification_controller.dart';

class VerificationLandingPage extends ConsumerStatefulWidget {
  const VerificationLandingPage({super.key});

  @override
  ConsumerState<VerificationLandingPage> createState() => _VerificationLandingPageState();
}

class _VerificationLandingPageState extends ConsumerState<VerificationLandingPage> {
  Map<String, dynamic>? _currentRequest;
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
  }

  Future<void> _checkExistingRequest() async {
    final status = await ref.read(verificationControllerProvider.notifier).checkRequestStatus();
    if (mounted) {
      setState(() {
        _currentRequest = status;
        _loadingStatus = false;
      });
    }
  }

  void _showCertificationFlow(String plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CertificationFlowSheet(
        plan: plan,
        onComplete: () {
          _checkExistingRequest();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Certification Oli"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildHeader(),

            // Afficher le statut de la demande en cours
            if (_loadingStatus)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Colors.blueAccent),
              )
            else if (_currentRequest != null && _currentRequest!['status'] == 'pending')
              _buildPendingBanner()
            else if (_currentRequest != null && _currentRequest!['status'] == 'rejected')
              _buildRejectedBanner(),

            const SizedBox(height: 40),
            _buildPlanCard(
              title: "Oli Certifié",
              price: "4.99\$ / mois",
              features: [
                "Badge bleu sur votre profil",
                "Priorité dans les recherches",
                "Support prioritaire 24/7",
              ],
              badgeType: BadgeType.blue,
              onTap: _currentRequest?.containsKey('status') == true && _currentRequest!['status'] == 'pending'
                  ? null
                  : () => _showCertificationFlow('certified'),
            ),
            const SizedBox(height: 20),
            _buildPlanCard(
              title: "Oli Entreprise",
              price: "39\$ / mois",
              features: [
                "Badge doré exclusif",
                "Certification légale de votre entreprise",
                "Outils d'analyses avancés",
                "Gestion multi-utilisateurs"
              ],
              badgeType: BadgeType.gold,
              isPremium: true,
              onTap: _currentRequest?.containsKey('status') == true && _currentRequest!['status'] == 'pending'
                  ? null
                  : () => _showCertificationFlow('enterprise'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Demande en cours",
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  "Votre demande de certification est en cours d'examen. Vous serez notifié sous 24-48h.",
                  style: TextStyle(color: Colors.amber.withOpacity(0.7), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedBanner() {
    final reason = _currentRequest?['rejection_reason'] ?? 'Document non conforme';
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Demande rejetée",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  "Raison : $reason\nVous pouvez soumettre une nouvelle demande.",
                  style: TextStyle(color: Colors.redAccent.withOpacity(0.7), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: const [
        Text(
          "Renforcez votre crédibilité",
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 12),
        Text(
          "Obtenez un badge de vérification et débloquez des fonctionnalités exclusives pour votre compte ou votre entreprise.",
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required List<String> features,
    required BadgeType badgeType,
    VoidCallback? onTap,
    bool isPremium = false,
  }) {
    final bool isDisabled = onTap == null;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: isPremium ? Border.all(color: Colors.amber, width: 2) : Border.all(color: Colors.white10),
        boxShadow: isPremium ? [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 20)] : [],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(price, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
              VerificationBadge(type: badgeType, size: 40),
            ],
          ),
          const Divider(color: Colors.white24, height: 32),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.check, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text(f, style: const TextStyle(color: Colors.white, fontSize: 14))),
              ],
            ),
          )),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDisabled
                  ? Colors.grey[700]
                  : (isPremium ? Colors.amber : Colors.blueAccent),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isDisabled ? "Demande en cours..." : (isPremium ? "Devenir Entreprise" : "Obtenir la Certification"),
              style: TextStyle(
                color: isDisabled ? Colors.white60 : (isPremium ? Colors.black : Colors.white),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet pour le flow de certification
class _CertificationFlowSheet extends ConsumerStatefulWidget {
  final String plan;
  final VoidCallback onComplete;

  const _CertificationFlowSheet({required this.plan, required this.onComplete});

  @override
  ConsumerState<_CertificationFlowSheet> createState() => _CertificationFlowSheetState();
}

class _CertificationFlowSheetState extends ConsumerState<_CertificationFlowSheet> {
  int _step = 0; // 0 = doc type, 1 = photo, 2 = payment, 3 = submit
  String _docType = 'carte_identite';
  String _paymentMethod = 'mobile_money';
  Uint8List? _idCardBytes;
  String _idCardFileName = '';
  bool _submitting = false;

  // Payment controllers
  final _phoneController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardholderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill phone from user profile
    final authState = ref.read(authControllerProvider);
    final phone = authState.userData?['phone'] ?? '';
    _phoneController.text = phone;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardholderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1200);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _idCardBytes = bytes;
        _idCardFileName = 'id_card_${DateTime.now().millisecondsSinceEpoch}.jpg';
        _step = 2; // Aller au paiement
      });
    }
  }

  Future<void> _submit() async {
    if (_idCardBytes == null) return;

    // Validation selon la méthode
    if (_paymentMethod == 'mobile_money' && _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez entrer votre numéro de téléphone"), backgroundColor: Colors.red),
      );
      return;
    }

    if (_paymentMethod == 'card') {
      if (_cardNumberController.text.trim().isEmpty || _expiryController.text.trim().isEmpty || _cvvController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez remplir tous les champs de la carte"), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _submitting = true);

    // Construire les détails de paiement + méthode réelle
    Map<String, String>? paymentDetails;
    String actualPaymentMethod = _paymentMethod;

    if (_paymentMethod == 'mobile_money') {
      final phone = _phoneController.text.trim();
      final detectedNetwork = _detectNetwork(phone);
      actualPaymentMethod = detectedNetwork; // 'orange_money' ou 'mtn'
      paymentDetails = {'phone_number': phone};
    } else if (_paymentMethod == 'card') {
      paymentDetails = {
        'card_number': _cardNumberController.text.trim(),
        'expiry_date': _expiryController.text.trim(),
        'cvv': _cvvController.text.trim(),
        'cardholder_name': _cardholderController.text.trim(),
      };
    }

    final result = await ref.read(verificationControllerProvider.notifier)
        .submitCertificationRequest(
      plan: widget.plan,
      paymentMethod: actualPaymentMethod,
      documentType: _docType,
      idCardBytes: _idCardBytes!,
      idCardFileName: _idCardFileName,
      paymentDetails: paymentDetails,
    );

    if (mounted) {
      setState(() => _submitting = false);
      Navigator.pop(context);
      widget.onComplete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Demande envoyée'),
          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                widget.plan == 'enterprise' ? "Devenir Entreprise" : "Obtenir la Certification",
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "Étape ${_step + 1} sur 3",
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Steps
              if (_step == 0) _buildDocTypeStep(),
              if (_step == 1) _buildPhotoStep(),
              if (_step == 2) _buildPaymentStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Type de document", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _docOption("🪪  Carte d'identité nationale", 'carte_identite'),
        const SizedBox(height: 10),
        _docOption("🛂  Passeport", 'passeport'),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => setState(() => _step = 1),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Suivant →", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _docOption(String label, String value) {
    final selected = _docType == value;
    return GestureDetector(
      onTap: () => setState(() => _docType = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? Colors.blueAccent.withOpacity(0.15) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.blueAccent : Colors.white10, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 15))),
            if (selected) const Icon(Icons.check_circle, color: Colors.blueAccent, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _docType == 'passeport' ? "Prenez une photo de votre passeport" : "Prenez une photo de votre carte d'identité",
          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          "Assurez-vous que le document est lisible et que toutes les informations sont visibles.",
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 20),

        if (_idCardBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_idCardBytes!, height: 180, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
        ],

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text("Caméra"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2A2A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library, size: 20),
                label: const Text("Galerie"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2A2A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _step = 0),
          child: const Text("← Retour", style: TextStyle(color: Colors.white38)),
        ),
      ],
    );
  }

  Widget _buildPaymentStep() {
    final price = widget.plan == 'enterprise' ? "39\$" : "4.99\$";
    final priceNum = widget.plan == 'enterprise' ? 39.0 : 4.99;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Méthode de paiement", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _paymentOption("📱  Mobile Money", 'mobile_money'),
        const SizedBox(height: 10),
        _paymentOption("💰  Oli Wallet", 'wallet'),
        const SizedBox(height: 10),
        _paymentOption("💳  Carte bancaire", 'card'),
        const SizedBox(height: 16),

        // ═══ FORMULAIRE DYNAMIQUE SELON LA MÉTHODE ═══
        if (_paymentMethod == 'mobile_money')
          _buildMobileMoneyForm(),

        if (_paymentMethod == 'wallet')
          _buildWalletForm(priceNum),

        if (_paymentMethod == 'card')
          _buildCardForm(),

        const SizedBox(height: 16),

        // Résumé
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Montant", style: TextStyle(color: Colors.white70)),
                  Text("$price / mois", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const Divider(color: Colors.white10, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Document", style: TextStyle(color: Colors.white38, fontSize: 12)),
                  Text(
                    _docType == 'passeport' ? 'Passeport' : "Carte d'identité",
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Paiement", style: TextStyle(color: Colors.white38, fontSize: 12)),
                  Text(
                    _paymentMethodLabel(),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.plan == 'enterprise' ? Colors.amber : Colors.blueAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _submitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
                  "Payer $price et envoyer",
                  style: TextStyle(
                    color: widget.plan == 'enterprise' ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _step = 1),
          child: const Text("← Retour", style: TextStyle(color: Colors.white38)),
        ),
      ],
    );
  }

  // ═══ AUTO-DÉTECTION RÉSEAU ═══
  String _detectNetwork(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\+]'), '');
    // Format DRC: 243XXXXXXXXX
    String local = cleaned;
    if (cleaned.startsWith('243') && cleaned.length >= 12) {
      local = cleaned.substring(3);
    } else if (cleaned.startsWith('0') && cleaned.length >= 10) {
      local = cleaned.substring(1);
    }

    // Orange RDC: 84, 85, 89
    if (local.startsWith('84') || local.startsWith('85') || local.startsWith('89')) {
      return 'orange_money';
    }
    // Airtel RDC: 97, 99, 98
    if (local.startsWith('97') || local.startsWith('99') || local.startsWith('98')) {
      return 'orange_money'; // Airtel via Orange Money
    }
    // MTN/Vodacom RDC: 81, 82, 83, 80
    return 'mtn';
  }

  // ═══ MOBILE MONEY FORM ═══
  Widget _buildMobileMoneyForm() {
    final phone = _phoneController.text.trim();
    final detectedNetwork = _detectNetwork(phone);
    final isOrange = detectedNetwork == 'orange_money';
    final networkName = isOrange ? 'Orange Money' : 'MTN Mobile Money';
    final networkColor = isOrange ? Colors.orange : Colors.yellow;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: networkColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android, color: networkColor, size: 18),
              const SizedBox(width: 8),
              const Text(
                "Mobile Money",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}), // Refresh pour auto-détection
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: "+243 ...",
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.phone, color: Colors.white54, size: 20),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          // Badge réseau détecté
          if (phone.length >= 6)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: networkColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi, color: networkColor, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    "Réseau détecté : $networkName",
                    style: TextStyle(color: networkColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            "Un push USSD sera envoyé sur ce numéro pour confirmer le paiement.",
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ═══ WALLET FORM ═══
  Widget _buildWalletForm(double priceNum) {
    final walletState = ref.watch(walletProvider);
    final balance = walletState.balance;
    final hasSufficientFunds = balance >= priceNum;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasSufficientFunds ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: hasSufficientFunds ? Colors.green : Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text("Oli Wallet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text(
                "${balance.toStringAsFixed(2)} \$",
                style: TextStyle(
                  color: hasSufficientFunds ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasSufficientFunds)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Solde insuffisant. Il vous manque ${(priceNum - balance).toStringAsFixed(2)}\$. Rechargez votre wallet.",
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 8),
                const Text("Solde suffisant — paiement instantané", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }

  // ═══ CARD FORM ═══
  Widget _buildCardForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.credit_card, color: Colors.blueAccent, size: 18),
              SizedBox(width: 8),
              Text("Carte bancaire", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14)),
              Spacer(),
              Text("Stripe", style: TextStyle(color: Colors.white30, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 14),
          _cardField(_cardNumberController, "Numéro de carte", "4242 4242 4242 4242", TextInputType.number, Icons.credit_card),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _cardField(_expiryController, "MM/YY", "12/28", TextInputType.datetime, Icons.calendar_today)),
              const SizedBox(width: 10),
              Expanded(child: _cardField(_cvvController, "CVV", "123", TextInputType.number, Icons.lock)),
            ],
          ),
          const SizedBox(height: 10),
          _cardField(_cardholderController, "Titulaire de la carte", "John Doe", TextInputType.name, Icons.person),
          const SizedBox(height: 8),
          Text(
            "🔒 Paiement sécurisé — Mode sandbox (simulation)",
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _cardField(TextEditingController controller, String label, String hint, TextInputType type, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  String _paymentMethodLabel() {
    switch (_paymentMethod) {
      case 'mobile_money':
        final network = _detectNetwork(_phoneController.text.trim());
        return network == 'orange_money' ? 'Mobile Money (Orange)' : 'Mobile Money (MTN)';
      case 'wallet': return 'Oli Wallet';
      case 'card': return 'Carte bancaire';
      default: return _paymentMethod;
    }
  }

  Widget _paymentOption(String label, String value) {
    final selected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? Colors.blueAccent.withOpacity(0.15) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.blueAccent : Colors.white10, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 15))),
            if (selected) const Icon(Icons.check_circle, color: Colors.blueAccent, size: 22),
          ],
        ),
      ),
    );
  }
}
