import 'package:slock_app/core/core.dart';

/// Settings for the workspace onboarding experience (owner-only).
class OnboardingSettings {
  const OnboardingSettings({
    required this.setupModalReminderOptOut,
    required this.onboardingReminderOptOut,
  });

  /// Whether the setup modal reminder is suppressed.
  final bool setupModalReminderOptOut;

  /// Whether the onboarding reminder is suppressed.
  final bool onboardingReminderOptOut;

  OnboardingSettings copyWith({
    bool? setupModalReminderOptOut,
    bool? onboardingReminderOptOut,
  }) {
    return OnboardingSettings(
      setupModalReminderOptOut:
          setupModalReminderOptOut ?? this.setupModalReminderOptOut,
      onboardingReminderOptOut:
          onboardingReminderOptOut ?? this.onboardingReminderOptOut,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingSettings &&
          runtimeType == other.runtimeType &&
          setupModalReminderOptOut == other.setupModalReminderOptOut &&
          onboardingReminderOptOut == other.onboardingReminderOptOut;

  @override
  int get hashCode =>
      Object.hash(setupModalReminderOptOut, onboardingReminderOptOut);
}

/// Repository for fetching and updating onboarding settings.
abstract class OnboardingSettingsRepository {
  Future<OnboardingSettings> getSettings(ServerScopeId serverId);

  Future<OnboardingSettings> updateSettings(
    ServerScopeId serverId, {
    required bool setupModalReminderOptOut,
  });
}
