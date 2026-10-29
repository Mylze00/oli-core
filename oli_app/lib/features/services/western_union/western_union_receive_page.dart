import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/providers/auth_controller.dart';
import 'western_union_success_dialog.dart';

class WesternUnionReceivePage extends ConsumerStatefulWidget {
  const WesternUnionReceivePage({super.key});

  @override
  ConsumerState<WesternUnionReceivePage> createState() => _WesternUnionReceivePageState();
}

class _WesternUnionReceivePageState extends ConsumerState<WesternUnionReceivePage> {
  // Country selection
  String _selectedCountry = "France";
  String _selectedCountryFlag = "🇫🇷";
  String _selectedCountryCurrency = "EUR (€)";

  // Controllers
  final TextEditingController _amountToReceiveController = TextEditingController(text: "50");
  final TextEditingController _senderFullNameController = TextEditingController(text: "Sophia Pesi Lopes Lilembo");
  final TextEditingController _mtcnController = TextEditingController(text: "2154-1244-1255");
  final TextEditingController _mobileMoneyController = TextEditingController(text: "+243827088682");
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController(
    text: "104, Avenue Banga nzambe, Quartier Kinkole, Commune de la N'sele, Kinshasa",
  );

  // Receive Method
  String _receiveMethod = "mobile_money"; // mobile_money, wallet, bank

  // Mobile operator
  String _detectedOperator = "M-PESA";

  // ID Document image
  File? _idDocumentFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _detectOperator(_mobileMoneyController.text);

