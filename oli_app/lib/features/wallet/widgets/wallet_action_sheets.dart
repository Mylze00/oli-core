import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'withdraw_status_dialog.dart';
import '../../../core/theme/oli_glass.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../core/router/network/dio_provider.dart';
import '../../contacts/services/contacts_match_service.dart';
import '../../contacts/utils/phone_normalizer.dart';
import '../utils/payment_qr.dart';

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
  // Recharge par Mobile Money uniquement : la carte bancaire n'est pas disponible.
  String? _method = 'mobile'; // 'mobile' (la branche 'card' est inactive)

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
  // Retrait par Mobile Money uniquement : pas de retrait vers carte.
  String? _method = 'mobile';

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
                  final authenticated = await biometricService.authenticate(
                    reason: 'Confirmez votre identité pour activer le retrait',
                  );
                  if (!authenticated) {
                    return false;
                  }

                  final result = await ref.read(walletProvider.notifier).withdraw(amount: amount, provider: provider, phone: phone); if (result.success && result.oliOrderId != null) { if (context.mounted) Navigator.pop(context); if (context.mounted) { await showWithdrawStatusDialog(context: context, ref: ref, orderId: result.oliOrderId!, amountFC: amount); } return true; } return result.success;
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
//
// Parcours : choix du mode → choix du destinataire (contacts Oli, carnet,
// saisie ou QR) → formulaire de montant commun → transfert par id du compte.
class EnvoyerSheet extends ConsumerStatefulWidget {
  const EnvoyerSheet({super.key});

  @override
  ConsumerState<EnvoyerSheet> createState() => _EnvoyerSheetState();
}

class _EnvoyerSheetState extends ConsumerState<EnvoyerSheet> {
  String? _mode; // 'contact' | 'qr'
  _TransferRecipient? _recipient;
  double? _requestedAmount; // montant demandé par un QR (facultatif)

  void _onRecipientSelected(_TransferRecipient recipient, {double? amount}) {
    setState(() {
      _recipient = recipient;
      _requestedAmount = amount;
    });
  }

