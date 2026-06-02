import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/data/onboarding_settings_repository.dart';
import 'package:slock_app/features/servers/data/onboarding_settings_repository_provider.dart';

/// Fetches onboarding settings for a server.
///
/// Thin application-layer wrapper around
/// [OnboardingSettingsRepository.getSettings].
final getOnboardingSettingsUseCaseProvider =
    Provider<Future<OnboardingSettings> Function(ServerScopeId serverId)>(
        (ref) {
  return (ServerScopeId serverId) =>
      ref.read(onboardingSettingsRepositoryProvider).getSettings(serverId);
});

/// Updates onboarding settings for a server.
///
/// Thin application-layer wrapper around
/// [OnboardingSettingsRepository.updateSettings].
final updateOnboardingSettingsUseCaseProvider = Provider<
    Future<OnboardingSettings> Function(
      ServerScopeId serverId, {
      required bool setupModalReminderOptOut,
    })>((ref) {
  return (ServerScopeId serverId, {required bool setupModalReminderOptOut}) =>
      ref.read(onboardingSettingsRepositoryProvider).updateSettings(
            serverId,
            setupModalReminderOptOut: setupModalReminderOptOut,
          );
});
