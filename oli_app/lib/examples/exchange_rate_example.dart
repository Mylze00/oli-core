import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/exchange_rate_provider.dart';
import '../widgets/currency_selector_widget.dart';

/// Exemple d'utilisation du système de taux de change
/// 
/// Ce fichier montre comment intégrer le sélecteur de devise
/// et afficher les prix convertis dans votre application.
class ExchangeRateExample extends ConsumerWidget {
  const ExchangeRateExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exchangeState = ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exemple Taux de Change'),
        actions: [
          // Sélecteur de devise dans l'AppBar
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: const CurrencySelectorWidget(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations sur le taux actuel
            const ExchangeRateInfoWidget(),
            const SizedBox(height: 24),

            // Exemple 1: Afficher un prix de produit
            _buildSection(
              title: '1. Affichage d\'un prix de produit',
              child: _ProductPriceExample(
                productName: 'iPhone 15 Pro',
                usdPrice: 999.99,
                exchangeNotifier: exchangeNotifier,
              ),
            ),

            const SizedBox(height: 24),

            // Exemple 2: Conversion manuelle
            _buildSection(
              title: '2. Conversion manuelle',
              child: _ManualConversionExample(
                exchangeNotifier: exchangeNotifier,
              ),
            ),

            const SizedBox(height: 24),

            // Exemple 3: Liste de produits
            _buildSection(
              title: '3. Liste de produits avec conversion',
              child: _ProductListExample(
                exchangeNotifier: exchangeNotifier,
              ),
            ),

            const SizedBox(height: 24),

            // Bouton pour rafraîchir le taux
            Center(
              child: ElevatedButton.icon(
                onPressed: exchangeState.isLoading
                    ? null
                    : () => exchangeNotifier.fetchCurrentRate(),
                icon: const Icon(Icons.refresh),
                label: const Text('Rafraîchir le taux'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

/// Exemple d'affichage d'un prix de produit
class _ProductPriceExample extends StatelessWidget {
  final String productName;
  final double usdPrice;
  final ExchangeRateNotifier exchangeNotifier;

  const _ProductPriceExample({
    required this.productName,
    required this.usdPrice,
    required this.exchangeNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.phone_iphone, size: 40),
        title: Text(productName),
        subtitle: Text('Prix: ${exchangeNotifier.formatProductPrice(usdPrice)}'),
        trailing: Chip(
          label: Text(exchangeNotifier.state.selectedCurrency.code),
        ),
      ),
    );
  }
}

/// Exemple de conversion manuelle
class _ManualConversionExample extends StatefulWidget {
  final ExchangeRateNotifier exchangeNotifier;

  const _ManualConversionExample({required this.exchangeNotifier});

  @override
  State<_ManualConversionExample> createState() => _ManualConversionExampleState();
}

class _ManualConversionExampleState extends State<_ManualConversionExample> {
  final TextEditingController _controller = TextEditingController(text: '100');
  double _amount = 100.0;

  @override
  Widget build(BuildContext context) {
    final converted = widget.exchangeNotifier.convertAmount(_amount, from: Currency.USD);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant en USD',
                prefixText: '\$ ',
              ),
              onChanged: (value) {
                setState(() {
                  _amount = double.tryParse(value) ?? 0;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Converti: ${widget.exchangeNotifier.formatAmount(converted)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Exemple de liste de produits
class _ProductListExample extends StatelessWidget {
  final ExchangeRateNotifier exchangeNotifier;

  const _ProductListExample({required this.exchangeNotifier});

  final List<Map<String, dynamic>> _products = const [
    {'name': 'MacBook Pro', 'price': 2499.00},
    {'name': 'iPad Air', 'price': 599.00},
    {'name': 'AirPods Pro', 'price': 249.00},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _products.map((product) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(product['name']),
            trailing: Text(
              exchangeNotifier.formatProductPrice(product['price']),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
