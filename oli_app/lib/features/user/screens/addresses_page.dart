import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/address_model.dart';
import '../providers/address_provider.dart';
import 'edit_address_page.dart';

class AddressesPage extends ConsumerStatefulWidget {
  const AddressesPage({super.key});

  @override
  ConsumerState<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends ConsumerState<AddressesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(addressProvider.notifier).loadAddresses());
  }

  @override
  Widget build(BuildContext context) {
    final addressesState = ref.watch(addressProvider);
    const oliBlue = Color(0xFF1E7DBA);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Adresses"),
        backgroundColor: oliBlue,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: oliBlue,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const EditAddressPage()));
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: addressesState.when(
        data: (addresses) {
          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("Aucune adresse enregistrée", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.read(addressProvider.notifier).loadAddresses(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                final address = addresses[index];
                return _AddressCard(address: address);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Erreur: ${err.toString()}")),
      ),
    );
  }
}

class _AddressCard extends ConsumerWidget {
  final Address address;
  const _AddressCard({required this.address});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: address.isDefault ? const BorderSide(color: Color(0xFF1E7DBA), width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: const Color(0xFF1E7DBA), size: 20),
                const SizedBox(width: 8),
                Text(
                  address.label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (address.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E7DBA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text("Par défaut", style: TextStyle(color: Color(0xFF1E7DBA), fontSize: 10)),
                  ),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => EditAddressPage(addressToEdit: address)));
                    } else if (value == 'delete') {
                      ref.read(addressProvider.notifier).deleteAddress(address.id);
                    } else if (value == 'default') {
                      ref.read(addressProvider.notifier).setDefaultAddress(address.id);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!address.isDefault)
                      const PopupMenuItem(value: 'default', child: Text("Définir par défaut")),
                    const PopupMenuItem(value: 'edit', child: Text("Modifier")),
                    const PopupMenuItem(value: 'delete', child: Text("Supprimer", style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            const Divider(),
            Text(address.address, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(address.city, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(address.phone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
