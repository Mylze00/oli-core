import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shop_provider.dart';
import '../models/shop_model.dart';
import 'create_shop_screen.dart';

class MyShopsScreen extends ConsumerWidget {
  const MyShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myShopsAsync = ref.watch(myShopsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Boutiques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const CreateShopScreen())
              );
            },
          )
        ],
      ),
      body: myShopsAsync.when(
        data: (shops) {
          if (shops.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.store, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("Vous n'avez pas encore de boutique"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => const CreateShopScreen())
                      );
                    },
                    child: const Text("Créer ma boutique"),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final shop = shops[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: shop.logoUrl != null 
                    ? CircleAvatar(backgroundImage: NetworkImage(shop.logoUrl!))
                    : const CircleAvatar(child: Icon(Icons.store)),
                  title: Text(shop.name),
                  subtitle: Text(shop.category),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to shop details / edit
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
    );
  }
}
