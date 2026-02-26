import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_controller.dart';
import '../providers/wallet_provider.dart';
import '../models/transaction_model.dart';
import '../widgets/payment_dialogs.dart';
import '../widgets/cash_bill_widget.dart';
import '../services/biometric_service.dart';
import '../services/receipt_service.dart';
import '../../../providers/exchange_rate_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _balanceVisible = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(walletProvider.notifier).loadWalletData());
  }

  void _showTransactionDialog(bool isDeposit) async {
    if (isDeposit) {
      final paymentMethod = await showDialog<String>(
        context: context,
        builder: (_) => const PaymentMethodSelectionDialog(),
      );
      if (paymentMethod != null && mounted) {
        showDialog(
          context: context,
          builder: (_) => paymentMethod == 'mobile'
              ? PaymentMethodSelectionDialog()
              : const CardPaymentDialog(),
        );
      }
    } else {
      // Biometric auth before withdrawal
      final ok = await biometricService.authenticate(
        reason: 'Confirmez votre retraite',
      );
      if (!ok || !mounted) return;
      showDialog(
        context: context,
        builder: (_) => const CardPaymentDialog(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Mon Wallet Oli'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(walletProvider.notifier).loadWalletData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Carte de solde redessinée ───────────────────────────────
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D1F4C), Color(0xFF1B3A84), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Solde disponible',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                          child: Icon(
                            _balanceVisible ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _balanceVisible
                          ? Text(
                              key: const ValueKey('visible'),
                              walletState.isLoading
                                  ? '•••••'
                                  : exchangeNotifier.formatProductPrice(walletState.balance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            )
                          : const Text(
                              key: ValueKey('hidden'),
                              '●●●●●●●',
                              style: TextStyle(color: Colors.white54, fontSize: 28, letterSpacing: 4),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Actions rapides
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _QuickAction(
                          icon: Icons.add_rounded,
                          label: 'Dépôt',
                          color: Colors.greenAccent,
                          onTap: () => _showTransactionDialog(true),
                        ),
                        _QuickAction(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Retrait',
                          color: Colors.orangeAccent,
                          onTap: () => _showTransactionDialog(false),
                        ),
                        _QuickAction(
                          icon: Icons.send_rounded,
                          label: 'Envoyer',
                          color: Colors.cyanAccent,
                          onTap: () => _showSendSheet(),
                        ),
                        _QuickAction(
                          icon: Icons.request_page_outlined,
                          label: 'Demander',
                          color: Colors.purpleAccent,
                          onTap: () => _showRequestSheet(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (walletState.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(walletState.error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // ── Historique ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text('Historique des transactions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Icon(Icons.history, color: Colors.grey.shade500, size: 20),
                  ],
                ),
              ),

              if (walletState.isLoading && walletState.transactions.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ))
              else if (walletState.transactions.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'Aucune transaction',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...walletState.transactions.map((tx) => _TransactionCard(
                  tx: tx,
                  exchangeNotifier: exchangeNotifier,
                  onReceiptTap: () => receiptService.showReceipt(context, tx),
                )),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Send Cash avec biométrie ──────────────────────────────────────────────
  Future<void> _showSendSheet() async {
    // D'abord biométrie
    final ok = await biometricService.authenticate(
      reason: 'Confirmer l\'envoi d\'argent',
    );
    if (!ok || !mounted) return;

    // Puis sheet
    showDialog(
      context: context,
      builder: (_) => const CardPaymentDialog(),
    );
  }

  Future<void> _showRequestSheet() async {
    // Pour l'instant : message placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Fonctionnalité disponible depuis le chat produit'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }
}

// ── Widgets helpers ──────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final WalletTransaction tx;
  final dynamic exchangeNotifier;
  final VoidCallback onReceiptTap;

  const _TransactionCard({
    required this.tx,
    required this.exchangeNotifier,
    required this.onReceiptTap,
  });

  bool get _isCredit => tx.type == 'deposit' || tx.type == 'refund';

  IconData get _icon {
    switch (tx.type) {
      case 'deposit': return Icons.call_received_rounded;
      case 'refund': return Icons.replay_rounded;
      case 'transfer': return Icons.swap_horiz_rounded;
      default: return Icons.call_made_rounded;
    }
  }

  Color get _color => _isCredit ? const Color(0xFF00C853) : const Color(0xFFDD2C00);

  @override
  Widget build(BuildContext context) {
    final dateStr = '${tx.createdAt.day.toString().padLeft(2, '0')}/'
        '${tx.createdAt.month.toString().padLeft(2, '0')}/'
        '${tx.createdAt.year}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_icon, color: _color, size: 20),
        ),
        title: Text(
          tx.description,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          dateStr,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_isCredit ? '+' : '-'}${exchangeNotifier.formatProductPrice(tx.amount)}',
                  style: TextStyle(
                    color: _color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tx.status == 'completed'
                        ? Colors.green.shade50
                        : tx.status == 'failed'
                            ? Colors.red.shade50
                            : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tx.status == 'completed' ? 'Complété' : tx.status == 'failed' ? 'Échoué' : 'En attente',
                    style: TextStyle(
                      fontSize: 9,
                      color: tx.status == 'completed'
                          ? Colors.green.shade700
                          : tx.status == 'failed'
                              ? Colors.red.shade700
                              : Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Bouton PDF reçu
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined, size: 20),
              color: Colors.grey.shade400,
              onPressed: onReceiptTap,
              tooltip: 'Reçu PDF',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(4),
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}
