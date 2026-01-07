import 'dart:convert'; // Indispensable pour jsonDecode
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Indispensable pour FutureProvider
import 'package:http/http.dart' as http; // Indispensable pour http.get

final marketProductsProvider = FutureProvider<List<dynamic>>((ref) async {
  // 127.0.0.1 pour Linux Desktop / 10.0.2.2 pour Émulateur Android
  const String apiUrl = 'http://127.0.0.1:3000/products';
  
  try {
    print("📡 Tentative de connexion à : $apiUrl");
    final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      print("✅ Produits reçus : ${data.length}");
      return data;
    } else {
      print("⚠️ Erreur serveur : ${response.statusCode}");
      throw 'Erreur serveur (${response.statusCode})';
    }
  } catch (e) {
    print("❌ Erreur de connexion au serveur : $e");
    throw 'Impossible de charger les produits. Vérifie ton terminal Node.js.';
  }
});