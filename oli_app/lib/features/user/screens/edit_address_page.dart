import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/address_model.dart';
import '../providers/address_provider.dart';

class EditAddressPage extends ConsumerStatefulWidget {
  final Address? addressToEdit; // If null, creating new

  const EditAddressPage({super.key, this.addressToEdit});

  @override
  ConsumerState<EditAddressPage> createState() => _EditAddressPageState();
}

class _EditAddressPageState extends ConsumerState<EditAddressPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _labelCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _phoneCtrl;
  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final addr = widget.addressToEdit;
    _labelCtrl = TextEditingController(text: addr?.label ?? "Domicile");
    _addressCtrl = TextEditingController(text: addr?.address ?? "");
    _cityCtrl = TextEditingController(text: addr?.city ?? "");
    _phoneCtrl = TextEditingController(text: addr?.phone ?? ""); // Default to user phone if needed via auth provider
    _isDefault = addr?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newAddress = Address(
        id: widget.addressToEdit?.id ?? 0, // ID ignored on create
        userId: 0, // Ignored
        label: _labelCtrl.text,
        address: _addressCtrl.text,
        city: _cityCtrl.text,
        phone: _phoneCtrl.text,
        isDefault: _isDefault,
      );

      final notifier = ref.read(addressProvider.notifier);
      
      if (widget.addressToEdit == null) {
        await notifier.addAddress(newAddress);
      } else {
        await notifier.updateAddress(newAddress.id, newAddress);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const oliBlue = Color(0xFF1E7DBA);
    final isEditing = widget.addressToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Modifier l'adresse" : "Nouvelle adresse"),
        backgroundColor: oliBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _labelCtrl,
                decoration: const InputDecoration(labelText: "Libellé (ex: Maison)"),
                validator: (v) => v!.isEmpty ? "Requis" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: "Adresse complète (Rue, N°...)"),
                maxLines: 2,
                validator: (v) => v!.isEmpty ? "Requis" : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(labelText: "Ville"),
                      validator: (v) => v!.isEmpty ? "Requis" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: "Téléphone contact"),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v!.isEmpty ? "Requis" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text("Définir comme adresse par défaut"),
                value: _isDefault,
                activeColor: oliBlue,
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: oliBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : Text(isEditing ? "Mettre à jour" : "Ajouter", style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
