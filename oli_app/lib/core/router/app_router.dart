import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/auth/auth_provider.dart';
import 'core/auth/auth_state.dart';

import '../../features/auth/screens/login_page.dart';
import 'home_page.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthProvider>().state;

    switch (authState.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );

      case AuthStatus.unauthenticated:
        return const LoginPage();

      case AuthStatus.authenticated:
        return const HomePage();
    }
  }
}
