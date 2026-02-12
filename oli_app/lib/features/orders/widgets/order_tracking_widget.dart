import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget timeline visuel pour le suivi de commande
/// Affiche les 5 étapes : Reçue → Préparation → Prête → Expédition → Livrée
class OrderTrackingWidget extends StatelessWidget {
  final Map<String, dynamic> tracking;

  const OrderTrackingWidget({super.key, required this.tracking});

  @override
  Widget build(BuildContext context) {
    final steps = (tracking['steps'] as List<dynamic>?) ?? [];
    final currentStatus = tracking['current_status'] ?? 'pending';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.timeline, color: Colors.blue, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Suivi de commande',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _buildStatusBadge(currentStatus),
            ],
          ),
          const SizedBox(height: 20),

          // Timeline
          ...List.generate(steps.length, (index) {
            final step = steps[index] as Map<String, dynamic>;
            final isCompleted = step['completed'] == true;
            final isCurrent = _isCurrentStep(steps, index);
            final isLast = index == steps.length - 1;

            return _buildTimelineStep(
              step: step,
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  bool _isCurrentStep(List<dynamic> steps, int index) {
    final step = steps[index] as Map<String, dynamic>;
    if (step['completed'] != true) return false;

    // C'est l'étape courante si c'est la dernière complétée
    if (index == steps.length - 1) return true;
    final nextStep = steps[index + 1] as Map<String, dynamic>;
    return nextStep['completed'] != true;
  }

  Widget _buildTimelineStep({
    required Map<String, dynamic> step,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    final Color activeColor = isCurrent ? Colors.blue : (isCompleted ? Colors.green : Colors.grey.shade700);
    final timestamp = step['timestamp'];
    final label = step['label'] ?? '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Dot
                Container(
                  width: isCurrent ? 20 : 16,
                  height: isCurrent ? 20 : 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? activeColor : Colors.transparent,
                    border: Border.all(
                      color: activeColor,
                      width: isCurrent ? 3 : 2,
                    ),
                    boxShadow: isCurrent
                        ? [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)]
                        : null,
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : null,
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted ? Colors.green.withOpacity(0.5) : Colors.grey.shade800,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isCompleted ? Colors.white : Colors.grey.shade500,
                      fontSize: 14,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                  if (isCurrent) ...[
                    const SizedBox(height: 4),
                    Text(
                      _getStepDescription(step['status']),
                      style: TextStyle(color: Colors.blue.shade300, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final config = _getStatusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config['color'].withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        config['label'],
        style: TextStyle(color: config['color'], fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'paid':
        return {'label': 'Confirmée', 'color': Colors.green};
      case 'processing':
        return {'label': 'En préparation', 'color': Colors.orange};
      case 'ready':
        return {'label': 'Prête', 'color': Colors.amber};
      case 'shipped':
        return {'label': 'En livraison', 'color': Colors.blue};
      case 'delivered':
        return {'label': 'Livrée', 'color': Colors.green};
      case 'cancelled':
        return {'label': 'Annulée', 'color': Colors.red};
      default:
        return {'label': 'En attente', 'color': Colors.grey};
    }
  }

  String _getStepDescription(String? status) {
    switch (status) {
      case 'paid':
        return 'Le vendeur va bientôt préparer votre commande';
      case 'processing':
        return 'Le vendeur prépare votre commande';
      case 'ready':
        return 'En attente du livreur pour récupérer le colis';
      case 'shipped':
        return 'Le livreur est en route vers vous';
      case 'delivered':
        return 'Commande livrée avec succès !';
      default:
        return '';
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      final dt = DateTime.parse(timestamp.toString()).toLocal();
      return DateFormat('dd/MM/yyyy à HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}
