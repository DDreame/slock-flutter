import 'package:slock_app/features/auth/data/auth_provider.dart';

/// Repository interface for discovering available OAuth/SSO providers.
abstract class AuthProviderRepository {
  /// Fetches the list of available OAuth providers from the server.
  ///
  /// Returns an empty list if no providers are configured.
  Future<List<AuthProvider>> getProviders();
}
