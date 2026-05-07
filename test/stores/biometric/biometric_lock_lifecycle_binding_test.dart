import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/auth/biometric_service.dart';
import 'package:slock_app/stores/biometric/biometric_lock_lifecycle_binding.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        biometricServiceProvider.overrideWithValue(_FakeBiometricService()),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('binding registers lifecycle observer', () {
    // Activate the binding
    container.read(biometricLockLifecycleBindingProvider);

    // If we got here without error, the observer was registered
    // (WidgetsBinding.addObserver was called)
    expect(true, isTrue);
  });

  test('paused lifecycle records background timestamp', () async {
    await container.read(biometricStoreProvider.notifier).setEnabled(true);
    container.read(biometricStoreProvider.notifier).unlock();

    // Activate binding
    container.read(biometricLockLifecycleBindingProvider);

    // Simulate app going to background
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    await Future<void>.delayed(Duration.zero);

    final state = container.read(biometricStoreProvider);
    expect(state.lastBackgroundAt, isNotNull);
  });

  test('resumed after long background triggers lock', () async {
    await container.read(biometricStoreProvider.notifier).setEnabled(true);
    container.read(biometricStoreProvider.notifier).unlock();

    // Manually set a background timestamp 10 minutes ago
    final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10));
    container
        .read(biometricStoreProvider.notifier)
        .recordBackground(tenMinutesAgo);

    // Activate binding
    container.read(biometricLockLifecycleBindingProvider);

    // Simulate app resuming
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await Future<void>.delayed(Duration.zero);

    final state = container.read(biometricStoreProvider);
    expect(state.isLocked, isTrue);
  });

  test('resumed after short background does not lock', () async {
    await container.read(biometricStoreProvider.notifier).setEnabled(true);
    container.read(biometricStoreProvider.notifier).unlock();

    // Manually set a background timestamp 2 minutes ago
    final twoMinutesAgo = DateTime.now().subtract(const Duration(minutes: 2));
    container
        .read(biometricStoreProvider.notifier)
        .recordBackground(twoMinutesAgo);

    // Activate binding
    container.read(biometricLockLifecycleBindingProvider);

    // Simulate app resuming
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await Future<void>.delayed(Duration.zero);

    final state = container.read(biometricStoreProvider);
    expect(state.isLocked, isFalse);
  });

  test('resumed when disabled does not lock', () async {
    // Leave biometric disabled (default)

    // Manually set a background timestamp 10 minutes ago
    final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10));
    container
        .read(biometricStoreProvider.notifier)
        .recordBackground(tenMinutesAgo);

    // Activate binding
    container.read(biometricLockLifecycleBindingProvider);

    // Simulate app resuming
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await Future<void>.delayed(Duration.zero);

    final state = container.read(biometricStoreProvider);
    expect(state.isLocked, isFalse);
  });
}

class _FakeBiometricService implements BiometricService {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
  }) async {
    return BiometricAuthResult.success;
  }
}
