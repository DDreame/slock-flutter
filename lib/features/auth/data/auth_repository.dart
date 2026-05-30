class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

class AuthUser {
  const AuthUser({
    required this.id,
    this.name,
    this.bio,
    this.avatarUrl,
    this.emailVerified,
    this.hasPassword,
  });

  final String id;
  final String? name;
  final String? bio;
  final String? avatarUrl;
  final bool? emailVerified;

  /// Whether the user has a password set. OAuth-only accounts have no password.
  /// Null when the server does not yet return this field (backward-compatible).
  final bool? hasPassword;
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

  /// Exchange an OAuth authorization code for tokens.
  Future<AuthResult> completeOAuth({
    required String providerId,
    required String code,
  });

  Future<AuthUser> getMe();

  /// Revoke the refresh token server-side.
  ///
  /// Best-effort: callers should not block local cleanup on this call.
  Future<void> logout({required String refreshToken});

  Future<void> requestPasswordReset({required String email});

  Future<void> resetPassword({
    required String token,
    required String password,
  });

  Future<void> verifyEmail({required String token});

  Future<void> resendVerification();
}
