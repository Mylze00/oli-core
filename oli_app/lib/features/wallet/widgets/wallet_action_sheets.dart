import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/wallet_provider.dart';
import '../../../features/auth/providers/auth_controller.dart';
import '../../../features/wallet/services/biometric_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper global
// ─────────────────────────────────────────────────────────────────────────────
void showWalletSheet(BuildContext context, Widget sheet) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => sheet,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ① RECHARGER — Mobile Money ou Carte Visa
// ─────────────────────────────────────────────────────────────────────────────
class RechargerSheet extends ConsumerStatefulWidget {
  const RechargerSheet({super.key});

  @override
  ConsumerState<RechargerSheet> createState() => _RechargerSheetState();
}

class _RechargerSheetState extends ConsumerState<RechargerSheet> {
  String? _method; // 'mobile' | 'card'

  @override
  Widget build(BuildContext context) {
    return _method == null
        ? _MethodPickerShell(
            title: 'Recharger le wallet',
            icon: Icons.add_circle_outline,
            iconColor: const Color(0xFF22C55E),
            onMobile: () => setState(() => _method = 'mobile'),
            onCard: () => setState(() => _method = 'card'),
          )
        : _method == 'mobile'
            ? _MobileMoneyForm(
                title: 'Recharger — Mobile Money',
                buttonLabel: 'Recharger',
                buttonColor: const Color(0xFF22C55E),
                onSubmit: (amount, provider, phone) async {
                  final ok = await ref
                      .read(walletProvider.notifier)
                      .deposit(amount: amount, provider: provider, phone: phone);
                  return ok;
                },
              )
            : _CardForm(
                title: 'Recharger — Carte Visa',
                onSubmit: (amount, card, expiry, cvv, name) async {
                  final ok = await ref
                      .read(walletProvider.notifier)
                      .depositByCard(
                        amount: amount,
                        cardNumber: card,
                        expiryDate: expiry,
                        cvv: cvv,
                        cardholderName: name,
                      );
                  return ok;
                },
              );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ② RETIRER — Mobile Money ou Carte Visa
// ─────────────────────────────────────────────────────────────────────────────
class RetirerSheet extends ConsumerStatefulWidget {
  const RetirerSheet({super.key});

  @override
  ConsumerState<RetirerSheet> createState() => _RetirerSheetState();
}

class _RetirerSheetState extends ConsumerState<RetirerSheet> {
  String? _method;

  @override
  Widget build(BuildContext context) {
    return _method == null
        ? _MethodPickerShell(
            title: 'Retirer des fonds',
            icon: Icons.arrow_upward_rounded,
            iconColor: const Color(0xFFF59E0B),
            onMobile: () => setState(() => _method = 'mobile'),
            onCard: () => setState(() => _method = 'card'),
          )
        : _method == 'mobile'
            ? _MobileMoneyForm(
                title: 'Retrait — Mobile Money',
                buttonLabel: 'Retirer',
                buttonColor: const Color(0xFFF59E0B),
                onSubmit: (amount, provider, phone) async {
                  final ok = await ref
                      .read(walletProvider.notifier)
                      .withdraw(amount: amount, provider: provider, phone: phone);
                  return ok;
                },
              )
            : _CardForm(
                title: 'Retrait — Carte Visa',
                onSubmit: (amount, card, expiry, cvv, name) async {
                  // Retrait par carte : endpoint même que deposit-card côté backend
                  // à adapter si endpoint distinct
                  final ok = await ref
                      .read(walletProvider.notifier)
                      .depositByCard(
                        amount: -amount.abs(),
                        cardNumber: card,
                        expiryDate: expiry,
                        cvv: cvv,
                        cardholderName: name,
                      );
                  return ok;
                },
              );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ③ ENVOYER — Contact ou QR Code
// ─────────────────────────────────────────────────────────────────────────────
class EnvoyerSheet extends ConsumerStatefulWidget {
  const EnvoyerSheet({super.key});

  @override
  ConsumerState<EnvoyerSheet> createState() => _EnvoyerSheetState();
}

class _EnvoyerSheetState extends ConsumerState<EnvoyerSheet> {
  String? _mode; // 'contact' | 'qr'

  @override
  Widget build(BuildContext context) {
    if (_mode == null) {
      return _DarkSheet(
        title: 'Envoyer de l\'argent',
        icon: Icons.send_rounded,
        iconColor: const Color(0xFF1E7DBA),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            _BigOptionTile(
              icon: Icons.contacts_outlined,
              title: 'Sélectionner un contact',
              subtitle: 'Envoyer par numéro de téléphone',
              color: const Color(0xFF1E7DBA),
              onTap: () => setState(() => _mode = 'contact'),
            ),
            const SizedBox(height: 12),
            _BigOptionTile(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scanner un QR Code',
              subtitle: 'Scanner le QR du destinataire',
              color: const Color(0xFF7C3AED),
              onTap: () => setState(() => _mode = 'qr'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    if (_mode == 'contact') {
      return _TransferContactForm(ref: ref);
    }

    return _TransferQrScanner(ref: ref);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ④ RECEVOIR — QR Code unique
// ─────────────────────────────────────────────────────────────────────────────
class RecevoirSheet extends ConsumerWidget {
  const RecevoirSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final phone = authState.userData?['phone'] ?? '';
    final name = authState.userData?['name'] ?? 'Utilisateur';
    // QR data : format JSON que l'app peut parser
    final qrData = 'oli://transfer?phone=$phone&name=${Uri.encodeComponent(name)}';

    return _DarkSheet(
      title: 'Recevoir de l\'argent',
      icon: Icons.arrow_downward_rounded,
      iconColor: const Color(0xFF22C55E),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // QR Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              children: [
                QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Copier l'identifiant
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: phone));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Numéro copié !'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFF22C55E),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Copier mon numéro : $phone',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Montrez ce QR ou partagez votre numéro pour recevoir un paiement.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ⑤ HISTORIQUE — Liste des transactions
// ─────────────────────────────────────────────────────────────────────────────
class HistoriqueSheet extends ConsumerWidget {
  const HistoriqueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);

    return _DarkSheet(
      title: 'Historique des transactions',
      icon: Icons.bar_chart_rounded,
      iconColor: const Color(0xFF7C3AED),
      child: walletState.isLoading
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF1E7DBA))),
            )
          : walletState.transactions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 52, color: Colors.white.withOpacity(0.25)),
                      const SizedBox(height: 12),
                      Text(
                        'Aucune transaction',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.45), fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: walletState.transactions.take(30).length,
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.white.withOpacity(0.07),
                    height: 1,
                  ),
                  itemBuilder: (_, i) {
                    final tx = walletState.transactions[i];
                    final isCredit = tx.type == 'deposit' || tx.type == 'transfer_in';
                    final color = isCredit ? const Color(0xFF22C55E) : const Color(0xFFF87171);
                    final icon = isCredit
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded;
                    final sign = isCredit ? '+' : '-';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.description.isNotEmpty
                                      ? tx.description
                                      : _txLabel(tx.type),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDate(tx.createdAt),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$sign ${tx.amount.toStringAsFixed(0)} FC',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _statusColor(tx.status).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _statusLabel(tx.status),
                                  style: TextStyle(
                                    color: _statusColor(tx.status),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  String _txLabel(String type) {
    switch (type) {
      case 'deposit':
        return 'Rechargement';
      case 'withdrawal':
        return 'Retrait';
      case 'transfer_out':
        return 'Transfert envoyé';
      case 'transfer_in':
        return 'Transfert reçu';
      default:
        return 'Transaction';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF22C55E);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'failed':
        return const Color(0xFFF87171);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'RÉUSSI';
      case 'pending':
        return 'EN COURS';
      case 'failed':
        return 'ÉCHOUÉ';
      default:
        return status.toUpperCase();
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return 'Aujourd\'hui ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Hier';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formulaire — Envoi par contact (numéro de téléphone)
// ─────────────────────────────────────────────────────────────────────────────
class _TransferContactForm extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _TransferContactForm({required this.ref});

  @override
  ConsumerState<_TransferContactForm> createState() =>
      _TransferContactFormState();
}

class _TransferContactFormState extends ConsumerState<_TransferContactForm> {
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = _phoneCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));

    if (phone.isEmpty) {
      setState(() => _error = 'Numéro requis');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Montant invalide');
      return;
    }

    final confirmed = await biometricService.authenticate(
      reason: 'Confirmer l\'envoi de ${amount.toStringAsFixed(0)} FC',
    );
    if (!confirmed) {
      setState(() => _error = 'Authentification annulée');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final ok = await ref.read(walletProvider.notifier).transfer(
          amount: amount,
          recipientPhone: phone,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );

    setState(() => _isLoading = false);

    if (mounted) {
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfert effectué avec succès !'),
            backgroundColor: Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(
            () => _error = ref.read(walletProvider).error ?? 'Erreur de transfert');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DarkSheet(
      title: 'Envoyer par contact',
      icon: Icons.contacts_outlined,
      iconColor: const Color(0xFF1E7DBA),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _GlassField(
            controller: _phoneCtrl,
            hint: 'Numéro de téléphone (+243...)',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          _GlassField(
            controller: _amountCtrl,
            hint: 'Montant (FC)',
            icon: Icons.attach_money_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          _GlassField(
            controller: _noteCtrl,
            hint: 'Motif (optionnel)',
            icon: Icons.notes_rounded,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFF87171), fontSize: 12),
              ),
            ),
          const SizedBox(height: 20),
          _ActionButton(
            label: _isLoading ? 'Envoi...' : 'Envoyer',
            color: const Color(0xFF1E7DBA),
            isLoading: _isLoading,
            onTap: _send,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scanner QR pour l'envoi
// ─────────────────────────────────────────────────────────────────────────────
class _TransferQrScanner extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _TransferQrScanner({required this.ref});

  @override
  ConsumerState<_TransferQrScanner> createState() => _TransferQrScannerState();
}

class _TransferQrScannerState extends ConsumerState<_TransferQrScanner> {
  String? _scannedPhone;
  String? _scannedName;
  final _amountCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  // Pour un vrai scan, intégrer mobile_scanner ; ici on simule avec un textfield
  void _handleScannedQr(String raw) {
    try {
      final uri = Uri.parse(raw);
      final phone = uri.queryParameters['phone'] ?? '';
      final name = Uri.decodeComponent(uri.queryParameters['name'] ?? 'Destinataire');
      setState(() {
        _scannedPhone = phone;
        _scannedName = name;
      });
    } catch (_) {
      setState(() => _error = 'QR invalide');
    }
  }

  Future<void> _send() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Montant invalide');
      return;
    }
    final confirmed = await biometricService.authenticate(
      reason: 'Confirmer l\'envoi de ${amount.toStringAsFixed(0)} FC',
    );
    if (!confirmed) {
      setState(() => _error = 'Authentification annulée');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    final ok = await ref.read(walletProvider.notifier).transfer(
          amount: amount,
          recipientPhone: _scannedPhone!,
        );
    setState(() => _isLoading = false);
    if (mounted) {
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfert réussi !'),
            backgroundColor: Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _error = ref.read(walletProvider).error ?? 'Erreur');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DarkSheet(
      title: 'Scanner QR Code',
      icon: Icons.qr_code_scanner_rounded,
      iconColor: const Color(0xFF7C3AED),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          if (_scannedPhone == null) ...[
            // Placeholder : en prod, remplacer par MobileScanner()
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.4)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner_rounded,
                      size: 52, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'Placez le QR code du destinataire\ndans la zone de scan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Champ manuel (fallback / dev)  
            _GlassField(
              hint: 'Ou saisir le lien QR manuellement (dev)',
              icon: Icons.link,
              onSubmitted: _handleScannedQr,
            ),
          ] else ...[
            // Destinataire confirmé
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF22C55E).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF22C55E), size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_scannedName ?? 'Destinataire',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text(_scannedPhone!,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _GlassField(
              controller: _amountCtrl,
              hint: 'Montant (FC)',
              icon: Icons.attach_money_rounded,
              keyboardType: TextInputType.number,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: const TextStyle(
                        color: Color(0xFFF87171), fontSize: 12)),
              ),
            const SizedBox(height: 16),
            _ActionButton(
              label: _isLoading ? 'Envoi...' : 'Confirmer l\'envoi',
              color: const Color(0xFF7C3AED),
              isLoading: _isLoading,
              onTap: _send,
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formulaire Mobile Money (réutilisable Recharger / Retirer)
// ─────────────────────────────────────────────────────────────────────────────
class _MobileMoneyForm extends ConsumerStatefulWidget {
  final String title;
  final String buttonLabel;
  final Color buttonColor;
  final Future<bool> Function(double amount, String provider, String phone) onSubmit;

  const _MobileMoneyForm({
    required this.title,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onSubmit,
  });

  @override
  ConsumerState<_MobileMoneyForm> createState() => _MobileMoneyFormState();
}

class _MobileMoneyFormState extends ConsumerState<_MobileMoneyForm> {
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _provider = 'orange';
  bool _isLoading = false;
  String? _error;

  final _providers = [
    {'value': 'orange', 'label': 'Orange Money', 'color': Color(0xFFF97316)},
    {'value': 'mpesa', 'label': 'M-Pesa', 'color': Color(0xFF22C55E)},
    {'value': 'airtel', 'label': 'Airtel Money', 'color': Color(0xFFEF4444)},
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Montant invalide');
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Numéro Mobile Money requis');
      return;
    }

    final confirmed = await biometricService.authenticate(
      reason: 'Confirmer ${widget.buttonLabel} de ${amount.toStringAsFixed(0)} FC',
    );
    if (!confirmed) {
      setState(() => _error = 'Authentification annulée');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    final ok = await widget.onSubmit(amount, _provider, _phoneCtrl.text.trim());
    setState(() => _isLoading = false);

    if (mounted) {
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.buttonLabel} réussi !'),
            backgroundColor: widget.buttonColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _error = ref.read(walletProvider).error ?? 'Erreur');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DarkSheet(
      title: widget.title,
      icon: Icons.phone_android_rounded,
      iconColor: widget.buttonColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Sélection opérateur
          Row(
            children: _providers.map((p) {
              final isSelected = _provider == p['value'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _provider = p['value'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (p['color'] as Color).withOpacity(0.18)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? (p['color'] as Color).withOpacity(0.7)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      p['label'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected
                            ? p['color'] as Color
                            : Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _GlassField(
            controller: _amountCtrl,
            hint: 'Montant (FC)',
            icon: Icons.attach_money_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          _GlassField(
            controller: _phoneCtrl,
            hint: 'Numéro Mobile Money',
            icon: Icons.smartphone_rounded,
            keyboardType: TextInputType.phone,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: const TextStyle(color: Color(0xFFF87171), fontSize: 12)),
            ),
          const SizedBox(height: 20),
          _ActionButton(
            label: _isLoading ? 'Traitement...' : widget.buttonLabel,
            color: widget.buttonColor,
            isLoading: _isLoading,
            onTap: _submit,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formulaire Carte (réutilisable Recharger / Retirer)
// ─────────────────────────────────────────────────────────────────────────────
class _CardForm extends ConsumerStatefulWidget {
  final String title;
  final Future<bool> Function(
      double amount, String card, String expiry, String cvv, String name) onSubmit;

  const _CardForm({required this.title, required this.onSubmit});

  @override
  ConsumerState<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends ConsumerState<_CardForm> {
  final _amountCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _cardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _formatCard(String v) {
    final raw = v.replaceAll(' ', '');
    final buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      buf.write(raw[i]);
      if ((i + 1) % 4 == 0 && i + 1 != raw.length) buf.write(' ');
    }
    final f = buf.toString();
    _cardCtrl.value = TextEditingValue(
        text: f, selection: TextSelection.collapsed(offset: f.length));
  }

  void _formatExpiry(String v) {
    final raw = v.replaceAll('/', '');
    if (raw.length >= 2) {
      final f = '${raw.substring(0, 2)}/${raw.substring(2)}';
      _expiryCtrl.value = TextEditingValue(
          text: f, selection: TextSelection.collapsed(offset: f.length));
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    final card = _cardCtrl.text.replaceAll(' ', '');
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Montant invalide');
      return;
    }
    if (card.length != 16) {
      setState(() => _error = 'Numéro de carte invalide');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    final ok = await widget.onSubmit(
      amount,
      card,
      _expiryCtrl.text,
      _cvvCtrl.text,
      _nameCtrl.text.isEmpty ? 'Card Holder' : _nameCtrl.text,
    );

    setState(() => _isLoading = false);
    if (mounted) {
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opération réussie !'),
            backgroundColor: Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _error = ref.read(walletProvider).error ?? 'Échec');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DarkSheet(
      title: widget.title,
      icon: Icons.credit_card_rounded,
      iconColor: const Color(0xFFD4A843),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _GlassField(
              controller: _amountCtrl,
              hint: 'Montant (FC)',
              icon: Icons.attach_money_rounded,
              keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          _GlassField(
              controller: _cardCtrl,
              hint: '1234 5678 9012 3456',
              icon: Icons.credit_card_rounded,
              keyboardType: TextInputType.number,
              maxLength: 19,
              onChanged: _formatCard),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _GlassField(
                  controller: _expiryCtrl,
                  hint: 'MM/AA',
                  icon: Icons.calendar_today_outlined,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  onChanged: _formatExpiry),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GlassField(
                  controller: _cvvCtrl,
                  hint: 'CVV',
                  icon: Icons.lock_outline_rounded,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscure: true),
            ),
          ]),
          const SizedBox(height: 10),
          _GlassField(
              controller: _nameCtrl,
              hint: 'Nom du titulaire',
              icon: Icons.person_outline_rounded),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: const TextStyle(color: Color(0xFFF87171), fontSize: 12)),
            ),
          const SizedBox(height: 20),
          _ActionButton(
            label: _isLoading ? 'Traitement...' : 'Confirmer',
            color: const Color(0xFFD4A843),
            isLoading: _isLoading,
            onTap: _submit,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sélecteur de méthode (Mobile Money | Carte Visa)
// ─────────────────────────────────────────────────────────────────────────────
class _MethodPickerShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onMobile;
  final VoidCallback onCard;

  const _MethodPickerShell({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onMobile,
    required this.onCard,
  });

  @override
  Widget build(BuildContext context) {
    return _DarkSheet(
      title: title,
      icon: icon,
      iconColor: iconColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          _BigOptionTile(
            icon: Icons.phone_android_rounded,
            title: 'Mobile Money',
            subtitle: 'Orange Money, M-Pesa, Airtel',
            color: const Color(0xFF22C55E),
            onTap: onMobile,
          ),
          const SizedBox(height: 12),
          _BigOptionTile(
            icon: Icons.credit_card_rounded,
            title: 'Carte Visa',
            subtitle: 'Visa, Mastercard',
            color: const Color(0xFFD4A843),
            onTap: onCard,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared — Dark bottom sheet avec glassmorphism
// ─────────────────────────────────────────────────────────────────────────────
class _DarkSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _DarkSheet({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F1E2E),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: iconColor, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Séparateur
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    height: 1,
                    color: Colors.white.withOpacity(0.07),
                  ),
                  // Contenu scrollable
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared — Tuile d'option large
// ─────────────────────────────────────────────────────────────────────────────
class _BigOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _BigOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: color.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared — Champ de saisie glassmorphism
// ─────────────────────────────────────────────────────────────────────────────
class _GlassField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final int? maxLength;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  const _GlassField({
    this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 18),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1E7DBA), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared — Bouton d'action
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.75)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
