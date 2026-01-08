import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

// --- MODELS & STATE (kept simple/simulated) ---

class Product {
  final String id, name, price, seller, condition, description, color, deliveryTime;
  final double deliveryPrice, rating;
  final int quantity, reviews;
  final List<File> images;
  final int totalBuyerRatings;
  
  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.seller,
    required this.condition,
    required this.description,
    required this.color,
    required this.deliveryPrice,
    required this.deliveryTime,
    required this.quantity,
    required this.rating,
    required this.reviews,
    required this.totalBuyerRatings,
    this.images = const [],
  });
}

class MarketNotifier extends StateNotifier<List<Product>> {
  MarketNotifier()
      : super([
          Product(
            id: '1',
            name: 'iPhone 15 Pro',
            price: '1200',
            seller: 'Jean Dupont',
            condition: 'Neuf',
            description: 'iPhone 15 Pro 256GB noir - Neuf avec emballage original et garantie 1 an.',
            color: 'Noir',
            deliveryPrice: 10,
            deliveryTime: '2-3 jours',
            quantity: 2,
            rating: 4.8,
            reviews: 45,
            totalBuyerRatings: 95,
            images: [],
          ),
          Product(
            id: '2',
            name: 'MacBook Air M2',
            price: '950',
            seller: 'Alice Shop',
            condition: 'Occasion',
            description: 'MacBook Air M2 2022 - 8GB RAM, 256GB SSD. En excellent état, quelques rayures légères.',
            color: 'Argent',
            deliveryPrice: 15,
            deliveryTime: '3-5 jours',
            quantity: 1,
            rating: 4.5,
            reviews: 28,
            totalBuyerRatings: 62,
            images: [],
          ),
        ]);
  void addProduct(Product p) => state = [p, ...state];
}
final marketProductsProvider = StateNotifierProvider<MarketNotifier, List<Product>>((ref) => MarketNotifier());

class ProductState {
  final bool isLoading;
  ProductState({this.isLoading = false});
}
class ProductController extends StateNotifier<ProductState> {
  ProductController() : super(ProductState());
  Future<bool> uploadProduct({required String name, required String price, required File imageFile}) async {
    state = ProductState(isLoading: true);
    await Future.delayed(const Duration(seconds: 2));
    state = ProductState(isLoading: false);
    return true;
  }
}
final productControllerProvider = StateNotifierProvider<ProductController, ProductState>((ref) => ProductController());

// --- THEME PROVIDER ---
class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier() : super(true); // true = dark mode, false = light mode
  void toggleTheme() => state = !state;
}
final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) => ThemeNotifier());

// --- APP ENTRY ---

void main() => runApp(const ProviderScope(child: MyApp()));

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDarkMode ? _darkTheme() : _lightTheme(),
      home: const HomePage(),
    );
  }
  
  ThemeData _darkTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF000000),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0A0A0A), elevation: 0),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: Color(0xFF0A0A0A)),
    );
  }
  
  ThemeData _lightTheme() {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, elevation: 0),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: Color(0xFFF5F5F5)),
      primaryColor: Colors.blueAccent,
    );
  }
}

// --- MAIN NAVIGATION ---

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  File? _profileImage;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      MainDashboardView(profileImage: _profileImage, onProfileImageChanged: (img) => setState(() => _profileImage = img)),
      const MessagingView(),
      const SizedBox(),
      const MarketView(),
      ProfileAndWalletPage(onImagePicked: (img) => setState(() => _profileImage = img)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0A0A0A),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex == 2 ? 0 : _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          if (i == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishArticlePage()));
          } else {
            setState(() => _currentIndex = i);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_outlined), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 28), label: '+'),
          BottomNavigationBarItem(icon: Icon(Icons.store_outlined), label: 'Marché'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Moi'),
        ],
      ),
    );
  }
}

// --- DASHBOARD ---

class MainDashboardView extends ConsumerStatefulWidget {
  final File? profileImage;
  final ValueChanged<File?>? onProfileImageChanged;

  const MainDashboardView({super.key, this.profileImage, this.onProfileImageChanged});

