import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:slock_app/core/auth/biometric_service.dart';

void main() {
  group('LocalAuthBiometricService.isAvailable', () {
    test('returns true when canCheckBiometrics and isDeviceSupported',
        () async {
      final auth = _FakeLocalAuth(
        canCheck: true,
        deviceSupported: true,
      );
      final service = LocalAuthBiometricService(auth: auth);

      expect(await service.isAvailable(), isTrue);
    });

    test('returns true when device credentials are supported', () async {
      final auth = _FakeLocalAuth(
        canCheck: false,
        deviceSupported: true,
      );
      final service = LocalAuthBiometricService(auth: auth);

      expect(await service.isAvailable(), isTrue);
    });

    test('returns false when isDeviceSupported is false', () async {
      final auth = _FakeLocalAuth(
        canCheck: true,
        deviceSupported: false,
      );
      final service = LocalAuthBiometricService(auth: auth);

      expect(await service.isAvailable(), isFalse);
    });

    test('returns false on PlatformException', () async {
      final auth = _FakeLocalAuth(
        canCheck: true,
        deviceSupported: true,
        throwOnIsDeviceSupported: true,
      );
      final service = LocalAuthBiometricService(auth: auth);

      expect(await service.isAvailable(), isFalse);
    });
  });

  group('LocalAuthBiometricService.authenticate', () {
    test('returns success when auth succeeds', () async {
      final auth = _FakeLocalAuth(
        canCheck: true,
        deviceSupported: true,
        authResult: true,
      );
      final service = LocalAuthBiometricService(auth: auth);

      final result = await service.authenticate(
        localizedReason: 'Unlock app',
      );
      expect(result, BiometricAuthResult.success);
    });

    test('returns cancelled when auth returns false', () async {
      final auth = _FakeLocalAuth(
        canCheck: true,
        deviceSupported: true,
        authResult: false,
      );
      final service = LocalAuthBiometricService(auth: auth);

      final result = await service.authenticate(
        localizedReason: 'Unlock app',
      );
      expect(result, BiometricAuthResult.cancelled);
    });

    test('returns lockout on LockedOut PlatformException', () async {
      final auth = _FakeLocalAuth(
        canCheck: true,
        deviceSupported: true,
        authException: PlatformException(
          code: 'LockedOut',
          message: 'Too many attempts',
        ),
      );
      final service = LocalAuthBiometricService(auth: auth);

      final result = await service.authenticate(
        localizedReason: 'Unlock app',
      );
      expect(result, BiometricAuthResult.lockout);
    });

    test('returns permanentLockout on PermanentlyLockedOut PlatformException',
        () async {
      final auth = _FakeLocalAuth(
        canCheck: true,
        deviceSupported: true,
        authException: PlatformException(
          code: 'PermanentlyLockedOut',
          message: 'Permanently locked',
        ),
      );
      final service = LocalAuthBiometricService(auth: auth);

      final result = await service.authenticate(
        localizedReason: 'Unlock app',
      );
      expect(result, BiometricAuthResult.permanentLockout);
    });

    test('returns notAvailable on NotAvailable PlatformException', () async {
      final auth = _FakeLocalAuth(
        canCheck: true,
        deviceSupported: true,
        authException: PlatformException(
          code: 'NotAvailable',
          message: 'Not available',
        ),
      );
      final service = LocalAuthBiometricService(auth: auth);

      final result = await service.authenticate(
        localizedReason: 'Unlock app',
      );
      expect(result, BiometricAuthResult.notAvailable);
    });

    test('returns error on unknown PlatformException', () async {
      final auth = _FakeLocalAuth(
        canCheck: true,
        deviceSupported: true,
        authException: PlatformException(
          code: 'SomeUnknownCode',
          message: 'Unknown error',
        ),
      );
      final service = LocalAuthBiometricService(auth: auth);

      final result = await service.authenticate(
        localizedReason: 'Unlock app',
      );
      expect(result, BiometricAuthResult.error);
    });

    test('passes localizedReason to plugin', () async {
      final auth = _FakeLocalAuth(
        canCheck: true,
        deviceSupported: true,
        authResult: true,
      );
      final service = LocalAuthBiometricService(auth: auth);

      await service.authenticate(localizedReason: 'Test reason');

      expect(auth.lastLocalizedReason, 'Test reason');
    });
  });
}

/// Minimal fake that uses [noSuchMethod] to satisfy the full
/// [LocalAuthentication] API surface while only overriding the
/// methods exercised by [LocalAuthBiometricService].
class _FakeLocalAuth implements LocalAuthentication {
  _FakeLocalAuth({
    required this.canCheck,
    required this.deviceSupported,
    this.authResult = true,
    this.throwOnIsDeviceSupported = false,
    this.authException,
  });

  final bool canCheck;
  final bool deviceSupported;
  final bool authResult;
  final bool throwOnIsDeviceSupported;
  final PlatformException? authException;
  String? lastLocalizedReason;

  @override
  Future<bool> get canCheckBiometrics => Future.value(canCheck);

  @override
  Future<bool> isDeviceSupported() {
    if (throwOnIsDeviceSupported) {
      throw PlatformException(code: 'NotAvailable');
    }
    return Future.value(deviceSupported);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    // authenticate() — match by symbol name since the method has
    // a complex signature that varies across local_auth versions.
    if (name == #authenticate) {
      lastLocalizedReason =
          invocation.namedArguments[#localizedReason] as String?;
      if (authException != null) throw authException!;
      return Future.value(authResult);
    }
    return super.noSuchMethod(invocation);
  }
}
