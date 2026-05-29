/// Represents an available OAuth/SSO provider returned by `GET /auth/providers`.
class AuthProvider {
  const AuthProvider({
    required this.id,
    required this.name,
    this.iconUrl,
  });

  /// Provider identifier (e.g. "google", "github").
  final String id;

  /// Human-readable display name (e.g. "Google", "GitHub").
  final String name;

  /// Optional icon URL for the provider.
  final String? iconUrl;
}