  @override
  ConsumerState<MainDashboardView> createState() => _MainDashboardViewState();
}

class _MainDashboardViewState extends ConsumerState<MainDashboardView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  widget.profileImage != null
                      ? CircleAvatar(radius: 22, backgroundImage: FileImage(widget.profileImage!), backgroundColor: Colors.blueAccent)
                      : const CircleAvatar(radius: 22, backgroundColor: Colors.blueAccent, child: Text("JD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: const [Text('Jean Dupont', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(width: 6), Icon(Icons.verified, color: Colors.blueAccent, size: 18)]),
                    const Text('Niveau Or • 1,250 pts', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsView()),
                      );
                    },
                    icon: const Icon(Icons.notifications, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1E7DBA), Color(0xFF9013FE)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Bonus de Fidélité", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const Text("Bon d'achat de 10\$ disponible.", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 15),
                ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blueAccent), child: const Text("Récompenses"))
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: _SectionHeader(title: 'Services & Paiements')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ActionButton(icon: Icons.account_balance_wallet, label: 'Payer', color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentView()))),
                  _ActionButton(icon: Icons.receipt_long, label: 'Factures', color: Colors.orange, onTap: () {}),
                  _ActionButton(icon: Icons.redeem, label: 'Cadeaux', color: Colors.pink, onTap: () {}),
                  _ActionButton(icon: Icons.settings_suggest, label: 'Services', color: Colors.blue, onTap: () {}),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _SearchField(
                onChanged: (v) => setState(() => _searchQuery = v),
                hintText: 'Rechercher produits, vendeurs...',
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          const SliverToBoxAdapter(child: _SectionHeader(title: 'Articles récents')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 180,
              child: Consumer(builder: (context, ref, _) {
                final products = ref.watch(marketProductsProvider);
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (c, i) {
                    final p = products[i];
                    return Container(
                      width: 117,
                      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        Expanded(child: Container(decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), image: p.images.isNotEmpty ? DecorationImage(image: FileImage(p.images[0]), fit: BoxFit.cover) : null), child: p.images.isEmpty ? const Icon(Icons.image, color: Colors.grey, size: 20) : null)),
                        Padding(padding: const EdgeInsets.all(6.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text('\$${p.price}', style: const TextStyle(color: Colors.blueAccent, fontSize: 10))])),
                      ]),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: products.length,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// --- MESSAGING (functional with chat view) ---

class MessagingView extends StatefulWidget {
  const MessagingView({super.key});
  @override
  State<MessagingView> createState() => _MessagingViewState();
}

class _MessagingViewState extends State<MessagingView> {
  String _query = '';
  final List<Map<String, String>> _convos = [
    {'name': 'Alice', 'status': 'Actif maintenant'},
    {'name': 'Bob', 'status': 'Vu il y a 2h'},
    {'name': 'Charlie', 'status': 'Vu il y a 30min'},
    {'name': 'Delivery Support', 'status': 'Support'},
    {'name': 'Vendeur X', 'status': 'Vu hier'},
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _convos
        : _convos.where((c) => c['name']!.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Messagerie'), backgroundColor: Colors.black, elevation: 0),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _SearchField(
            onChanged: (v) => setState(() => _query = v),
            hintText: 'Rechercher conversations...',
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Aucune conversation', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (c, i) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Text(
                        _convos[i]['name']![0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(filtered[i]['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    subtitle: Text(filtered[i]['status']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white30),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatView(contactName: filtered[i]['name']!),
                      ),
                    ),
                  ),
                  separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                  itemCount: filtered.length,
                ),
        )
      ]),
    );
  }
}

// --- CHAT VIEW (functional messaging) ---

