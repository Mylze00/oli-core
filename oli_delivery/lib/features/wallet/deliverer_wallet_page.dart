import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/api_config.dart';
import '../../core/providers/dio_provider.dart';

class DelivererWalletPage extends ConsumerStatefulWidget {
  const DelivererWalletPage({super.key});

  @override
  ConsumerState<DelivererWalletPage> createState() => _DelivererWalletPageState();
}

class _DelivererWalletPageState extends ConsumerState<DelivererWalletPage> {
  double _balance = 0;
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final results = await Future.wait([
        dio.get(ApiConfig.walletBalance),
        dio.get(ApiConfig.walletTransactions),
      ]);

      if (mounted) {
        setState(() {
          _balance = (results[0].data['balance'] is num)
              ? results[0].data['balance'].toDouble()
              : double.tryParse('${results[0].data['balance']}') ?? 0;
          _transactions = results[1].data is List ? results[1].data : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur wallet: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatFC(double usd) {
    final fc = (usd * 2800).round();
    final formatted = fc.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
    return '$formatted FC';
  }

  void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+243');
    String provider = 'Airtel';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Retirer des fonds',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Solde disponible: ${_formatFC(_balance)}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Montant (USD)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: provider,
                decoration: InputDecoration(
                  labelText: 'Opérateur',
                  prefixIcon: const Icon(Icons.phone_android),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'Airtel', child: Text('Airtel Money')),
                  DropdownMenuItem(value: 'Vodacom', child: Text('M-Pesa (Vodacom)')),
                  DropdownMenuItem(value: 'Orange', child: Text('Orange Money')),
                ],
                onChanged: (v) => setModalState(() => provider = v!),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro Mobile Money',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await _withdraw(amount, provider, phoneCtrl.text);
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Retirer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E7DBA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _withdraw(double amount, String provider, String phone) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(ApiConfig.walletWithdraw, data: {
        'amount': amount,
        'provider': provider,
        'phoneNumber': phone,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Retrait effectué avec succès'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // ─── Balance Card ────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E7DBA), Color(0xFF0D5A8C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E7DBA).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Wallet Livreur',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _formatFC(_balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '≈ \$${_balance.toStringAsFixed(2)} USD',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showWithdrawDialog,
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          label: const Text('Retirer', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1E7DBA),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Transactions ────────────────────────
                const Text(
                  'Historique des gains',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (_transactions.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune transaction',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vos gains apparaîtront ici après vos livraisons',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._transactions.map<Widget>((tx) {
                    final type = tx['type'] ?? '';
                    final isCredit = type == 'deposit' || type == 'credit';
                    final amount = (tx['amount'] is num) ? tx['amount'].toDouble() : 0.0;
                    final description = tx['description'] ?? '';
                    final createdAt = tx['created_at'] ?? '';

                    String dateStr = '';
                    try {
                      final dt = DateTime.parse(createdAt);
                      dateStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                    } catch (_) {}

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCredit
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          child: Icon(
                            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isCredit ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          description,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          dateStr,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        trailing: Text(
                          '${isCredit ? '+' : '-'}\$${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isCredit ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
