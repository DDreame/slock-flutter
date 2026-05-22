import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/features/onboarding/application/onboarding_store.dart';
import 'package:slock_app/features/onboarding/presentation/page/onboarding_page.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  testWidgets('walks steps, requests notifications, and completes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final initializer = _FakeNotificationInitializer();
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingPage(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (context, state) => const Scaffold(body: Text('edit')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationInitializerProvider.overrideWithValue(initializer),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('onboarding-welcome-step')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-notifications-step')),
        findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('onboarding-request-notifications')));
    await tester.pumpAndSettle();
    expect(initializer.requestPermissionCount, 1);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('onboarding-profile-step')), findsOneWidget);

    expect(
        find.byKey(const ValueKey('onboarding-edit-profile')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(prefs.getBool(OnboardingRepository.completeKey), isTrue);
  });
}

class _FakeNotificationInitializer implements NotificationInitializer {
  int requestPermissionCount = 0;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      NotificationPermissionStatus.unknown;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    requestPermissionCount++;
    return NotificationPermissionStatus.granted;
  }

  @override
  Future<void> init() async {}

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async => null;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => const Stream.empty();

  @override
  Stream<String> get onTokenChanged => const Stream.empty();

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) async {}
}
