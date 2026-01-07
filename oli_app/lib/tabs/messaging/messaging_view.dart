import 'package:flutter/material.dart';

class MessagingView extends StatelessWidget {
  const MessagingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: Text('Messages', style: TextStyle(color: Colors.white))),
    );
  }
}