    // Auto-fill from auth profile if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authControllerProvider);
      final userData = authState.userData;
      if (userData != null) {
        if (_fullNameController.text.isEmpty) {
          final name = userData['full_name'] ?? userData['name'] ?? "Paolice Lilembo Lowala";
          _fullNameController.text = name.toString();
        }
        if (userData['phone'] != null && _mobileMoneyController.text.isEmpty) {
          _mobileMoneyController.text = userData['phone'].toString();
          _detectOperator(userData['phone'].toString());
        }
      } else {
        if (_fullNameController.text.isEmpty) {
          _fullNameController.text = "Paolice Lilembo Lowala";
        }
      }
    });
  }

  void _detectOperator(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    String operatorName = "M-PESA";

    if (cleanPhone.length >= 5) {
      final local = cleanPhone.startsWith('243') ? cleanPhone.substring(3) : cleanPhone;
      if (local.length >= 2) {
        final prefix = local.substring(0, 2);
        if (['81', '82', '83'].contains(prefix)) {
          operatorName = "M-PESA";
        } else if (['97', '98', '99'].contains(prefix)) {
          operatorName = "Airtel Money";
        } else if (['84', '85', '89'].contains(prefix)) {
          operatorName = "Orange Money";
        } else if (['90', '80', '88', '86'].contains(prefix)) {
          operatorName = "Afrimoney";
        }
      }
    }

    setState(() {
      _detectedOperator = operatorName;
    });
  }

  Future<void> _pickIdDocument() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _idDocumentFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Erreur sélection document: $e");
    }
  }

  void _showCountryPicker() {
    final countries = [
      {"name": "France", "flag": "🇫🇷", "currency": "EUR (€)"},
      {"name": "Belgique", "flag": "🇧🇪", "currency": "EUR (€)"},
      {"name": "États-Unis", "flag": "🇺🇸", "currency": "USD (\$)"},
      {"name": "Canada", "flag": "🇨🇦", "currency": "CAD (\$)"},
      {"name": "Royaume-Uni", "flag": "🇬🇧", "currency": "GBP (£)"},
      {"name": "Rép. Dém. du Congo", "flag": "🇨🇩", "currency": "CDF (FC)"},
      {"name": "Côte d'Ivoire", "flag": "🇨🇮", "currency": "XOF (CFA)"},
      {"name": "Sénégal", "flag": "🇸🇳", "currency": "XOF (CFA)"},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Sélectionner le pays de votre expéditeur",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: countries.length,
                  itemBuilder: (context, index) {
                    final c = countries[index];
                    return ListTile(
                      leading: Text(c["flag"] as String, style: const TextStyle(fontSize: 24)),
                      title: Text(c["name"] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: _selectedCountry == c["name"]
                          ? const Icon(Icons.check_circle, color: Color(0xFF163750))
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCountry = c["name"] as String;
                          _selectedCountryFlag = c["flag"] as String;
                          _selectedCountryCurrency = c["currency"] as String;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit() {
    if (_amountToReceiveController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez saisir le montant à recevoir")),
      );
      return;
    }

    if (_mtcnController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez saisir le code MTCN")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WesternUnionSuccessDialog(
        operationType: "RETRAIT",
        amount: "${_amountToReceiveController.text.replaceAll('\$', '')}\$",
        targetCountry: "$_selectedCountryFlag $_selectedCountry",
        senderName: _senderFullNameController.text,
        receiverName: _fullNameController.text,
        mtcnCode: _mtcnController.text,
        paymentMethod: _receiveMethod == "mobile_money"
            ? "Mobile Money ($_detectedOperator)"
            : (_receiveMethod == "wallet" ? "Portefeuille Oli" : "Compte Bancaire"),
        accountNumber: _mobileMoneyController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const navyBg = Color(0xFF163750);
    const wuYellow = Color(0xFFFFDE00);

    return Scaffold(
      backgroundColor: navyBg,
      body: Stack(
        children: [
          // ── Top Yellow Curved Header ─────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: CustomPaint(
              painter: _HeaderCurvePainter(color: wuYellow),
            ),
          ),

          // ── Bottom Yellow Accent ─────────────────────────────
          Positioned(
            bottom: 0,
            right: 0,
            width: 140,
            height: 40,
            child: CustomPaint(
              painter: _BottomAccentPainter(color: wuYellow),
            ),
          ),

          // ── Content ──────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top Header Row (Back Button + Pill "RETRAIT")
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB9CAD6),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              "RETRAIT",
                              style: TextStyle(
                                color: Color(0xFF0D2338),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 36),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Main Title "Bienvenue chez Western Union"
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    "Bienvenue chez Western Union",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF0D2338),
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Scrollable Form Cards
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      children: [
                        // ── Card 1: Commençons ! ─────────────────
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Commençons !",
                                style: TextStyle(
                                  color: Color(0xFF758A99),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Country Selector (expéditeur)
                              GestureDetector(
                                onTap: _showCountryPicker,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFF4A6B82), width: 1.2),
                                    borderRadius: BorderRadius.circular(25),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(_selectedCountryFlag, style: const TextStyle(fontSize: 22)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Sélectionner le pays de votre expéditeur",
                                              style: TextStyle(fontSize: 10, color: Color(0xFF163750), fontWeight: FontWeight.w600),
                                            ),
                                            Text(
                                              _selectedCountry,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0D2338),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, color: Color(0xFF163750), size: 26),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Montant à recevoir
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFF4A6B82), width: 1.2),
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Veuillez saisir le montant à recevoir ($_selectedCountryCurrency)",
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF758A99)),
                                    ),
                                    TextField(
                                      controller: _amountToReceiveController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D2338),
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        border: InputBorder.none,
                                        suffixText: "\$",
                                        suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D2338)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Nom complet de l'Expéditeur
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFF4A6B82), width: 1.2),
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Veuillez saisir le nom complet de l'Expéditeur",
                                      style: TextStyle(fontSize: 10, color: Color(0xFF758A99)),
                                    ),
                                    TextField(
                                      controller: _senderFullNameController,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D2338),
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 2),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Code MTCN (Champ spécifique pour le retrait)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFF4A6B82), width: 1.2),
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Veuillez saisir votre code MTCN",
                                      style: TextStyle(fontSize: 10, color: Color(0xFF758A99)),
                                    ),
                                    TextField(
                                      controller: _mtcnController,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        color: Color(0xFF0D2338),
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 2),
                                        border: InputBorder.none,
                                        hintText: "XXXX-XXXX-XXXX",
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Card 2: Comment souhaitez vous recevoir l'argent ? ──
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Comment souhaitez vous recevoir l'argent?",
                                style: TextStyle(
                                  color: Color(0xFF0D2338),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // 3 Options Row
                              Row(
                                children: [
                                  // Mobile Money
                                  Expanded(
                                    child: _buildMethodTile(
                                      title: "Mobile Money",
                                      id: "mobile_money",
                                      isSelected: _receiveMethod == "mobile_money",
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Portefeuille Oli
                                  Expanded(
                                    child: _buildMethodTile(
                                      title: "Portefeuille Oli",
                                      id: "wallet",
                                      isSelected: _receiveMethod == "wallet",
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Compte Bancaire
                                  Expanded(
                                    child: _buildMethodTile(
                                      title: "Compte Bancaire",
                                      id: "bank",
                                      isSelected: _receiveMethod == "bank",
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Mobile Money input & label
                              if (_receiveMethod == "mobile_money") ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFF4A6B82), width: 1.2),
                                    borderRadius: BorderRadius.circular(20),
                                    color: Colors.white,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Veuillez saisir le numéro de votre compte mobile money",
                                        style: TextStyle(fontSize: 10, color: Color(0xFF758A99)),
                                      ),
                                      TextField(
                                        controller: _mobileMoneyController,
                                        keyboardType: TextInputType.phone,
                                        onChanged: _detectOperator,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0D2338),
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(vertical: 2),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Votre numéro renseigné est ($_detectedOperator), le fonds vous seras automatiquement déposé sur le numéro renseigné dès l'approbation de l'opération",
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: Color(0xFF758A99),
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Card 3: Authentification Identité ──
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Nous avons besoin de votre identité pour authentification",
                                style: TextStyle(
                                  color: Color(0xFF0D2338),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Nom complet
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFF4A6B82), width: 1.2),
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Nom complet",
                                      style: TextStyle(fontSize: 10, color: Color(0xFF758A99)),
                                    ),
                                    TextField(
                                      controller: _fullNameController,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D2338),
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 2),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Adresse complète
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFF4A6B82), width: 1.2),
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Adresse complète",
                                      style: TextStyle(fontSize: 10, color: Color(0xFF758A99)),
                                    ),
                                    TextField(
                                      controller: _addressController,
                                      maxLines: 2,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D2338),
                                        height: 1.2,
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 2),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // ID Upload Box
                              GestureDetector(
                                onTap: _pickIdDocument,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFF4A6B82), width: 1.2),
                                    borderRadius: BorderRadius.circular(20),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          "Veuillez cliquez ici pour télécharger votre pièce d'identité",
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0D2338),
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward, color: Color(0xFF0D2338), size: 20),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 80,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD6DFE6),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFB0C0CC)),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: _idDocumentFile != null
                                            ? Image.file(
                                                _idDocumentFile!,
                                                fit: BoxFit.cover,
                                              )
                                            : const Icon(
                                                Icons.badge_outlined,
                                                color: Color(0xFF758A99),
                                                size: 28,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Bottom Confirm Button (Dark Blue for Retrait) ──
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF163750),
                              foregroundColor: Colors.white,
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Confirmer",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMethodTile({
    required String title,
    required String id,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _receiveMethod = id;
        });
      },
      child: Container(
        height: 75,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D2338) : const Color(0xFFCCD5DC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Radio circle indicator
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : const Color(0xFF758A99),
                  width: 1.5,
                ),
                color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
              ),
            ),
            Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF0D2338),
                ),
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

// ── Custom Painters ──────────────────────────────────────────────────────────

class _HeaderCurvePainter extends CustomPainter {
  final Color color;
  _HeaderCurvePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height,
      size.width,
      size.height * 0.75,
    );
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomAccentPainter extends CustomPainter {
  final Color color;
  _BottomAccentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width * 0.25, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
