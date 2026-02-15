import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../widgets/verification_badge.dart';
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
  String _paymentMethod = 'orange_money';
  File? _idCardImage;
  bool _submitting = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1200);
    if (picked != null) {
      setState(() {
        _idCardImage = File(picked.path);
        _step = 2; // Aller au paiement
      });
    }
  }

  Future<void> _submit() async {
    if (_idCardImage == null) return;

    setState(() => _submitting = true);

    final result = await ref.read(verificationControllerProvider.notifier)
        .submitCertificationRequest(
      plan: widget.plan,
      paymentMethod: _paymentMethod,
      documentType: _docType,
      idCardImage: _idCardImage!,
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

        if (_idCardImage != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_idCardImage!, height: 180, fit: BoxFit.cover),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Méthode de paiement", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _paymentOption("🟠  Orange Money", 'orange_money'),
        const SizedBox(height: 10),
        _paymentOption("🟡  MTN Mobile Money", 'mtn'),
        const SizedBox(height: 10),
        _paymentOption("💳  Carte bancaire", 'card'),
        const SizedBox(height: 20),

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
