import 'package:flutter/material.dart';

/// Barre de progression horizontale compacte pour les commandes.
/// Affiche 4 étapes : Commandée → Préparation → En route → Livrée
/// avec des cercles colorés, icônes et lignes de connexion.
class OrderProgressBar extends StatelessWidget {
  final String status;

  const OrderProgressBar({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return _buildCancelledBar();
    }
    if (status == 'pending') {
      return _buildPendingBar();
    }

    final currentStep = _statusToStep(status);
    final steps = [
      _StepData(icon: Icons.assignment_outlined, label: 'Commandée'),
      _StepData(icon: Icons.inventory_2_outlined, label: 'Préparation'),
      _StepData(icon: Icons.local_shipping_outlined, label: 'En route'),
      _StepData(icon: Icons.home_outlined, label: 'Livrée'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isEven) {
            // Step circle
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentStep;
            final isCurrent = stepIndex == currentStep;
            return _buildStep(
              steps[stepIndex],
              isCompleted: isCompleted,
              isCurrent: isCurrent,
            );
          } else {
            // Connector line
            final beforeStep = index ~/ 2;
            final isCompleted = beforeStep < currentStep;
            return _buildConnector(isCompleted: isCompleted);
          }
        }),
      ),
    );
  }

  int _statusToStep(String status) {
    switch (status) {
      case 'paid':
        return 0;
      case 'processing':
      case 'ready':       // legacy: traiter comme processing
        return 1;
      case 'shipped':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }

  Widget _buildStep(_StepData step,
      {required bool isCompleted, required bool isCurrent}) {
    final Color circleColor = isCurrent
        ? const Color(0xFF1E7DBA)
        : isCompleted
            ? const Color(0xFF4CAF50)
            : Colors.grey.shade700;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isCompleted || isCurrent)
                  ? circleColor
                  : Colors.transparent,
              border: Border.all(
                color: circleColor,
                width: isCurrent ? 2.5 : 2,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1E7DBA).withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              step.icon,
              size: 16,
              color: (isCompleted || isCurrent)
                  ? Colors.white
                  : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: (isCompleted || isCurrent)
                  ? (isCurrent ? const Color(0xFF1E7DBA) : Colors.green)
                  : Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildConnector({required bool isCompleted}) {
    return SizedBox(
      width: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 2.5,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFF4CAF50)
                  : Colors.grey.shade700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cancel_outlined, size: 16, color: Colors.red.shade400),
          const SizedBox(width: 6),
          Text(
            'Commande annulée',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_top, size: 16, color: Colors.orange.shade400),
          const SizedBox(width: 6),
          Text(
            'En attente de paiement',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepData {
  final IconData icon;
  final String label;
  const _StepData({required this.icon, required this.label});
}
