import 'package:flutter/material.dart';
import 'core/router/app_router.dart';

class OliApp extends StatelessWidget {
  const OliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OLI',
      theme: ThemeData.dark(useMaterial3: true),
      routerConfig: appRouter,
    );
  }
}
