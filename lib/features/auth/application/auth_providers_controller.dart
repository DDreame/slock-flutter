import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/auth/data/auth_provider.dart';
import 'package:slock_app/features/auth/data/auth_provider_repository_provider.dart';

/// Fetches available OAuth/SSO providers from the server.
///
/// Auto-disposes when the login/register page is unmounted — re-fetches
/// fresh data each time the page is shown.
final authProvidersProvider =
    FutureProvider.autoDispose<List<AuthProvider>>((ref) async {
  final repo = ref.watch(authProviderRepositoryProvider);
  return repo.getProviders();
});
