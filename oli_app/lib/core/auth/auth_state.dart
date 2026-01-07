enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
}

class AuthState {
  final AuthStatus status;
  final String? token;

  const AuthState({
    required this.status,
    this.token,
  });

  factory AuthState.unknown() =>
      const AuthState(status: AuthStatus.unknown);

  factory AuthState.authenticated(String token) =>
      AuthState(status: AuthStatus.authenticated, token: token);

  factory AuthState.unauthenticated() =>
      const AuthState(status: AuthStatus.unauthenticated);
}
