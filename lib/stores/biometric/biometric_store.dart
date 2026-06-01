import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/auth/biometric_service.dart';
import 'package:slock_app/features/settings/data/biometric_preference.dart';

/// Whether the device has biometric hardware available.
enum BiometricAvailability { unknown, available, unavailable }

/// The current lock state of the biometric gate.
enum BiometricLockStatus { locked, unlocked }

/// Immutable state for biometric authentication.
@immutable
class BiometricState {
  const BiometricState({
    this.enabled = false,
    this.lockStatus = BiometricLockStatus.unlocked,
    this.availability = BiometricAvailability.unknown,
    this.timeout = BiometricLockTimeout.fiveMinutes,
    this.lastBackgroundAt,
  });

  /// Whether the user has opted in to biometric lock.
  final bool enabled;

  /// Current lock state — [locked] triggers the lock screen.
  final BiometricLockStatus lockStatus;

  /// Whether the device has biometric hardware.
  final BiometricAvailability availability;

  /// Background duration before the app requires authentication again.
  final BiometricLockTimeout timeout;

  /// When the app last went to background (for timeout calculation).
  final DateTime? lastBackgroundAt;

  bool get isLocked => enabled && lockStatus == BiometricLockStatus.locked;

  BiometricState copyWith({
    bool? enabled,
    BiometricLockStatus? lockStatus,
    BiometricAvailability? availability,
    BiometricLockTimeout? timeout,
    DateTime? lastBackgroundAt,
    bool clearLastBackgroundAt = false,
  }) {
    return BiometricState(
      enabled: enabled ?? this.enabled,
      lockStatus: lockStatus ?? this.lockStatus,
      availability: availability ?? this.availability,
      timeout: timeout ?? this.timeout,
      lastBackgroundAt: clearLastBackgroundAt
          ? null
          : (lastBackgroundAt ?? this.lastBackgroundAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiometricState &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          lockStatus == other.lockStatus &&
          availability == other.availability &&
          timeout == other.timeout &&
          lastBackgroundAt == other.lastBackgroundAt;

  @override
  int get hashCode => Object.hash(
        enabled,
        lockStatus,
        availability,
        timeout,
        lastBackgroundAt,
      );
}

/// Store managing biometric authentication state.
///
/// Preference (enabled/disabled) is persisted via [BiometricPreferenceRepository].
/// Lock status is ephemeral — starts unlocked and transitions to locked
/// when the app is backgrounded beyond the configured biometric timeout.
class BiometricStore extends Notifier<BiometricState> {
  @override
  BiometricState build() => const BiometricState();

  /// Restore preferences from secure storage before first authenticated frame.
  Future<void> initialize() async {
    final repo = ref.read(biometricPreferenceRepositoryProvider);
    final snapshot = await repo.load();
    state = state.copyWith(
      enabled: snapshot.enabled,
      timeout: snapshot.timeout,
      lockStatus: snapshot.enabled
          ? BiometricLockStatus.locked
          : BiometricLockStatus.unlocked,
    );
  }

  /// Restore preference snapshot directly for tests/bootstrap helpers.
  void restoreFrom(BiometricPreferenceSnapshot snapshot) {
    state = state.copyWith(
      enabled: snapshot.enabled,
      timeout: snapshot.timeout,
      lockStatus: snapshot.enabled
          ? BiometricLockStatus.locked
          : BiometricLockStatus.unlocked,
    );
  }

  /// Check hardware availability and update state.
  ///
  /// When biometrics are unavailable but the preference is enabled
  /// (e.g. device migration or hardware removal), auto-disables the
  /// preference and unlocks to prevent a dead-end lock screen.
  Future<void> checkAvailability() async {
    final service = ref.read(biometricServiceProvider);
    final available = await service.isAvailable();
    if (!available && state.enabled) {
      // Hardware gone — clear preference and unlock to avoid dead-end.
      final repo = ref.read(biometricPreferenceRepositoryProvider);
      await repo.setEnabled(false);
      state = state.copyWith(
        availability: BiometricAvailability.unavailable,
        enabled: false,
        lockStatus: BiometricLockStatus.unlocked,
      );
    } else {
      state = state.copyWith(
        availability: available
            ? BiometricAvailability.available
            : BiometricAvailability.unavailable,
      );
    }
  }

  /// Enable or disable biometric lock.
  Future<void> setEnabled(bool enabled) async {
    final repo = ref.read(biometricPreferenceRepositoryProvider);
    await repo.setEnabled(enabled);
    state = state.copyWith(
      enabled: enabled,
      lockStatus:
          enabled ? BiometricLockStatus.locked : BiometricLockStatus.unlocked,
    );
  }

  /// Transition to locked state.
  void lock() {
    if (!state.enabled) return;
    state = state.copyWith(lockStatus: BiometricLockStatus.locked);
  }

  /// Transition to unlocked state after successful authentication.
  void unlock() {
    state = state.copyWith(
      lockStatus: BiometricLockStatus.unlocked,
      clearLastBackgroundAt: true,
    );
  }

  /// Record when the app was backgrounded.
  void recordBackground(DateTime timestamp) {
    state = state.copyWith(lastBackgroundAt: timestamp);
  }

  /// Persist and update the background timeout.
  Future<void> setTimeout(BiometricLockTimeout timeout) async {
    final repo = ref.read(biometricPreferenceRepositoryProvider);
    await repo.setTimeout(timeout);
    state = state.copyWith(timeout: timeout);
  }

  /// Check whether the background timeout has elapsed and lock if so.
  void checkTimeoutAndLock(DateTime now) {
    if (!state.enabled) return;
    final backgroundAt = state.lastBackgroundAt;
    if (backgroundAt == null) return;
    if (now.difference(backgroundAt) >= state.timeout.duration) {
      state = state.copyWith(lockStatus: BiometricLockStatus.locked);
    }
  }
}

/// App-scoped provider for [BiometricStore].
final biometricStoreProvider =
    NotifierProvider<BiometricStore, BiometricState>(BiometricStore.new);
