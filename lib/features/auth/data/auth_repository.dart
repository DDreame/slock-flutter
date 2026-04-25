class AuthResult {
  const AuthResult({
    required this.token,
    required this.userId,
    this.displayName,
  });

  final String token;
  final String userId;
  final String? displayName;
}

abstract class AuthRepository {
  Future<AuthResult> login({
    required String email,
    required String password,
  });

  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> requestPasswordReset({required String email});
}
