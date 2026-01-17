import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_controller.dart';
import '../providers/wallet_provider.dart';
import '../models/transaction_model.dart';
import '../widgets/payment_dialogs.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(walletProvider.notifier).loadWalletData());
  }

  void _showTransactionDialog(bool isDeposit) async {
    if (isDeposit) {
      // Show payment method selection first
      final paymentMethod = await showDialog<String>(
        context: context,
        builder: (_) => const PaymentMethodSelectionDialog(),
      );

      if (paymentMethod != null && mounted) {
        if (paymentMethod == 'mobile') {
          showDialog(
            context: context,
            builder: (_) => TransactionDialog(isDeposit: true),
          );
        } else {
          showDialog(
            context: context,
            builder: (_) => const CardPaymentDialog(),
          );
        }
      }
    } else {
      // For withdrawals, only mobile money
      showDialog(
        context: context,
        builder: (_) => TransactionDialog(isDeposit: false),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Wallet Oli'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(walletProvider.notifier).loadWalletData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // BALANCE CARD
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E3C72), Color(0xFF2A5298)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
                ),
                child: Column(
                  children: [
                    const Text('Solde Disponible', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      '${walletState.balance.toStringAsFixed(2)} \$',
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionButton(
                          icon: Icons.add, 
                          label: 'Dépôt', 
                          onTap: () => _showTransactionDialog(true)
                        ),
                        _ActionButton(
                          icon: Icons.arrow_upward, 
                          label: 'Retrait', 
                          onTap: () => _showTransactionDialog(false)
                        ),
                      ],
                    )
                  ],
                ),
              ),

              if (walletState.error != null)
                Padding(
                   padding: const EdgeInsets.all(8.0),
                   child: Text(walletState.error!, style: const TextStyle(color: Colors.red)),
                ),

              // TRANSACTIONS HEADER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Historique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Icon(Icons.history, color: Colors.grey[600]),
                  ],
                ),
              ),

              // LIST
              if (walletState.isLoading && walletState.transactions.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (walletState.transactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text("Aucune transaction récente", style: TextStyle(color: Colors.grey)),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: walletState.transactions.length,
                  itemBuilder: (context, index) {
                    final tx = walletState.transactions[index];
                    final isPositive = tx.type == 'deposit' || tx.type == 'refund';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isPositive ? Colors.green[100] : Colors.red[100],
                        child: Icon(
                          isPositive ? Icons.call_received : Icons.call_made, 
                          color: isPositive ? Colors.green : Colors.red
                        ),
                      ),
                      title: Text(tx.description),
                      subtitle: Text(tx.createdAt.toString().substring(0, 16)),
                      trailing: Text(
                        '${isPositive ? '+' : ''}${tx.amount.toStringAsFixed(2)} \$',
                        style: TextStyle(
                          color: isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white))
      ],
    );
  }
}

class TransactionDialog extends ConsumerStatefulWidget {
  final bool isDeposit;
  const TransactionDialog({super.key, required this.isDeposit});

  @override
  ConsumerState<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends ConsumerState<TransactionDialog> {
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _provider = 'orange'; // orange, mpesa, airtel
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill phone number from user profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authControllerProvider).userData;
      if (user != null && user['phone'] != null) {
        _phoneCtrl.text = user['phone'];
        // Tenter de deviner le provider (Sommaire)
        final phone = user['phone'] as String;
        if (phone.startsWith('07') || phone.startsWith('+2438')) { 
           // Logique simplifiée, à adapter selon pays
           // Orange souvent 085, 089, 084...
           // Vodacom 081, 082...
           // Airtel 099, 097...
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDeposit = widget.isDeposit;
    return AlertDialog(
      title: Text(isDeposit ? 'Dépôt Mobile Money' : 'Retrait vers Mobile Money'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Simulation Sandbox: Terminez le numéro par 99 pour 'Pending', 00 pour 'Fail', autre pour 'Success'."),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _provider,
              items: const [
                DropdownMenuItem(value: 'orange', child: Text('Orange Money')),
                DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                DropdownMenuItem(value: 'airtel', child: Text('Airtel Money')),
              ],
              onChanged: (v) => setState(() => _provider = v!),
              decoration: const InputDecoration(labelText: 'Opérateur'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Montant (USD)', suffixText: '\$'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Numéro de téléphone'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _isLoading ? null : () async {
            final amount = double.tryParse(_amountCtrl.text);
            final phone = _phoneCtrl.text;
            
            if (amount == null || phone.isEmpty) return;

            setState(() => _isLoading = true);

            final notifier = ref.read(walletProvider.notifier);
            final success = isDeposit 
                ? await notifier.deposit(amount: amount, provider: _provider, phone: phone)
                : await notifier.withdraw(amount: amount, provider: _provider, phone: phone);

            setState(() => _isLoading = false);

            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(success ? 'Opération réussie' : 'Échec opération')),
              );
            }
          },
          child: _isLoading ? const CircularProgressIndicator() : const Text('Valider'),
        ),
      ],
    );
  }
}
