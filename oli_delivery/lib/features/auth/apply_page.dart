import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/api_config.dart';
import '../../core/providers/dio_provider.dart';

class ApplyPage extends ConsumerStatefulWidget {
  const ApplyPage({super.key});

  @override
  ConsumerState<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends ConsumerState<ApplyPage> {
  final _pledgeController = TextEditingController();
  final _motivationController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pledgeController.dispose();
    _motivationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pledgeStr = _pledgeController.text.trim();
    final pledge = double.tryParse(pledgeStr) ?? 0;

    if (pledge <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un montant de gage valide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(ApiConfig.deliveryApply, data: {
        'pledge_amount': pledge,
        'motivation': _motivationController.text.trim(),
      });

      if (mounted) {
        if (response.statusCode == 201 || response.statusCode == 200) {
          context.go('/pending');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E7DBA).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.delivery_dining,
                        size: 56,
                        color: Color(0xFF1E7DBA),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Devenir Livreur Oli',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E7DBA),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rejoignez notre équipe de livreurs et commencez à gagner dès aujourd\'hui',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Avantages
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.stars, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Avantages',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildAdvantage('Gagnez des commissions sur chaque livraison'),
                    _buildAdvantage('Horaires flexibles — travaillez quand vous voulez'),
                    _buildAdvantage('Wallet intégré avec retrait Mobile Money'),
                    _buildAdvantage('Notifications en temps réel pour les commandes'),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Montant de gage
              const Text(
                'Montant de gage (USD)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Ce montant sert de garantie. Choisissez librement le montant selon votre volonté.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pledgeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: InputDecoration(
                  hintText: 'Ex: 5.00',
                  prefixIcon: const Icon(Icons.attach_money),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF1E7DBA), width: 2),
                  ),
                ),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              // Motivation (optional)
              const Text(
                'Motivation (optionnel)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _motivationController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Pourquoi souhaitez-vous devenir livreur ?',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF1E7DBA), width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting ? 'Envoi en cours...' : 'Soumettre ma candidature',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E7DBA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Logout
              Center(
                child: TextButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Retour'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvantage(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