  void _changeRecipient() {
    setState(() {
      _recipient = null;
      _requestedAmount = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_recipient != null) {
      return _TransferAmountForm(
        recipient: _recipient!,
        initialAmount: _requestedAmount,
        onChangeRecipient: _changeRecipient,
      );
    }

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
              subtitle: 'Vos contacts Oli, numéro ou ID Oli',
              color: const Color(0xFF1E7DBA),
              onTap: () => setState(() => _mode = 'contact'),
            ),
            const SizedBox(height: 12),
            _BigOptionTile(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scanner un QR Code',
              subtitle: 'Scanner le QR du destinataire',
              color: const Color(0xFF1E7DBA),
              onTap: () => setState(() => _mode = 'qr'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    if (_mode == 'contact') {
      return _RecipientPicker(onSelected: _onRecipientSelected);
    }

    return _TransferQrScanner(onResolved: _onRecipientSelected);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ④ RECEVOIR — QR Code unique
// ─────────────────────────────────────────────────────────────────────────────
//
// Le QR contient l'ID Oli (oli://pay?u=OLI-1234-5678), jamais le numéro de
// téléphone. Il est fixe et peut être imprimé ; un montant facultatif peut y
// être ajouté (…&amount=5000).
class RecevoirSheet extends ConsumerStatefulWidget {
  const RecevoirSheet({super.key});

  @override
  ConsumerState<RecevoirSheet> createState() => _RecevoirSheetState();
}

class _RecevoirSheetState extends ConsumerState<RecevoirSheet> {
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(authControllerProvider).userData;
    final idOli = userData?['id_oli']?.toString() ?? '';
    final phone = userData?['phone']?.toString() ?? '';
    final name = userData?['name']?.toString() ?? 'Utilisateur';
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    final qrData = buildPaymentQrData(idOli: idOli, phone: phone, amount: amount);

    return _DarkSheet(
      title: 'Recevoir de l\'argent',
      icon: Icons.arrow_downward_rounded,
      iconColor: const Color(0xFF22C55E),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Carte QR
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
                if (qrData != null)
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  )
                else
                  const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'QR indisponible : identifiant du compte manquant.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ),
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
                if (idOli.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    idOli,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ],
                if (amount != null && amount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Montant demandé : ${amount.toStringAsFixed(0)} FC',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E7DBA),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Montant facultatif intégré au QR
          _GlassField(
            controller: _amountCtrl,
            hint: 'Montant à demander en FC (facultatif)',
            icon: Icons.request_quote_outlined,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Copier l'ID Oli (ou le numéro pour un ancien compte sans ID)
          GestureDetector(
            onTap: () {
              final value = idOli.isNotEmpty ? idOli : phone;
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(idOli.isNotEmpty ? 'ID Oli copié !' : 'Numéro copié !'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF22C55E),
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
                  Flexible(
                    child: Text(
                      idOli.isNotEmpty ? 'Copier mon ID Oli : $idOli' : 'Copier mon numéro : $phone',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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
              'Montrez ce QR ou partagez votre ID Oli pour recevoir un paiement. '
              'Votre numéro de téléphone n\'apparaît pas dans le QR.',
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
      iconColor: const Color(0xFF1E7DBA),
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
                    final isCredit = tx.amount > 0; // le signe de l'opération vient du montant
                    final color = isCredit ? const Color(0xFF22C55E) : const Color(0xFFF87171);
                    final icon = isCredit
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded;
                    final sign = isCredit ? '+' : '-';

                    return InkWell(
                      onTap: () => _showTxDetail(context, tx, color, icon, sign),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDate(tx.createdAt),
                                  style: const TextStyle(
                                    color: OliPalette.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$sign ${_formatFc(tx.amount)} FC',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _statusColor(tx.status).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (tx.status == 'pending')
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: SizedBox(width: 8, height: 8, child: CircularProgressIndicator(color: _statusColor(tx.status), strokeWidth: 1.5)),
                                      )
                                    else if (tx.status == 'completed')
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Icon(Icons.check_circle_rounded, size: 10, color: _statusColor(tx.status)),
                                      )
                                    else if (tx.status == 'failed')
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Icon(Icons.cancel_rounded, size: 10, color: _statusColor(tx.status)),
                                      ),
                                    Text(
                                      _statusLabel(tx.status),
                                      style: TextStyle(
                                        color: _statusColor(tx.status),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  /// Montant sans signe, avec séparateur de milliers.
  String _formatFc(num amount) => amount
      .abs()
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');

  void _showTxDetail(BuildContext context, dynamic tx, Color color, IconData icon, String sign) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _DarkSheet(
        title: 'Détails de l\'opération',
        icon: Icons.receipt_long_rounded,
        iconColor: color,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              '$sign ${_formatFc(tx.amount)} FC',
              style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor(tx.status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tx.status == 'pending')
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: _statusColor(tx.status), strokeWidth: 2)),
                    )
                  else if (tx.status == 'completed')
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.check_circle_rounded, size: 14, color: _statusColor(tx.status)),
                    )
                  else if (tx.status == 'failed')
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.cancel_rounded, size: 14, color: _statusColor(tx.status)),
                    ),
                  Text(
                    _statusLabel(tx.status),
                    style: TextStyle(color: _statusColor(tx.status), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildDetailRow('Type d\'opération', _txLabel(tx.type)),
            _buildDetailRow('Description', tx.description.isNotEmpty ? tx.description : 'Aucune description'),
            _buildDetailRow('Fournisseur / Méthode', tx.provider ?? 'N/A'),
            _buildDetailRow('Référence interne', tx.reference ?? 'N/A'),
            _buildDetailRow('Date', _formatDate(tx.createdAt)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
// Destinataire d'un envoi (compte Oli vérifié par le serveur)
// ─────────────────────────────────────────────────────────────────────────────
class _TransferRecipient {
  final int id;
  final String name;
  final String? avatarUrl;

  /// Numéro (complet pour un contact, masqué sinon) ou ID Oli.
  final String? subtitle;

  const _TransferRecipient({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.subtitle,
  });

  /// Réponse de GET /wallet/resolve-recipient.
  factory _TransferRecipient.fromResolved(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString().trim();
    return _TransferRecipient(
      id: (json['id'] as num).toInt(),
      name: name.isEmpty ? 'Utilisateur Oli' : name,
      avatarUrl: json['avatar_url']?.toString(),
      subtitle: (json['phone'] ?? json['phone_masked'] ?? json['id_oli'])?.toString(),
    );
  }

  /// Contact de « Mes contacts » ou du carnet (déjà un compte Oli).
  factory _TransferRecipient.fromContact(ContactMatch contact) => _TransferRecipient(
        id: contact.id,
        name: contact.displayName,
        avatarUrl: contact.avatarUrl,
        subtitle: contact.phone.isEmpty ? null : contact.phone,
      );
}

/// Avatar rond : photo du compte ou initiale du nom.
class _RecipientAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const _RecipientAvatar({required this.name, this.avatarUrl, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: OliPalette.blue.withOpacity(0.25),
      foregroundImage: url != null && url.startsWith('http') ? NetworkImage(url) : null,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// Ligne de contact touchable.
class _ContactRow extends StatelessWidget {
  final String name;
  final String? subtitle;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _ContactRow({
    required this.name,
    required this.onTap,
    this.subtitle,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            _RecipientAvatar(name: name, avatarUrl: avatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: OliPalette.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: OliPalette.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Titre de section (« Mes contacts Oli », « Dans votre carnet »).
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: OliPalette.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Choix du destinataire : Mes contacts Oli, carnet du téléphone, ou saisie
// ─────────────────────────────────────────────────────────────────────────────
class _RecipientPicker extends ConsumerStatefulWidget {
  final void Function(_TransferRecipient recipient, {double? amount}) onSelected;

  const _RecipientPicker({required this.onSelected});

  @override
  ConsumerState<_RecipientPicker> createState() => _RecipientPickerState();
}

class _RecipientPickerState extends ConsumerState<_RecipientPicker> {
  final _searchCtrl = TextEditingController();
  List<ContactMatch> _contacts = const [];
  List<ContactMatch> _bookMatches = const [];
  bool _loadingContacts = true;
  bool _syncingBook = false;
  bool _resolving = false;
  String? _error;

  ContactsMatchService get _contactsService => ContactsMatchService(ref.read(dioProvider));

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _contactsService.fetchContacts();
      if (mounted) setState(() => _contacts = contacts);
    } catch (e) {
      debugPrint('Erreur chargement contacts: $e');
    } finally {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  /// Comptes Oli présents dans le carnet du téléphone (avec consentement).
  Future<void> _syncAddressBook() async {
    final consent = await showOliConfirmDialog(
      context,
      title: 'Chercher dans mon carnet',
      message: 'Oli va lire les numéros de votre carnet pour trouver ceux qui ont un compte Oli. '
          'Les numéros sont envoyés de façon sécurisée et ne sont pas conservés.',
      confirmLabel: 'Continuer',
    );
    if (!consent || !mounted) return;

    setState(() {
      _syncingBook = true;
      _error = null;
    });
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (mounted) setState(() => _error = 'Accès aux contacts refusé.');
        return;
      }
      final phoneContacts = await FlutterContacts.getContacts(withProperties: true);
      final phones = <String>{};
      for (final c in phoneContacts) {
        for (final p in c.phones) {
          final normalized = normalizePhone(p.number);
          if (normalized != null) phones.add(normalized);
        }
      }
      final matches = await _contactsService.matchPhones(phones.toList());
      final known = _contacts.map((c) => c.id).toSet();
      if (mounted) {
        setState(() {
          _bookMatches = matches.where((m) => !known.contains(m.id)).toList()
            ..sort((a, b) => a.displayName.compareTo(b.displayName));
          if (matches.isEmpty) _error = 'Aucun contact de votre carnet n\'est encore sur Oli.';
        });
      }
    } catch (e) {
      debugPrint('Erreur lecture du carnet: $e');
      if (mounted) setState(() => _error = 'Impossible de lire votre carnet. Réessayez plus tard.');
    } finally {
      if (mounted) setState(() => _syncingBook = false);
    }
  }

  /// Recherche d'un numéro ou d'un ID Oli saisi.
  Future<void> _resolveTyped([String? value]) async {
    final code = parsePaymentCode(value ?? _searchCtrl.text);
    if (code == null) {
      setState(() => _error = 'Saisissez un numéro (0812…, +243…) ou un ID Oli (OLI-1234-5678).');
      return;
    }
    setState(() {
      _resolving = true;
      _error = null;
    });
    final result = await ref.read(walletProvider.notifier).resolveRecipient(code.identifier);
    if (!mounted) return;
    setState(() => _resolving = false);
    final user = result.user;
    if (user == null) {
      setState(() => _error = result.error);
      return;
    }
    widget.onSelected(_TransferRecipient.fromResolved(user), amount: code.amount);
  }

  bool _matches(ContactMatch c, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    final digits = query.replaceAll(RegExp(r'\D'), '');
    return c.displayName.toLowerCase().contains(q) ||
        (digits.length >= 3 && c.phone.replaceAll(RegExp(r'\D'), '').contains(digits));
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim();
    final contacts = _contacts.where((c) => _matches(c, query)).toList();
    final bookMatches = _bookMatches.where((c) => _matches(c, query)).toList();
    final typedCode = parsePaymentCode(query);

    return _DarkSheet(
      title: 'Choisir un destinataire',
      icon: Icons.contacts_outlined,
      iconColor: const Color(0xFF1E7DBA),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _GlassField(
            controller: _searchCtrl,
            hint: 'Nom, numéro ou ID Oli',
            icon: Icons.person_search_rounded,
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: _resolveTyped,
          ),

          // Numéro ou ID Oli reconnu : envoi direct après vérification
          if (typedCode != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: _resolving ? null : _resolveTyped,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: oliGlassCardDecoration(highlighted: true, radius: 14),
                child: Row(
                  children: [
                    const Icon(Icons.send_rounded, color: OliPalette.blueOnDark, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Envoyer à ${typedCode.identifier}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_resolving)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: OliPalette.blueOnDark),
                      ),
                  ],
                ),
              ),
            ),
          ],

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(color: OliPalette.danger, fontSize: 12)),
            ),

          // Carnet du téléphone (indisponible sur le web)
          if (!kIsWeb) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _syncingBook ? null : _syncAddressBook,
              style: oliSecondaryButtonStyle(),
              icon: _syncingBook
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.import_contacts_rounded, size: 18),
              label: const Text('Chercher dans mon carnet'),
            ),
          ],

          // Mes contacts Oli
          const _SectionLabel('Mes contacts Oli'),
          if (_loadingContacts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: OliPalette.blueOnDark)),
            )
          else if (contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _contacts.isEmpty
                    ? 'Aucun contact pour l\'instant. Recherchez un numéro ou un ID Oli : '
                        'les personnes à qui vous envoyez de l\'argent sont ajoutées ici.'
                    : 'Aucun contact ne correspond.',
                style: const TextStyle(color: OliPalette.textSecondary, fontSize: 13),
              ),
            )
          else
            ...contacts.map((c) => _ContactRow(
                  name: c.displayName,
                  subtitle: c.phone,
                  avatarUrl: c.avatarUrl,
                  onTap: () => widget.onSelected(_TransferRecipient.fromContact(c)),
                )),

          // Comptes Oli trouvés dans le carnet
          if (bookMatches.isNotEmpty) ...[
            const _SectionLabel('Dans votre carnet'),
            ...bookMatches.map((c) => _ContactRow(
                  name: c.displayName,
                  subtitle: c.phone,
                  avatarUrl: c.avatarUrl,
                  onTap: () => widget.onSelected(_TransferRecipient.fromContact(c)),
                )),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formulaire de montant (commun au contact et au QR)
// ─────────────────────────────────────────────────────────────────────────────
class _TransferAmountForm extends ConsumerStatefulWidget {
  final _TransferRecipient recipient;
  final double? initialAmount;
  final VoidCallback onChangeRecipient;

  const _TransferAmountForm({
    required this.recipient,
    required this.onChangeRecipient,
    this.initialAmount,
  });

  @override
  ConsumerState<_TransferAmountForm> createState() => _TransferAmountFormState();
}

class _TransferAmountFormState extends ConsumerState<_TransferAmountForm> {
  static const double _minAmount = 100; // identique au serveur
  late final TextEditingController _amountCtrl;
  final _noteCtrl = TextEditingController();

  /// Même clé pour toutes les tentatives de cet envoi : le serveur ne débite
  /// qu'une fois, même si l'utilisateur réessaie après une coupure réseau.
  final String _transferKey = newTransferKey();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAmount;
    _amountCtrl = TextEditingController(text: initial == null ? '' : initial.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Montant invalide');
      return;
    }
    if (amount < _minAmount) {
      setState(() => _error = 'Montant minimum : ${_minAmount.toStringAsFixed(0)} FC');
      return;
    }

    final name = widget.recipient.name;
    final fee = (amount * 0.01).roundToDouble();
    final confirmed = await biometricService.authenticate(
      reason: 'Envoyer ${amount.toStringAsFixed(0)} FC à $name ?\n(+ ${fee.toStringAsFixed(0)} FC de frais)',
    );
    if (!confirmed) {
      setState(() => _error = 'Authentification annulée');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    final note = _noteCtrl.text.trim();
    final ok = await ref.read(walletProvider.notifier).transfer(
          amount: amount,
          receiverId: widget.recipient.id,
          idempotencyKey: _transferKey,
          note: note.isEmpty ? null : note,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      HapticFeedback.mediumImpact();
      AudioPlayer().play(AssetSource('images/kaching.mp3'));
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${amount.toStringAsFixed(0)} FC envoyés à $name'),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _error = ref.read(walletProvider).error ?? 'Erreur de transfert');
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipient = widget.recipient;
    return _DarkSheet(
      title: 'Envoyer de l\'argent',
      icon: Icons.send_rounded,
      iconColor: const Color(0xFF1E7DBA),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Destinataire vérifié
          Container(
            padding: const EdgeInsets.all(14),
            decoration: oliGlassCardDecoration(highlighted: true, radius: 14),
            child: Row(
              children: [
                _RecipientAvatar(name: recipient.name, avatarUrl: recipient.avatarUrl, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              recipient.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: OliPalette.blueOnDark, size: 16),
                        ],
                      ),
                      if (recipient.subtitle != null)
                        Text(
                          recipient.subtitle!,
                          style: const TextStyle(color: OliPalette.textSecondary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : widget.onChangeRecipient,
                  child: const Text('Changer', style: TextStyle(color: OliPalette.blueOnDark)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
              final fee = (amt * 0.01).roundToDouble();
              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(
                  'Frais de transfert OLI (1 %) : +${fee.toStringAsFixed(0)} FC',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                ),
              );
            },
          ),
          _GlassField(
            controller: _noteCtrl,
            hint: 'Motif (facultatif)',
            icon: Icons.notes_rounded,
            maxLength: 140,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: OliPalette.danger, fontSize: 12)),
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
  final void Function(_TransferRecipient recipient, {double? amount}) onResolved;

  const _TransferQrScanner({required this.onResolved});

  @override
  ConsumerState<_TransferQrScanner> createState() => _TransferQrScannerState();
}

class _TransferQrScannerState extends ConsumerState<_TransferQrScanner> {
  bool _isLoading = false;
  String? _error;
  String? _lastRaw; // évite de retraiter le même QR à chaque image de la caméra
  bool _hasPermission = false;
  bool _isPermissionChecked = false;
  bool _scanStarted = false; // Web : la caméra démarre après un appui
  int _retry = 0; // incrémenté pour relancer le lecteur

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    if (kIsWeb) {
      // Sur le web, le navigateur demande l'autorisation au démarrage du lecteur
      if (mounted) {
        setState(() {
          _hasPermission = true;
          _isPermissionChecked = true;
        });
      }
      return;
    }
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
        _isPermissionChecked = true;
      });
    }
  }

  Future<void> _handleCode(String raw, {bool typed = false}) async {
    if (_isLoading) return;
    if (!typed && raw == _lastRaw) return;
    _lastRaw = raw;

    final code = parsePaymentCode(raw);
    if (code == null) {
      setState(() => _error = typed
          ? 'Saisissez un numéro (0812…, +243…) ou un ID Oli (OLI-1234-5678).'
          : 'Ce QR code n\'est pas un QR de paiement Oli.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await ref.read(walletProvider.notifier).resolveRecipient(code.identifier);
    if (!mounted) return;
    setState(() => _isLoading = false);

    final user = result.user;
    if (user == null) {
      setState(() => _error = result.error);
      return;
    }
    widget.onResolved(_TransferRecipient.fromResolved(user), amount: code.amount);
  }

  @override
  Widget build(BuildContext context) {
    return _DarkSheet(
      title: 'Scanner QR Code',
      icon: Icons.qr_code_scanner_rounded,
      iconColor: const Color(0xFF1E7DBA),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E7DBA).withOpacity(0.4)),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!_isPermissionChecked)
                  const CircularProgressIndicator(color: Color(0xFF1E7DBA))
                else if (_hasPermission && kIsWeb && !_scanStarted)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, color: Colors.white54, size: 40),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setState(() => _scanStarted = true),
                        child: const Text('Activer la caméra',
                            style: TextStyle(color: Color(0xFF1E7DBA), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                else if (_hasPermission)
                  MobileScanner(
                    key: ValueKey('scanner-$_retry'),
                    errorBuilder: (context, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 40),
                            const SizedBox(height: 10),
                            const Text(
                              'Caméra indisponible. Autorisez la caméra, puis réessayez, ou saisissez le numéro ou l\'ID Oli.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Détail : ${error.errorCode.name}',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _retry++),
                              child: const Text('Réessayer', style: TextStyle(color: Color(0xFF1E7DBA))),
                            ),
                          ],
                        ),
                      ),
                    ),
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        final raw = barcode.rawValue;
                        if (raw != null) {
                          _handleCode(raw);
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
                        child: const Text('Ouvrir les paramètres', style: TextStyle(color: Color(0xFF1E7DBA))),
                      ),
                    ],
                  ),
                if (_hasPermission)
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF1E7DBA).withOpacity(0.8), width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      width: 180,
                      height: 180,
                    ),
                  ),
                if (_isLoading)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Color(0xFF1E7DBA)),
                    ),
                  ),
              ],
            ),
          ),
          // Erreurs de lecture visibles pendant le scan
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: OliPalette.danger, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          // Saisie manuelle (caméra indisponible, QR abîmé…)
          _GlassField(
            hint: 'Ou saisir un numéro ou un ID Oli',
            icon: Icons.keyboard_rounded,
            onSubmitted: (value) => _handleCode(value, typed: true),
          ),
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
  bool _isUSD = false;

  final _providers = [
    {'value': 'orange', 'label': 'Orange', 'color': Color(0xFFF97316)},
    {'value': 'mpesa', 'label': 'M-Pesa', 'color': Color(0xFF22C55E)},
    {'value': 'airtel', 'label': 'Airtel', 'color': Color(0xFFEF4444)},
    {'value': 'africell', 'label': 'Africell', 'color': Color(0xFFA855F7)},
  ];

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(() {
      _detectProvider(_phoneCtrl.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authControllerProvider);
      final phone = authState.userData?['phone'] ?? '';
      if (phone.isNotEmpty) {
        _phoneCtrl.text = phone;
        _detectProvider(phone);
      }
    });
  }

  void _detectProvider(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('243')) clean = clean.substring(3);
    if (clean.startsWith('0')) clean = clean.substring(1);
    
    if (clean.length >= 2) {
      String prefix = clean.substring(0, 2);
      if (['81', '82', '83'].contains(prefix)) {
        if (_provider != 'mpesa') setState(() => _provider = 'mpesa');
      } else if (['99', '97', '98'].contains(prefix)) {
        if (_provider != 'airtel') setState(() => _provider = 'airtel');
      } else if (['84', '85', '89'].contains(prefix)) {
        if (_provider != 'orange') setState(() => _provider = 'orange');
      } else if (['90', '80', '88', '86'].contains(prefix)) {
        if (_provider != 'africell') setState(() => _provider = 'africell');
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountInput = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amountInput == null || amountInput <= 0) {
      setState(() => _error = 'Montant invalide');
      return;
    }
    final amountFC = _isUSD ? amountInput * 2300 : amountInput;
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Numéro Mobile Money requis');
      return;
    }

    final confirmed = await biometricService.authenticate(
      reason: 'Confirmer ${widget.buttonLabel} de ${amountFC.toStringAsFixed(0)} FC',
    );
    if (!confirmed) {
      setState(() => _error = 'Authentification annulée');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    
    final ok = await widget.onSubmit(amountFC, _provider, _phoneCtrl.text.trim());
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
    final currencySymbol = _isUSD ? '\$' : 'FC';
    final hintCurrency = _isUSD ? 'USD' : 'FC';

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Montant', style: TextStyle(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                          GestureDetector(
                            onTap: () => setState(() {
                              _isUSD = !_isUSD;
                              _amountCtrl.clear();
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _isUSD ? const Color(0xFF1E7DBA) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('\$', style: TextStyle(color: _isUSD ? Colors.white : const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: !_isUSD ? const Color(0xFF1E7DBA) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('FC', style: TextStyle(color: !_isUSD ? Colors.white : const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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
                      
                      // Légende FC si USD
                      if (_isUSD && _amountCtrl.text.isNotEmpty && double.tryParse(_amountCtrl.text.replaceAll(',', '.')) != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Text(
                            '≈ ${(double.parse(_amountCtrl.text.replaceAll(',', '.')) * 2300).toStringAsFixed(0)} FC',
                            style: const TextStyle(color: Color(0xFF1E7DBA), fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      
                      // Frais preview
                      if (_amountCtrl.text.isNotEmpty && double.tryParse(_amountCtrl.text.replaceAll(',', '.')) != null)
                        Builder(builder: (context) {
                          final amountInput = double.parse(_amountCtrl.text.replaceAll(',', '.'));
                          final amtFC = _isUSD ? amountInput * 2300 : amountInput;
                          final fee = amtFC * 0.05;
                          final total = amtFC + fee;
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
                                      Text('${amtFC.toStringAsFixed(0)} FC', style: const TextStyle(color: Color(0xFF103652), fontSize: 13, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Frais de plateforme (5%) :', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                      Text('${fee.toStringAsFixed(0)} FC', style: const TextStyle(color: Color(0xFFE11D48), fontSize: 13, fontWeight: FontWeight.w700)),
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
                                      Text('${total.toStringAsFixed(0)} FC', style: const TextStyle(color: Color(0xFF103652), fontSize: 16, fontWeight: FontWeight.w900)),
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
                          onPressed: _isLoading ? null : () => _submit(),
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
        child: OliGlassPanel(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
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
        decoration: oliGlassCardDecoration(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: OliPalette.textSecondary,
                          fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: OliPalette.textSecondary, size: 16),
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


