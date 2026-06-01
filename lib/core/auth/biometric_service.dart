import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Result of a biometric authentication attempt.
enum BiometricAuthResult {
  /// Authentication succeeded.
  success,

  /// User explicitly cancelled the prompt.
  cancelled,

  /// Too many failed attempts — biometrics temporarily locked out.
  lockout,

  /// Biometrics permanently locked out — device credential required.
  permanentLockout,

  /// Biometric hardware is temporarily unavailable.
  notAvailable,

  /// No biometric credential is enrolled.
  notEnrolled,

  /// Generic transient authentication error.
  error,
}

/// Abstract biometric authentication service.
///
/// Wraps platform biometric APIs behind a testable interface.
abstract class BiometricService {
  /// Whether the device has biometric hardware with enrolled credentials.
  Future<bool> isAvailable();

  /// Prompt the user for biometric authentication.
  ///
  /// [localizedReason] is displayed in the system dialog explaining why
  /// authentication is needed.
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
  });
}

/// Production implementation wrapping the `local_auth` plugin.
class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      // `authenticate(biometricOnly: false)` can fall back to device PIN /
      // pattern when biometrics are unavailable, so app lock is available when
      // the device supports local authentication at all.
      return _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
  }) async {
    try {
      final success = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      return success
          ? BiometricAuthResult.success
          : BiometricAuthResult.cancelled;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'LockedOut':
          return BiometricAuthResult.lockout;
        case 'PermanentlyLockedOut':
          return BiometricAuthResult.permanentLockout;
        case 'NotAvailable':
          return BiometricAuthResult.notAvailable;
        case 'NotEnrolled':
        case 'PasscodeNotSet':
          return BiometricAuthResult.notEnrolled;
        default:
          return BiometricAuthResult.error;
      }
    }
  }
}

/// Riverpod provider for [BiometricService].
///
/// Override in tests with a fake implementation.
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return LocalAuthBiometricService();
});
