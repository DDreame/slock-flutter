import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/settings/data/base_url_connection_tester.dart';
import 'package:slock_app/features/settings/data/base_url_settings.dart';
import 'package:slock_app/features/settings/presentation/page/base_url_settings_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/base_url/base_url_settings_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildSubject({
    BaseUrlConnectionTester? tester,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (tester != null)
          baseUrlConnectionTesterProvider.overrideWithValue(tester),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: GoRouter(
          initialLocation: '/settings/base-url',
          routes: [
            GoRoute(
              path: '/settings/base-url',
              builder: (context, state) => const BaseUrlSettingsPage(),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('renders title and both URL fields', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Server Configuration'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('base-url-api-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('base-url-realtime-field')),
      findsOneWidget,
    );
  });

  testWidgets('renders save, test connection, restore buttons', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('base-url-save')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('base-url-test-connection')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('base-url-restore-defaults')),
      findsOneWidget,
    );
  });

  testWidgets('shows empty-default helper text when fields empty', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(
      find.text('Using build-time default'),
      findsNWidgets(2),
    );
  });

  testWidgets('save with valid URL shows success snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('base-url-api-field')),
      'https://api.example.com',
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('base-url-realtime-field')),
      'wss://rt.example.com',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('base-url-save')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Restart the app'),
      findsOneWidget,
    );
  });

  testWidgets('save with invalid API URL shows error snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('base-url-api-field')),
      'not-a-url',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('base-url-save')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('http://'),
      findsOneWidget,
    );
  });

  testWidgets('restore defaults clears fields', (
    tester,
  ) async {
    // Pre-populate saved settings
    await SharedPrefsBaseUrlRepository(prefs: prefs).save(
      const BaseUrlSettings(
        apiBaseUrl: 'https://api.saved.com',
        realtimeUrl: 'wss://rt.saved.com',
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // Verify pre-populated
    final apiField = tester.widget<TextField>(
      find.byKey(const ValueKey('base-url-api-field')),
    );
    expect(apiField.controller!.text, 'https://api.saved.com');

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('base-url-restore-defaults')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('base-url-restore-defaults')),
    );
    await tester.pumpAndSettle();

    // After restore, fields should be empty
    final apiFieldAfter = tester.widget<TextField>(
      find.byKey(const ValueKey('base-url-api-field')),
    );
    expect(apiFieldAfter.controller!.text, '');

    expect(
      find.textContaining('Defaults restored'),
      findsOneWidget,
    );
  });

  testWidgets('loads saved settings on init', (
    tester,
  ) async {
    await SharedPrefsBaseUrlRepository(prefs: prefs).save(
      const BaseUrlSettings(
        apiBaseUrl: 'https://api.loaded.com',
        realtimeUrl: 'wss://rt.loaded.com',
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final apiField = tester.widget<TextField>(
      find.byKey(const ValueKey('base-url-api-field')),
    );
    expect(apiField.controller!.text, 'https://api.loaded.com');

    final rtField = tester.widget<TextField>(
      find.byKey(const ValueKey('base-url-realtime-field')),
    );
    expect(rtField.controller!.text, 'wss://rt.loaded.com');
  });
}