class ChatView extends StatefulWidget {
  final String contactName;
  const ChatView({super.key, required this.contactName});
  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {'sender': 'other', 'text': 'Bonjour! Comment ça va?'},
    {'sender': 'me', 'text': 'Salut! Ça va bien, et toi?'},
    {'sender': 'other', 'text': 'Super! Intéressé par mon produit?'},
  ];

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    setState(() {
      _messages.add({'sender': 'me', 'text': _msgController.text});
      _msgController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(_contactName),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemBuilder: (c, i) {
              final msg = _messages[i];
              final isMe = msg['sender'] == 'me';
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blueAccent : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(msg['text'], style: const TextStyle(color: Colors.white)),
                ),
              );
            },
            itemCount: _messages.length,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF0A0A0A),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: _sendMessage,
              ),
            )
          ]),
        )
      ]),
    );
  }

  String get _contactName => widget.contactName;
}

// --- MARKET (responsive + search) ---

class MarketView extends ConsumerStatefulWidget {
  const MarketView({super.key});
  @override
  ConsumerState<MarketView> createState() => _MarketViewState();
}

class _MarketViewState extends ConsumerState<MarketView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(marketProductsProvider);
    final filtered = _query.isEmpty ? products : products.where((p) => p.name.toLowerCase().contains(_query.toLowerCase()) || p.seller.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Marché Public'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _SearchField(onChanged: (v) => setState(() => _query = v)),
          ),
        ),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        int crossAxis = 2;
        if (w > 1000) crossAxis = 4;
        else if (w > 700) crossAxis = 3;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxis, childAspectRatio: 0.72, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final p = filtered[index];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: p))),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(15)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                          image: p.images.isNotEmpty ? DecorationImage(image: FileImage(p.images[0]), fit: BoxFit.cover) : null,
                        ),
                        child: p.images.isEmpty ? const Center(child: Icon(Icons.image, color: Colors.grey)) : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('Vendu par: ${p.seller}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        const SizedBox(height: 4),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('\$${p.price}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            Row(children: [
                              const Icon(Icons.star, color: Colors.amber, size: 12),
                              Text(' ${p.rating} (${p.reviews})', style: const TextStyle(fontSize: 9, color: Colors.white70)),
                            ]),
                          ]),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(5)), child: Text(p.condition, style: const TextStyle(fontSize: 9, color: Colors.blueAccent)))
                        ]),
                      ]),
                    )
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}


// --- PRODUCT DETAILS PAGE ---

class ProductDetailsPage extends StatefulWidget {
  final Product product;
  const ProductDetailsPage({super.key, required this.product});
  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  int _currentImageIndex = 0;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0, title: const Text('Détails du produit'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        child: Column(children: [
          Stack(children: [
            Container(
              color: Colors.white,
              height: 400,
              width: double.infinity,
              child: p.images.isEmpty
                  ? const Center(child: Icon(Icons.image, size: 60, color: Colors.grey))
                  : PageView.builder(
                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                      itemCount: p.images.length,
                      itemBuilder: (c, i) => Image.file(p.images[i], fit: BoxFit.cover),
                    ),
            ),
            Positioned(
              top: 40, left: 16,
              child: CircleAvatar(backgroundColor: Colors.white.withOpacity(0.9), child: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18), onPressed: () => Navigator.pop(context))),
            ),
            Positioned(
              top: 40, right: 16,
              child: Row(children: [
                CircleAvatar(backgroundColor: Colors.white.withOpacity(0.9), child: const Icon(Icons.ios_share, color: Colors.black, size: 18)),
                const SizedBox(width: 10),
                CircleAvatar(backgroundColor: Colors.white.withOpacity(0.9), child: const Icon(Icons.shopping_cart_outlined, color: Colors.black, size: 18)),
              ]),
            ),
            if (p.images.length > 1)
              Positioned(
                bottom: 20, left: 0, right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(p.images.length, (i) => Container(width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(shape: BoxShape.circle, color: i == _currentImageIndex ? Colors.blueAccent : Colors.grey.withOpacity(0.5))))),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(p.name.toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          // BLOC VENDEUR
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Row(children: [
              Stack(
                children: [
                   CircleAvatar(radius: 25, backgroundColor: Colors.blueAccent, child: Text(p.seller[0], style: const TextStyle(color: Colors.white, fontSize: 20))),
                   Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Colors.blue, size: 16))),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.seller.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
                  Text('${p.totalBuyerRatings}% d\'évaluation positive', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.chat_bubble_outline, color: Colors.black, size: 30),
            ]),
          ),
          // BANNIÈRE PRIX
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: const Color(0xFF1E7DBA),
            child: Center(child: Text("${p.price}\$", style: const TextStyle(color: Colors.white, fontSize: 45, fontWeight: FontWeight.bold))),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${p.deliveryPrice}\$ de livraison", style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Text("Livraison estimée : ${p.deliveryTime}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const Divider(color: Colors.white24, height: 24),
              Text("Etat : ${p.condition}", style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 16),
              // BOUTONS D'ACTION
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E7DBA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), child: const Text("Achat immédiat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white70), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), child: const Text("Ajouter au panier", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white70), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), child: const Text("Suivre cet objet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
              ),
              const SizedBox(height: 20),
              GestureDetector(onTap: () {}, child: const Text("Afficher la description complète", style: TextStyle(color: Colors.white, decoration: TextDecoration.underline))),
              const SizedBox(height: 8),
              Text("Quantité Disponible : ${p.quantity}", style: const TextStyle(color: Colors.white70)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.white70)), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]);
  }
}

