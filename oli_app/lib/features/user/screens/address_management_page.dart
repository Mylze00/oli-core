import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/address_provider.dart';
import '../models/address_model.dart';
import '../../auth/providers/auth_controller.dart';

class AddressManagementPage extends ConsumerStatefulWidget {
  const AddressManagementPage({super.key});

  @override
  ConsumerState<AddressManagementPage> createState() => _AddressManagementPageState();
}

class _AddressManagementPageState extends ConsumerState<AddressManagementPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(addressProvider.notifier).loadAddresses());
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Mes Adresses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2196F3)),
            onPressed: () => _showAddressForm(context),
          ),
        ],
      ),
      body: addresses.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2196F3))),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Erreur: $e', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(addressProvider.notifier).loadAddresses(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) => _buildAddressCard(list[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddressForm(context),
        backgroundColor: const Color(0xFF2196F3),
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'Aucune adresse enregistrée',
            style: TextStyle(fontSize: 18, color: Colors.grey[400], fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez une adresse pour faciliter\nvos livraisons',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddressForm(context),
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Ajouter une adresse'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(Address address) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: address.isDefault
            ? Border.all(color: const Color(0xFF2196F3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: label + default badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getLabelColor(address.label).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getLabelIcon(address.label), size: 14, color: _getLabelColor(address.label)),
                      const SizedBox(width: 4),
                      Text(
                        address.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _getLabelColor(address.label),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '✓ Par défaut',
                      style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[500], size: 20),
                  color: const Color(0xFF2A2A2A),
                  onSelected: (value) => _handleMenuAction(value, address),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Modifier', style: TextStyle(color: Colors.white)),
                      ],
                    )),
                    if (!address.isDefault)
                      const PopupMenuItem(value: 'default', child: Row(
                        children: [
                          Icon(Icons.star, size: 18, color: Colors.amber),
                          SizedBox(width: 8),
                          Text('Par défaut', style: TextStyle(color: Colors.white)),
                        ],
                      )),
                    const PopupMenuItem(value: 'delete', child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: Colors.red)),
                      ],
                    )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Address details
            if (address.avenue != null && address.avenue!.isNotEmpty)
              _buildDetailRow(Icons.route, 
                '${address.avenue}${address.numero != null && address.numero!.isNotEmpty ? " N°${address.numero}" : ""}'),
            if (address.quartier != null && address.quartier!.isNotEmpty)
              _buildDetailRow(Icons.location_city, 'Q/ ${address.quartier}'),
            if (address.commune != null && address.commune!.isNotEmpty)
              _buildDetailRow(Icons.map_outlined, 'C/ ${address.commune}'),
            if (address.ville != null && address.ville!.isNotEmpty)
              _buildDetailRow(Icons.location_on, address.ville!),
            if (address.referencePoint != null && address.referencePoint!.isNotEmpty)
              _buildDetailRow(Icons.flag_outlined, address.referencePoint!, isReference: true),
            if (address.phone.isNotEmpty)
              _buildDetailRow(Icons.phone, address.phone),
            // GPS indicator
            if (address.hasCoordinates)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.gps_fixed, size: 14, color: Colors.green[400]),
                    const SizedBox(width: 4),
                    Text(
                      'Coordonnées GPS enregistrées',
                      style: TextStyle(fontSize: 11, color: Colors.green[400]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, {bool isReference = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isReference ? Colors.amber[600] : Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isReference ? Colors.grey[300] : Colors.white,
                fontStyle: isReference ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, Address address) async {
    switch (action) {
      case 'edit':
        _showAddressForm(context, existing: address);
        break;
      case 'default':
        try {
          await ref.read(addressProvider.notifier).setDefaultAddress(address.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Adresse par défaut mise à jour')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
            );
          }
        }
        break;
      case 'delete':
        _confirmDelete(address);
        break;
    }
  }

  void _confirmDelete(Address address) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Supprimer cette adresse ?', style: TextStyle(color: Colors.white)),
        content: Text(
          'L\'adresse "${address.label}" sera définitivement supprimée.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(addressProvider.notifier).deleteAddress(address.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Adresse supprimée')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddressForm(BuildContext context, {Address? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddressFormSheet(
        existing: existing,
        onSave: (address) async {
          try {
            if (existing != null) {
              await ref.read(addressProvider.notifier).updateAddress(existing.id, address);
            } else {
              await ref.read(addressProvider.notifier).addAddress(address);
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(existing != null ? 'Adresse modifiée' : 'Adresse ajoutée')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  Color _getLabelColor(String label) {
    switch (label.toLowerCase()) {
      case 'maison': return Colors.blue;
      case 'bureau': return Colors.orange;
      case 'boutique': return Colors.purple;
      default: return Colors.teal;
    }
  }

  IconData _getLabelIcon(String label) {
    switch (label.toLowerCase()) {
      case 'maison': return Icons.home;
      case 'bureau': return Icons.work;
      case 'boutique': return Icons.store;
      default: return Icons.location_on;
    }
  }
}

// ---------------------------------------------------------------
// Bottom Sheet Form for Add/Edit
// ---------------------------------------------------------------
class _AddressFormSheet extends StatefulWidget {
  final Address? existing;
  final Function(Address) onSave;

  const _AddressFormSheet({this.existing, required this.onSave});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late String _label;
  late TextEditingController _avenueCtrl;
  late TextEditingController _numeroCtrl;
  late TextEditingController _quartierCtrl;
  late TextEditingController _communeCtrl;
  late TextEditingController _villeCtrl;
  late TextEditingController _referenceCtrl;
  bool _isDefault = false;
  bool _isSaving = false;

  final _labels = ['Maison', 'Bureau', 'Boutique', 'Autre'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = e?.label ?? 'Maison';
    _avenueCtrl = TextEditingController(text: e?.avenue ?? '');
    _numeroCtrl = TextEditingController(text: e?.numero ?? '');
    _quartierCtrl = TextEditingController(text: e?.quartier ?? '');
    _communeCtrl = TextEditingController(text: e?.commune ?? '');
    _villeCtrl = TextEditingController(text: e?.ville ?? 'Kinshasa');
    _referenceCtrl = TextEditingController(text: e?.referencePoint ?? '');
    _isDefault = e?.isDefault ?? false;
  }

  @override
  void dispose() {
    _avenueCtrl.dispose();
    _numeroCtrl.dispose();
    _quartierCtrl.dispose();
    _communeCtrl.dispose();
    _villeCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF2196F3)),
                const SizedBox(width: 8),
                Text(
                  widget.existing != null ? 'Modifier l\'adresse' : 'Nouvelle adresse',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF333333), height: 1),
          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label chips
                    const Text('Type d\'adresse', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _labels.map((l) => ChoiceChip(
                        label: Text(l),
                        selected: _label == l,
                        onSelected: (sel) => setState(() => _label = l),
                        selectedColor: const Color(0xFF2196F3),
                        labelStyle: TextStyle(color: _label == l ? Colors.white : Colors.grey[400]),
                        backgroundColor: const Color(0xFF2A2A2A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Avenue + Numéro on same row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildField('Avenue / Rue', _avenueCtrl, icon: Icons.route, required: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: _buildField('N°', _numeroCtrl, icon: Icons.tag),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildField('Quartier', _quartierCtrl, icon: Icons.location_city, required: true),
                    const SizedBox(height: 12),
                    _buildField('Commune', _communeCtrl, icon: Icons.map_outlined, required: true),
                    const SizedBox(height: 12),
                    _buildField('Ville', _villeCtrl, icon: Icons.location_on),
                    const SizedBox(height: 12),
                    _buildField('Point de repère', _referenceCtrl, icon: Icons.flag_outlined, hint: 'Ex: En face de l\'église...'),
                    const SizedBox(height: 16),
                    // Default toggle
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Adresse par défaut', style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text('Utilisée automatiquement au checkout', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      value: _isDefault,
                      onChanged: (val) => setState(() => _isDefault = val),
                      activeColor: const Color(0xFF2196F3),
                    ),
                    const SizedBox(height: 20),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveAddress,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                widget.existing != null ? 'Enregistrer les modifications' : 'Ajouter l\'adresse',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {
    IconData? icon, bool required = false, String? hint, TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[700], fontSize: 13),
        labelStyle: TextStyle(color: Colors.grey[500]),
        prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.grey[600]) : null,
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: required ? (val) {
        if (val == null || val.trim().isEmpty) return 'Ce champ est requis';
        return null;
      } : null,
    );
  }

  void _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final address = Address(
      label: _label,
      avenue: _avenueCtrl.text.trim(),
      numero: _numeroCtrl.text.trim(),
      quartier: _quartierCtrl.text.trim(),
      commune: _communeCtrl.text.trim(),
      ville: _villeCtrl.text.trim().isEmpty ? 'Kinshasa' : _villeCtrl.text.trim(),
      referencePoint: _referenceCtrl.text.trim(),
      isDefault: _isDefault,
    );

    await widget.onSave(address);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }
}
