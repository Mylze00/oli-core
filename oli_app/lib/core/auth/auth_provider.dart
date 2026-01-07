import 'package:flutter/material.dart';
import '../storage/secure_storage.dart';
import 'auth_state.dart';

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.unknown();

  AuthState get state => _state;

  AuthProvider() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final token = await SecureStorage.getToken();

    if (token != null) {
      _state = AuthState.authenticated(token);
    } else {
      _state = AuthState.unauthenticated();
    }
    notifyListeners();
  }

  Future<void> login(String token) async {
    await SecureStorage.saveToken(token);
    _state = AuthState.authenticated(token);
    notifyListeners();
  }

  Future<void> logout() async {
    await SecureStorage.deleteToken();
    _state = AuthState.unauthenticated();
    notifyListeners();
  }
}