// --- PROFILE & WALLET (kept close to original, improved spacing) ---

class ProfileAndWalletPage extends StatefulWidget {
  final ValueChanged<File?>? onImagePicked;
  const ProfileAndWalletPage({super.key, this.onImagePicked});
  @override
  State<ProfileAndWalletPage> createState() => _ProfileAndWalletPageState();
}

class _ProfileAndWalletPageState extends State<ProfileAndWalletPage> {
  File? _image;
  String _deliveryAddress = '';

  Future<void> _updatePhoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _image = File(img.path));
      widget.onImagePicked?.call(_image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0, title: const Text('Mon profil')),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Center(
                child: Stack(children: [
                  CircleAvatar(radius: 48, backgroundColor: Colors.blueAccent, backgroundImage: _image != null ? FileImage(_image!) : null, child: _image == null ? const Icon(Icons.person, size: 40) : null),
                  Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: _updatePhoto, child: const CircleAvatar(radius: 15, backgroundColor: Colors.white, child: Icon(Icons.edit, size: 14, color: Colors.black)))),
                ]),
              ),
              const SizedBox(height: 12),
              const Text('Jean Dupont', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('+243 820 000 000', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: const [_Badge(label: 'Niveau Or', color: Colors.amber), SizedBox(width: 10), _Badge(label: 'Certifié', color: Colors.blue)]),
              const SizedBox(height: 20),
              // DELIVERY ADDRESS SECTION
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.location_on, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _deliveryAddress.isEmpty
                        ? GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (c) => _DeliveryAddressDialog(
                                  onSave: (addr) => setState(() => _deliveryAddress = addr),
                                ),
                              );
                            },
                            child: const Text('Ajouter adresse de livraison', style: TextStyle(color: Colors.blueAccent, fontStyle: FontStyle.italic)),
                          )
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Adresse de livraison', style: TextStyle(color: Colors.white70, fontSize: 10)),
                            const SizedBox(height: 4),
                            Text(_deliveryAddress, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ]),
                  ),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (c) => _DeliveryAddressDialog(
                          initialAddress: _deliveryAddress,
                          onSave: (addr) => setState(() => _deliveryAddress = addr),
                        ),
                      );
                    },
                    child: Icon(Icons.edit, color: Colors.blueAccent, size: 18),
                  )
                ]),
              ),
              const SizedBox(height: 20),
              Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1976D2)]), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('SOLDE TOTAL', style: TextStyle(color: Colors.white70)), SizedBox(height: 8), Text('\$2,450.50', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold))])),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final isDarkMode = ref.watch(themeProvider);
                  return _ProfileTile(
                    icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    title: isDarkMode ? 'Mode Sombre' : 'Mode Clair',
                    onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                  );
                },
              ),
              _ProfileTile(icon: Icons.settings, title: 'Paramètres', onTap: () {}),
              _ProfileTile(icon: Icons.history, title: 'Mes Achats', onTap: () {}),
              _ProfileTile(icon: Icons.help_outline, title: 'Aide', onTap: () {}),
              _ProfileTile(icon: Icons.logout, title: 'Déconnexion', color: Colors.redAccent, onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Center(child: Text('Page Login'))))),
            ]),
          ),
        )
      ]),
    );
  }
}

