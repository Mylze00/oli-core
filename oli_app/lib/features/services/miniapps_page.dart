import 'package:flutter/material.dart';

class MiniAppsPage extends StatelessWidget {
  const MiniAppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mini-Apps & Jeux")),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apps, size: 80, color: Colors.purple),
            SizedBox(height: 20),
            Text(
              "Hub d'Applications",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text("Jeux, Utilitaires et plus encore...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
