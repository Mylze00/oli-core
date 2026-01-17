import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_controller.dart';

class EditNameDialog extends ConsumerStatefulWidget {
  final String currentName;

  const EditNameDialog({
    super.key,
    required this.currentName,
  });

  @override
  ConsumerState<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends ConsumerState<EditNameDialog> {
  late TextEditingController _nameController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _validateAndSave() {
    final newName = _nameController.text.trim();

    if (newName.isEmpty) {
      setState(() => _errorMessage = 'Le nom ne peut pas être vide');
      return;
    }

    if (newName.length < 2) {
      setState(() => _errorMessage = 'Le nom doit contenir au moins 2 caractères');
      return;
    }

    if (newName.length > 100) {
      setState(() => _errorMessage = 'Le nom ne peut pas dépasser 100 caractères');
      return;
    }

    if (newName == widget.currentName) {
      Navigator.pop(context);
      return;
    }

    // Save the new name
    _saveName(newName);
  }

  Future<void> _saveName(String newName) async {
    await ref.read(profileControllerProvider.notifier).updateUserName(newName);

    if (mounted) {
      final state = ref.read(profileControllerProvider);
      
      state.when(
        data: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nom mis à jour avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        },
        loading: () {},
        error: (error, _) {
          setState(() => _errorMessage = error.toString().replaceAll('Exception: ', ''));
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final isLoading = profileState.isLoading;

    return AlertDialog(
      title: const Text('Modifier votre nom'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            enabled: !isLoading,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nom',
              hintText: 'Entrez votre nom',
              errorText: _errorMessage,
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) {
              if (_errorMessage != null) {
                setState(() => _errorMessage = null);
              }
            },
            onSubmitted: (_) => !isLoading ? _validateAndSave() : null,
          ),
          const SizedBox(height: 8),
          Text(
            'Entre 2 et 100 caractères',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _validateAndSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E7DBA),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Sauvegarder'),
        ),
      ],
    );
  }
}
