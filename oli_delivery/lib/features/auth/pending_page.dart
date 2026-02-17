import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/api_config.dart';
import '../../core/providers/dio_provider.dart';
import 'providers/auth_controller.dart';

class PendingPage extends ConsumerStatefulWidget {
  const PendingPage({super.key});

  @override
  ConsumerState<PendingPage> createState() => _PendingPageState();
}

class _PendingPageState extends ConsumerState<PendingPage> {
  String _status = 'pending';
  String? _adminNote;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(ApiConfig.deliveryApplyStatus);

      if (mounted) {
        final data = response.data;
        setState(() {
          _status = data['status'] ?? 'pending';
          _adminNote = data['admin_note'];
          _isLoading = false;
        });

        // Si approuvé, re-check session et rediriger
        if (_status == 'approved') {
          await ref.read(authControllerProvider.notifier).checkSession();
          final authState = ref.read(authControllerProvider);
          if (authState.userData?['is_deliverer'] == true && mounted) {
            context.go('/');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur vérification statut: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _isLoading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Status icon
                      _buildStatusIcon(),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        _getTitle(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Text(
                        _getDescription(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),

                      // Admin note
                      if (_adminNote != null && _adminNote!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withOpacity(0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Note admin: $_adminNote',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Actions
                      if (_status == 'pending') ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _checkStatus,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Vérifier le statut',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E7DBA),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],

                      if (_status == 'rejected') ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () => context.go('/apply'),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Postuler à nouveau',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E7DBA),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],

                      if (_status == 'approved') ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () => context.go('/'),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Accéder au Dashboard',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () async {
                          await ref.read(authControllerProvider.notifier).logout();
                          if (mounted) context.go('/login');
                        },
                        child: const Text('Se déconnecter',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (_status) {
      case 'approved':
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        );
      case 'rejected':
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cancel, color: Colors.red, size: 60),
        );
      default:
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.hourglass_top, color: Colors.orange, size: 60),
        );
    }
  }

  String _getTitle() {
    switch (_status) {
      case 'approved':
        return '🎉 Candidature approuvée !';
      case 'rejected':
        return 'Candidature refusée';
      default:
        return 'Candidature en attente';
    }
  }

  String _getDescription() {
    switch (_status) {
      case 'approved':
        return 'Félicitations ! Votre candidature a été approuvée. Vous pouvez maintenant accéder au dashboard et commencer à livrer.';
      case 'rejected':
        return 'Votre candidature n\'a pas été retenue pour le moment. Vous pouvez soumettre une nouvelle candidature.';
      default:
        return 'Votre candidature est en cours d\'examen par notre équipe. Vous recevrez une notification une fois qu\'elle sera traitée.';
    }
  }
}
