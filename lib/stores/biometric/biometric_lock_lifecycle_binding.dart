import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';

/// Lifecycle binding that monitors app lifecycle transitions and manages
/// biometric lock state based on background duration.
///
/// When the app goes to background, it records the timestamp.
/// When the app returns to foreground, it checks whether the background
/// duration exceeds the configured biometric timeout and locks if so.
///
/// Activate by calling `ref.watch(biometricLockLifecycleBindingProvider)`
/// in the root app widget.
final biometricLockLifecycleBindingProvider = Provider<void>((ref) {
  final observer = _BiometricLifecycleObserver(ref);
  final binding = WidgetsBinding.instance;
  binding.addObserver(observer);
  ref.onDispose(() => binding.removeObserver(observer));
});

class _BiometricLifecycleObserver extends WidgetsBindingObserver {
  _BiometricLifecycleObserver(this._ref);

  final Ref _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final store = _ref.read(biometricStoreProvider.notifier);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        store.recordBackground(DateTime.now());
      case AppLifecycleState.resumed:
        store.checkTimeoutAndLock(DateTime.now());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}
