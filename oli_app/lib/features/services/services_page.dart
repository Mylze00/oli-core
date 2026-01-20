import 'package:flutter/material.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Services Publics")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildServiceTile(context, "SNEL", Icons.flash_on, Colors.yellow[700]!),
          _buildServiceTile(context, "REGIDESO", Icons.water_drop, Colors.blue),
          _buildServiceTile(context, "Canal+", Icons.tv, Colors.black),
        ],
      ),
    );
  }

  Widget _buildServiceTile(BuildContext context, String title, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Paiement $title bientôt disponible")),
          );
        },
      ),
    );
  }
}
