import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

AppLifecycleStatus mapAppLifecycleState(AppLifecycleState state) {
  return switch (state) {
    AppLifecycleState.resumed => AppLifecycleStatus.resumed,
    AppLifecycleState.inactive => AppLifecycleStatus.inactive,
    AppLifecycleState.paused => AppLifecycleStatus.paused,
    AppLifecycleState.detached => AppLifecycleStatus.detached,
    AppLifecycleState.hidden => AppLifecycleStatus.paused,
  };
}

final notificationLifecycleBindingProvider = Provider<void>((ref) {
  final observer = _LifecycleObserver(ref);
  final binding = WidgetsBinding.instance;
  binding.addObserver(observer);
  ref.onDispose(() => binding.removeObserver(observer));
});

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver(this._ref);

  final Ref _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ref
        .read(notificationStoreProvider.notifier)
        .setLifecycleStatus(mapAppLifecycleState(state));
  }
}