// --- REUSABLE WIDGETS ---

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.5))), child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)));
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Column(children: [CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)), const SizedBox(height: 5), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))]));
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;
  const _ProfileTile({required this.icon, required this.title, required this.onTap, this.color = Colors.white});
  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon, color: color), title: Text(title, style: TextStyle(color: color)), trailing: const Icon(Icons.chevron_right, size: 18), onTap: onTap);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(16), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)));
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  const _SearchField({required this.onChanged, this.hintText = 'Rechercher...'});
  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white12,
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

// --- PAYMENT VIEW (unchanged) ---

class PaymentView extends StatefulWidget {
  const PaymentView({super.key});
  @override
  State<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<PaymentView> {
  String _provider = 'M-PESA';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Recharger"), backgroundColor: Colors.black),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Montant (\$)", filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 20),
          DropdownButton<String>(value: _provider, isExpanded: true, dropdownColor: Colors.grey[900], items: ['M-PESA', 'ORANGE', 'AIRTEL'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _provider = v!)),
          const Spacer(),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), onPressed: () => Navigator.pop(context), child: const Text("CONFIRMER"))),
        ]),
      ),
    );
  }
}

// --- PUBLISH ARTICLE (improved form + validation + feedback) ---

class PublishArticlePage extends ConsumerStatefulWidget {
  const PublishArticlePage({super.key});
  @override
  ConsumerState<PublishArticlePage> createState() => _PublishArticlePageState();
}

class _PublishArticlePageState extends ConsumerState<PublishArticlePage> {
  List<File> _images = [];
  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _deliveryPrice = TextEditingController();
  final TextEditingController _deliveryTime = TextEditingController();
  final TextEditingController _color = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _quantity = TextEditingController();
  String _condition = 'Neuf';
  final _formKey = GlobalKey<FormState>();

  Future<void> _pickImages() async {
    final imgs = await ImagePicker().pickMultiImage();
    if (imgs.isNotEmpty && _images.length < 8) {
      setState(() {
        _images.addAll(imgs.take(8 - _images.length).map((img) => File(img.path)));
      });
    }
  }

