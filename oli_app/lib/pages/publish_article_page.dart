import 'package:flutter/material.dart';

class PublishArticlePage extends StatelessWidget {
  const PublishArticlePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publier un article')),
      body: const Center(child: Text('Formulaire de publication')),
    );
  }
}