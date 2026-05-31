import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/wallet_provider.dart';
import '../../../features/auth/providers/auth_controller.dart';
import '../../../features/wallet/services/biometric_service.dart';
import '../../../providers/exchange_rate_provider.dart';
import 'deposit_status_dialog.dart';

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
            title: 'Recharger votre portefeuille',
            icon: Icons.add,
            iconColor: const Color(0xFFE11D48), // Rouge comme sur la maquette
            onMobile: () => setState(() => _method = 'mobile'),
            onCard: () => setState(() => _method = 'card'),
          )
        : _method == 'mobile'
            ? _MobileMoneyForm(
                title: 'Recharger — Mobile Money',
                buttonLabel: 'Recharger',
                buttonColor: const Color(0xFF22C55E),
                onSubmit: (amount, provider, phone) async {
                  // Lance le dépôt et récupère l'oliOrderId pour le popup de statut
                  final result = await ref
                      .read(walletProvider.notifier)
                      .deposit(amount: amount, provider: provider, phone: phone);
                  if (result.success && result.oliOrderId != null) {
                    // Fermer le formulaire
                    if (context.mounted) Navigator.pop(context);
                    // Afficher le popup de suivi
                    if (context.mounted) {
                      await showDepositStatusDialog(
                        context: context,
                        ref: ref,
                        orderId: result.oliOrderId!,
                        amountFC: amount,
                      );
                    }
                    return true;
                  }
                  return result.success;
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
    // QR data : Format sécurisé contenant uniquement l'identifiant
    final qrData = 'oli://pay?id=$phone';

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

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // 1. Résolution sécurisée du destinataire
    final resolvedUser = await ref.read(walletProvider.notifier).resolveRecipient(phone);
    if (resolvedUser == null) {
      setState(() {
        _isLoading = false;
        _error = 'Destinataire introuvable ou non autorisé';
      });
      return;
    }

    final recipientName = resolvedUser['name'] ?? 'Utilisateur';
    
    // 2. Confirmation biométrique avec le VRAI nom
    final fee = amount * 0.01;
    final confirmed = await biometricService.authenticate(
      reason: 'Envoyer ${amount.toStringAsFixed(0)} FC à $recipientName ?\n(+ ${fee.toStringAsFixed(0)} FC de frais)',
    );

    if (!confirmed) {
      setState(() {
        _isLoading = false;
        _error = 'Authentification annulée';
      });
      return;
    }

    final ok = await ref.read(walletProvider.notifier).transfer(
          amount: amount,
          recipientPhone: phone,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );

    setState(() => _isLoading = false);

    if (mounted) {
      if (ok) {
        HapticFeedback.mediumImpact();
        AudioPlayer().play(AssetSource('images/kaching.mp3'));
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
            hint: 'Identifiant (@pseudo, numéro ou ID)',
            icon: Icons.person_search_rounded,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 10),
          _GlassField(
            controller: _amountCtrl,
            hint: 'Montant (FC)',
            icon: Icons.attach_money_rounded,
            keyboardType: TextInputType.number,
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _amountCtrl,
            builder: (context, value, _) {
              final amt = double.tryParse(value.text.replaceAll(',', '.')) ?? 0;
              if (amt <= 0) return const SizedBox(height: 10);
              final fee = amt * 0.01;
              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(
                  'Frais de transfert OLI (1%) : +${fee.toStringAsFixed(0)} FC',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                ),
              );
            },
          ),
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
  bool _hasPermission = false;
  bool _isPermissionChecked = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
        _isPermissionChecked = true;
        if (!status.isGranted) {
          _error = 'Accès à la caméra refusé. Veuillez l\'autoriser dans les paramètres.';
        }
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _handleScannedQr(String raw) async {
    try {
      final uri = Uri.parse(raw);
      String? identifier;
      
      if (uri.scheme == 'oli' && uri.host == 'pay') {
        identifier = uri.queryParameters['id'];
      } else if (uri.scheme == 'oli' && uri.host == 'transfer') {
        // Rétrocompatibilité avec les anciens QR codes
        identifier = uri.queryParameters['phone'];
      }

      if (identifier == null || identifier.isEmpty) {
        setState(() => _error = 'QR code invalide');
        return;
      }

      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Résolution sécurisée
      final resolvedUser = await ref.read(walletProvider.notifier).resolveRecipient(identifier);
      
      setState(() => _isLoading = false);

      if (resolvedUser != null) {
        setState(() {
          _scannedPhone = identifier;
          _scannedName = resolvedUser['name'] ?? 'Utilisateur certifié';
        });
      } else {
        setState(() => _error = 'Destinataire introuvable');
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _error = 'Format QR invalide';
      });
    }
  }

  Future<void> _send() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Montant invalide');
      return;
    }
    
    final fee = amount * 0.01;
    final confirmed = await biometricService.authenticate(
      reason: 'Envoyer ${amount.toStringAsFixed(0)} FC à $_scannedName ?\n(+ ${fee.toStringAsFixed(0)} FC de frais)',
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
        HapticFeedback.mediumImpact();
        AudioPlayer().play(AssetSource('images/kaching.mp3'));
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
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.4)),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!_isPermissionChecked)
                    const CircularProgressIndicator(color: Color(0xFF7C3AED))
                  else if (_hasPermission)
                    MobileScanner(
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null && _scannedPhone == null && !_isLoading) {
                            _handleScannedQr(barcode.rawValue!);
                            break;
                          }
                        }
                      },
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.no_photography_rounded, color: Colors.white54, size: 40),
                        const SizedBox(height: 12),
                        const Text('Caméra bloquée', style: TextStyle(color: Colors.white54)),
                        TextButton(
                          onPressed: () => openAppSettings(),
                          child: const Text('Ouvrir les paramètres', style: TextStyle(color: Color(0xFF7C3AED))),
                        ),
                      ],
                    ),
                  if (_hasPermission)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.8), width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      width: 180,
                      height: 180,
                    ),
                  if (_isLoading)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
                      ),
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
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _amountCtrl,
              builder: (context, value, _) {
                final amt = double.tryParse(value.text.replaceAll(',', '.')) ?? 0;
                if (amt <= 0) return const SizedBox(height: 12);
                final fee = amt * 0.01;
                return Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    'Frais de transfert OLI (1%) : +${fee.toStringAsFixed(0)} FC',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                  ),
                );
              },
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
    {'value': 'orange', 'label': 'Orange', 'color': Color(0xFFF97316)},
    {'value': 'mpesa', 'label': 'M-Pesa', 'color': Color(0xFF22C55E)},
    {'value': 'airtel', 'label': 'Airtel', 'color': Color(0xFFEF4444)},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authControllerProvider);
      final phone = authState.userData?['phone'] ?? '';
      if (phone.isNotEmpty) {
        _phoneCtrl.text = phone;
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(bool isUSD) async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Montant invalide');
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Numéro Mobile Money requis');
      return;
    }

    final currencyLabel = isUSD ? 'USD' : 'FC';
    final confirmed = await biometricService.authenticate(
      reason: 'Confirmer ${widget.buttonLabel} de ${amount.toStringAsFixed(isUSD ? 2 : 0)} $currencyLabel',
    );
    if (!confirmed) {
      setState(() => _error = 'Authentification annulée');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    
    // Le wallet_provider gère-t-il la devise ? Actuellement wallet_provider s'attend à amountFC pour UnipesaDeposit.
    // L'API backend attend amountFC pour Unipesa. Donc si c'est USD, on doit convertir en FC avant d'appeler onSubmit.
    // L'utilisateur demande que la recharge se fasse dans la monnaie du wallet.
    final finalAmount = isUSD 
        ? ref.read(exchangeRateProvider.notifier).convertAmount(amount, from: Currency.USD) 
        : amount;

    final ok = await widget.onSubmit(finalAmount, _provider, _phoneCtrl.text.trim());
    setState(() => _isLoading = false);

    if (mounted) {
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.buttonLabel} réussi !'),
            backgroundColor: const Color(0xFF103652),
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
    final maxH = MediaQuery.of(context).size.height * 0.9;
    final exchangeState = ref.watch(exchangeRateProvider);
    final isUSD = exchangeState.selectedCurrency == Currency.USD;
    final currencySymbol = isUSD ? '\$' : 'FC';
    final hintCurrency = isUSD ? 'USD' : 'FC';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white, // Thème épuré blanc
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.phone_android_rounded, color: const Color(0xFF103652), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Color(0xFF103652),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Content scrollable
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sélection opérateur
                      Text('Opérateur Mobile', style: TextStyle(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: _providers.map((p) {
                          final isSelected = _provider == p['value'];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _provider = p['value'] as String),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF103652) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF103652) : const Color(0xFFE2E8F0),
                                    width: 1.5,
                                  ),
                                  boxShadow: isSelected ? [
                                    BoxShadow(color: const Color(0xFF103652).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
                                  ] : [],
                                ),
                                child: Text(
                                  p['label'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      
                      // Montant
                      Text('Montant', style: TextStyle(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) => setState(() {}),
                        style: const TextStyle(color: Color(0xFF103652), fontSize: 16, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(currencySymbol, style: const TextStyle(color: Color(0xFF103652), fontSize: 18, fontWeight: FontWeight.w800)),
                          ),
                          suffixText: hintCurrency,
                          suffixStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF103652), width: 2)),
                        ),
                      ),
                      
                      // Frais preview
                      if (_amountCtrl.text.isNotEmpty && double.tryParse(_amountCtrl.text.replaceAll(',', '.')) != null)
                        Builder(builder: (context) {
                          final amt = double.parse(_amountCtrl.text.replaceAll(',', '.'));
                          final fee = amt * 0.05;
                          final total = amt + fee;
                          final isDeposit = widget.buttonLabel.toLowerCase().contains('recharger');
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Montant demandé :', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                      Text('$currencySymbol${amt.toStringAsFixed(isUSD ? 2 : 0)}', style: const TextStyle(color: Color(0xFF103652), fontSize: 13, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Frais de plateforme (5%) :', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                      Text('$currencySymbol${fee.toStringAsFixed(isUSD ? 2 : 0)}', style: const TextStyle(color: Color(0xFFE11D48), fontSize: 13, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    child: Divider(color: Color(0xFFE2E8F0), height: 1),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(isDeposit ? 'Vous serez facturé :' : 'Total déduit :', style: const TextStyle(color: Color(0xFF103652), fontSize: 14, fontWeight: FontWeight.w800)),
                                      Text('$currencySymbol${total.toStringAsFixed(isUSD ? 2 : 0)}', style: const TextStyle(color: Color(0xFF103652), fontSize: 16, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      
                      const SizedBox(height: 20),
                      
                      // Numéro de téléphone
                      Text('Numéro Mobile Money', style: TextStyle(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Color(0xFF103652), fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: '+243...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.smartphone_rounded, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF103652), width: 2)),
                        ),
                      ),
                      
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFE11D48), size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 13, fontWeight: FontWeight.w500))),
                            ],
                          ),
                        ),
                        
                      const SizedBox(height: 32),
                      
                      // Bouton
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _submit(isUSD),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF103652), // Bouton toujours bleu pour le thème "bleu et blanc"
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text(widget.buttonLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final maxH = MediaQuery.of(context).size.height * 0.9;
    final exchangeState = ref.watch(exchangeRateProvider);
    final isUSD = exchangeState.selectedCurrency == Currency.USD;
    final currencySymbol = isUSD ? '\$' : 'FC';
    final hintCurrency = isUSD ? 'USD' : 'FC';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white, // Thème épuré blanc
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.credit_card_rounded, color: Color(0xFF103652), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Color(0xFF103652),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Content scrollable
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Montant
                      const Text('Montant', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) => setState(() {}),
                        style: const TextStyle(color: Color(0xFF103652), fontSize: 16, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(currencySymbol, style: const TextStyle(color: Color(0xFF103652), fontSize: 18, fontWeight: FontWeight.w800)),
                          ),
                          suffixText: hintCurrency,
                          suffixStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF103652), width: 2)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Informations de la carte
                      const Text('Détails de la carte', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      
                      // Numéro de carte
                      TextField(
                        controller: _cardCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 19,
                        onChanged: _formatCard,
                        style: const TextStyle(color: Color(0xFF103652), fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '1234 5678 9012 3456',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.credit_card_rounded, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF103652), width: 2)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Expiration et CVV
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _expiryCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 5,
                              onChanged: _formatExpiry,
                              style: const TextStyle(color: Color(0xFF103652), fontSize: 16, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'MM/AA',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF94A3B8), size: 20),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF103652), width: 2)),
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
                              style: const TextStyle(color: Color(0xFF103652), fontSize: 16, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'CVV',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF103652), width: 2)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Titulaire
                      TextField(
                        controller: _nameCtrl,
                        keyboardType: TextInputType.name,
                        style: const TextStyle(color: Color(0xFF103652), fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Nom sur la carte',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF103652), width: 2)),
                        ),
                      ),
                      
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFE11D48), size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 13, fontWeight: FontWeight.w500))),
                            ],
                          ),
                        ),
                        
                      const SizedBox(height: 32),
                      
                      // Bouton
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF103652),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text('Confirmer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final maxH = MediaQuery.of(context).size.height * 0.88;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF103652), // Bleu foncé de la maquette
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header type Mockup
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 28, weight: 800),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _WhiteOptionTile(
                  icon: Icons.phone_android_rounded,
                  title: 'Mobile Money',
                  onTap: onMobile,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _WhiteOptionTile(
                  icon: Icons.credit_card_rounded,
                  title: 'Carte crédit',
                  onTap: onCard,
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhiteOptionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _WhiteOptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_WhiteOptionTile> createState() => _WhiteOptionTileState();
}

class _WhiteOptionTileState extends State<_WhiteOptionTile> with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: const Color(0xFF103652), size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Color(0xFF103652),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF103652),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
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