  void _removeImage(int idx) => setState(() => _images.removeAt(idx));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productControllerProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Vendre un article"), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(children: [
            const Text('Photos (1-8)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _images.isEmpty
                ? GestureDetector(
                    onTap: _pickImages,
                    child: Container(height: 150, width: double.infinity, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blueAccent)), child: const Center(child: Icon(Icons.add_a_photo, size: 40, color: Colors.blueAccent))),
                  )
                : Column(
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
                        itemCount: _images.length + (_images.length < 8 ? 1 : 0),
                        itemBuilder: (c, i) {
                          if (i == _images.length) {
                            return GestureDetector(
                              onTap: _pickImages,
                              child: Container(decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blueAccent)), child: const Icon(Icons.add, color: Colors.blueAccent)),
                            );
                          }
                          return Stack(
                            children: [
                              Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: FileImage(_images[i]), fit: BoxFit.cover))),
                              Positioned(
                                top: 0, right: 0,
                                child: GestureDetector(
                                  onTap: () => _removeImage(i),
                                  child: Container(decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.close, size: 14, color: Colors.white)),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
            const SizedBox(height: 20),
            TextFormField(controller: _name, validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nom du produit", filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextFormField(controller: _price, keyboardType: TextInputType.number, validator: (v) => v == null || v.trim().isEmpty ? 'Prix requis' : null, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Prix (\$)", filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextFormField(controller: _deliveryPrice, keyboardType: TextInputType.number, validator: (v) => v == null || v.trim().isEmpty ? 'Coût de livraison requis' : null, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Coût de livraison (\$)", filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextFormField(controller: _deliveryTime, validator: (v) => v == null || v.trim().isEmpty ? 'Temps requis' : null, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Temps de livraison (ex: 2-3 jours)", filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextFormField(controller: _color, validator: (v) => v == null || v.trim().isEmpty ? 'Couleur requise' : null, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Couleur", filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _condition,
              dropdownColor: Colors.grey[900],
              decoration: const InputDecoration(labelText: "État du produit", filled: true, fillColor: Colors.white10, border: OutlineInputBorder()),
              items: ['Neuf', 'Bon état', 'État acceptable', 'À restaurer'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _condition = v!),
            ),
            const SizedBox(height: 15),
            TextFormField(controller: _quantity, keyboardType: TextInputType.number, validator: (v) => v == null || v.trim().isEmpty ? 'Quantité requise' : null, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Quantité disponible", filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextFormField(
              controller: _description,
              maxLines: 4,
              validator: (v) => v == null || v.trim().isEmpty ? 'Description requise' : null,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Description du produit", filled: true, fillColor: Colors.white10, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        if (_images.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez ajouter au moins une photo')));
                          return;
                        }
                        final ok = await ref.read(productControllerProvider.notifier).uploadProduct(
                          name: _name.text.trim(),
                          price: _price.text.trim(),
                          description: _description.text.trim(),
                          deliveryPrice: double.tryParse(_deliveryPrice.text.trim()) ?? 0,
                          deliveryTime: _deliveryTime.text.trim(),
                          condition: _condition,
                          quantity: int.tryParse(_quantity.text.trim()) ?? 1,
                          color: _color.text.trim(),
                          imageFile: _images[0],
                        );
                        if (ok) {
                          ref.read(marketProductsProvider.notifier).addProduct(Product(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            name: _name.text.trim(),
                            price: _price.text.trim(),
                            seller: 'Moi',
                            condition: _condition,
                            description: _description.text.trim(),
                            color: _color.text.trim(),
                            deliveryPrice: double.parse(_deliveryPrice.text.trim()),
                            deliveryTime: _deliveryTime.text.trim(),
                            quantity: int.parse(_quantity.text.trim()),
                            rating: 5.0,
                            reviews: 0,
                            totalBuyerRatings: 0,
                            images: _images,
                          ));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Article publié avec succès')));
                            Navigator.pop(context);
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Échec de la publication')));
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: state.isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("PUBLIER"),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// --- NOTIFICATIONS VIEW ---

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});
  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> notifications = [
      {'title': 'Nouvel achat', 'msg': 'Quelqu\'un a acheté votre iPhone', 'time': 'Il y a 2h'},
      {'title': 'Livraison confirmée', 'msg': 'Votre commande est en route', 'time': 'Hier'},
      {'title': 'Promo exclusive', 'msg': 'Recevez 20% de réduction aujourd\'hui', 'time': 'Il y a 3j'},
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Notifications'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (c, i) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(notifications[i]['title']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(notifications[i]['time']!, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ]),
            const SizedBox(height: 6),
            Text(notifications[i]['msg']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: notifications.length,
      ),
    );
  }
}

// --- DELIVERY ADDRESS DIALOG ---

class _DeliveryAddressDialog extends StatefulWidget {
  final String? initialAddress;
  final ValueChanged<String> onSave;
  const _DeliveryAddressDialog({this.initialAddress, required this.onSave});
  @override
  State<_DeliveryAddressDialog> createState() => _DeliveryAddressDialogState();
}

class _DeliveryAddressDialogState extends State<_DeliveryAddressDialog> {
  late TextEditingController _addrCtrl;

  @override
  void initState() {
    super.initState();
    _addrCtrl = TextEditingController(text: widget.initialAddress ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Adresse de livraison', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _addrCtrl,
        style: const TextStyle(color: Colors.white),
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Ex: 123 rue..., Quartier, Ville',
          hintStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          onPressed: () {
            widget.onSave(_addrCtrl.text);
            Navigator.pop(context);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    super.dispose();
  }
}