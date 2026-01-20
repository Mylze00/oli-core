import 'package:flutter/material.dart';

class LiveShoppingPage extends StatelessWidget {
  const LiveShoppingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Live Shopping", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.live_tv, size: 80, color: Colors.redAccent),
            SizedBox(height: 20),
            Text(
              "Directs à venir",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text("Achetez en direct de vos vendeurs préférés.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
