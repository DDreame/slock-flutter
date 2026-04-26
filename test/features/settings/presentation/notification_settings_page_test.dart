import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/features/settings/presentation/page/notification_settings_page.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

void main() {
  testWidgets('shows permission status and diagnostics', (tester) async {
    final store = _FakeNotificationStore(
      initialState: const NotificationState(
        permissionStatus: NotificationPermissionStatus.granted,
        pushToken: 'abcdefghijklmnopqrstuvwxyz1234567890',
        pushTokenPlatform: 'android',
        pushTokenUpdatedAt: null,
      ),
    );
    final diagnostics = DiagnosticsCollector();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationStoreProvider.overrideWith(() => store),
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
        ],
        child: const MaterialApp(home: NotificationSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Permission granted'), findsWidgets);
    expect(find.text('android'), findsOneWidget);
    expect(find.text('abcdefgh...34567890'), findsOneWidget);
  });

  testWidgets('shows all three preference options', (tester) async {
    final store = _FakeNotificationStore();
    final diagnostics = DiagnosticsCollector();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationStoreProvider.overrideWith(() => store),
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
        ],
        child: const MaterialApp(home: NotificationSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All Messages'), findsOneWidget);
    expect(find.text('Mentions & DMs Only'), findsOneWidget);
    expect(find.text('Mute'), findsOneWidget);
  });

  testWidgets('tapping preference radio calls setNotificationPreference', (
    tester,
  ) async {
    final store = _FakeNotificationStore();
    final diagnostics = DiagnosticsCollector();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationStoreProvider.overrideWith(() => store),
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
        ],
        child: const MaterialApp(home: NotificationSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('notification-preference-mute')),
      200,
    );
    await tester.tap(find.text('Mute'));
    await tester.pumpAndSettle();

    expect(store.lastPreference, NotificationPreference.mute);
  });

  testWidgets('tapping permission action calls requestPermission', (
    tester,
  ) async {
    final store = _FakeNotificationStore();
    final diagnostics = DiagnosticsCollector();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationStoreProvider.overrideWith(() => store),
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
        ],
        child: const MaterialApp(home: NotificationSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('notification-settings-permission-action')),
    );
    await tester.pumpAndSettle();

    expect(store.requestPermissionCount, 1);
    expect(store.refreshTokenCount, 1);
  });

  testWidgets('shows empty diagnostics message when no events', (
    tester,
  ) async {
    final store = _FakeNotificationStore();
    final diagnostics = DiagnosticsCollector();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationStoreProvider.overrideWith(() => store),
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
        ],
        child: const MaterialApp(home: NotificationSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('notification-diagnostics-events')),
      200,
    );

    expect(find.text('No recent notification events.'), findsOneWidget);
  });

  testWidgets('shows diagnostics entries when present', (tester) async {
    final store = _FakeNotificationStore();
    final diagnostics = DiagnosticsCollector();
    diagnostics.add(DiagnosticsEntry(
      timestamp: DateTime.now(),
      level: DiagnosticsLevel.info,
      tag: 'notification',
      message: 'Permission request result: granted',
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationStoreProvider.overrideWith(() => store),
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
        ],
        child: const MaterialApp(home: NotificationSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('notification-diagnostics-events')),
      200,
    );

    expect(
      find.text('Permission request result: granted'),
      findsOneWidget,
    );
  });
}

class _FakeNotificationStore extends NotificationStore {
  _FakeNotificationStore({NotificationState? initialState})
      : _initialState = initialState;

  final NotificationState? _initialState;
  var requestPermissionCount = 0;
  var refreshTokenCount = 0;
  NotificationPreference? lastPreference;

  @override
  NotificationState build() => _initialState ?? const NotificationState();

  @override
  Future<void> requestPermission() async {
    requestPermissionCount += 1;
    state = state.copyWith(
      permissionStatus: NotificationPermissionStatus.granted,
    );
  }

  @override
  Future<void> refreshToken({String? platform}) async {
    refreshTokenCount += 1;
    state = state.copyWith(
      pushToken: 'push-token',
      pushTokenPlatform: platform,
      pushTokenUpdatedAt: DateTime.utc(2026, 4, 25),
    );
  }

  @override
  Future<void> setNotificationPreference(
    NotificationPreference preference,
  ) async {
    lastPreference = preference;
    state = state.copyWith(notificationPreference: preference);
  }
}
