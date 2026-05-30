import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/data/onboarding_settings_repository.dart';

final onboardingSettingsRepositoryProvider =
    Provider<OnboardingSettingsRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiOnboardingSettingsRepository(appDioClient: appDioClient);
});

class _ApiOnboardingSettingsRepository implements OnboardingSettingsRepository {
  const _ApiOnboardingSettingsRepository({
    required AppDioClient appDioClient,
  }) : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  String _path(ServerScopeId serverId) =>
      '/servers/${serverId.value}/onboarding-settings';

  @override
  Future<OnboardingSettings> getSettings(ServerScopeId serverId) async {
    try {
      final response = await _appDioClient.get<Object?>(_path(serverId));
      return _parseSettings(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load onboarding settings.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<OnboardingSettings> updateSettings(
    ServerScopeId serverId, {
    required bool setupModalReminderOptOut,
  }) async {
    try {
      final response = await _appDioClient.request<Object?>(
        _path(serverId),
        method: 'PATCH',
        data: {'setupModalReminderOptOut': setupModalReminderOptOut},
      );
      return _parseSettings(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to update onboarding settings.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  OnboardingSettings _parseSettings(Object? payload) {
    if (payload is! Map) {
      throw SerializationFailure(
        message: 'Malformed onboarding settings payload: expected an object.',
        causeType: payload?.runtimeType.toString() ?? 'Null',
      );
    }
    final map = Map<String, dynamic>.from(payload);
    return OnboardingSettings(
      setupModalReminderOptOut: map['setupModalReminderOptOut'] == true,
      onboardingReminderOptOut: map['onboardingReminderOptOut'] == true,
    );
  }
}
