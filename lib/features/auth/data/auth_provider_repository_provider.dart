import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_provider.dart';
import 'package:slock_app/features/auth/data/auth_provider_repository.dart';

const _providersPath = '/auth/providers';

final authProviderRepositoryProvider = Provider<AuthProviderRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiAuthProviderRepository(appDioClient: appDioClient);
});

class _ApiAuthProviderRepository implements AuthProviderRepository {
  const _ApiAuthProviderRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<List<AuthProvider>> getProviders() async {
    try {
      final response = await _appDioClient.get<Object?>(_providersPath);
      return _parseProviders(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      // On failure, return empty list — providers are optional enhancement.
      return const [];
    }
  }

  List<AuthProvider> _parseProviders(Object? payload) {
    if (payload is! List) return const [];
    final results = <AuthProvider>[];
    for (final item in payload) {
      if (item is! Map) continue;
      final map =
          item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
      final id = map['id'];
      final name = map['name'];
      if (id is! String || id.isEmpty) continue;
      if (name is! String || name.isEmpty) continue;
      final iconUrl = map['iconUrl'];
      results.add(AuthProvider(
        id: id,
        name: name,
        iconUrl: iconUrl is String && iconUrl.isNotEmpty ? iconUrl : null,
      ));
    }
    return results;
  }
}
