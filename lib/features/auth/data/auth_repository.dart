class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

class AuthUser {
  const AuthUser({required this.id, this.name});

  final String id;
  final String? name;
}

abstract class AuthRepository {
  Future<AuthResult> login({
    required String email,
    required String password,
  });

  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  });

  Future<AuthUser> getMe();

  Future<void> requestPasswordReset({required String email});
}
