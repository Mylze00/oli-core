import 'package:flutter/material.dart';

class RequestProductPage extends StatelessWidget {
  const RequestProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Demande d'un produit")),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_add, size: 80, color: Colors.orange),
            SizedBox(height: 20),
            Text(
              "Formulaire de demande",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text("Bientôt disponible : demandez un produit spécifique."),
          ],
        ),
      ),
    );
  }
}
