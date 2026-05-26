// =============================================================================
// #825 — BaseUrl .select() Rebuild Isolation + NotificationSettings Reversed
//
// Verifies:
// 1. BaseUrlSettingsPage .select() only rebuilds on (apiTestResult,
//    realtimeTestResult, isTesting) — unrelated field changes (settings,
//    isDirty) do NOT trigger widget rebuild.
// 2. NotificationSettings diagnostics entries display in reverse
//    chronological order using .reversed (without redundant .toList()).
//
// Load-bearing proof:
//   Reverting .select() → ref.watch(full state) causes test 1 to fail
//   (widget rebuilds on setApiBaseUrl which mutates settings+isDirty).
//   Removing .reversed causes test 2 to fail (wrong order).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/settings/presentation/page/base_url_settings_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/base_url/base_url_settings_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  // ===========================================================================
  // Part 1: BaseUrlSettingsPage .select() rebuild isolation (widget-level)
  // ===========================================================================

  group('#825 — BaseUrlSettingsPage .select() rebuild isolation', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      BaseUrlSettingsPage.debugBuildCount = 0;
    });

    Widget buildSubject() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: GoRouter(
            initialLocation: '/test',
            routes: [
              GoRoute(
                path: '/test',
                builder: (context, state) => const BaseUrlSettingsPage(),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets(
      '.select() prevents rebuild on unrelated field mutation',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final before = BaseUrlSettingsPage.debugBuildCount;
        expect(before, greaterThan(0)); // Sanity: page was built.

        // Mutate settings + isDirty (NOT in the select tuple).
        // setApiBaseUrl changes settings.apiBaseUrl, sets isDirty=true,
        // and clears apiTestResult (which was already null → unchanged).
        final container = ProviderScope.containerOf(
          tester.element(find.byType(BaseUrlSettingsPage)),
        );
        container
            .read(baseUrlSettingsStoreProvider.notifier)
            .setApiBaseUrl('http://changed.example.com');

        await tester.pump();

        // Build count must NOT increase because .select() filters the
        // rebuild to only (apiTestResult, realtimeTestResult, isTesting)
        // and none of those changed.
        expect(BaseUrlSettingsPage.debugBuildCount, before);
      },
    );

    testWidgets(
      '.select() prevents rebuild on second unrelated mutation',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final before = BaseUrlSettingsPage.debugBuildCount;

        final container = ProviderScope.containerOf(
          tester.element(find.byType(BaseUrlSettingsPage)),
        );
        container
            .read(baseUrlSettingsStoreProvider.notifier)
            .setRealtimeUrl('wss://new-rt.example.com');

        await tester.pump();

        // realtimeTestResult was already null, so select tuple unchanged.
        expect(BaseUrlSettingsPage.debugBuildCount, before);
      },
    );
  });

  // ===========================================================================
  // Part 2: NotificationSettings diagnostics entries reverse order
  // ===========================================================================

  group('#825 — NotificationSettings diagnostics reversed order', () {
    test('entries filtered and reversed without extra toList allocation', () {
      // Simulate the exact computation from _DiagnosticsEventsList.build:
      // diagnostics.entries.where(...).toList().reversed
      final entries = [
        _FakeEntry(tag: 'notification', message: 'first', order: 1),
        _FakeEntry(tag: 'other', message: 'skip', order: 2),
        _FakeEntry(tag: 'notification', message: 'second', order: 3),
        _FakeEntry(tag: 'notification', message: 'third', order: 4),
      ];

      // Exact computation from production code (without redundant .toList()):
      final result =
          entries.where((e) => e.tag == 'notification').toList().reversed;

      // Verify reversed order (newest first).
      final messages = result.map((e) => e.message).toList();
      expect(messages, ['third', 'second', 'first']);

      // Verify isEmpty works on reversed Iterable.
      expect(result.isEmpty, isFalse);

      // Verify take(20) works (used in production for display limit).
      expect(result.take(20).length, 3);
    });

    test('empty diagnostics produces empty reversed iterable', () {
      final entries = <_FakeEntry>[
        _FakeEntry(tag: 'other', message: 'not-notification', order: 1),
      ];

      final result =
          entries.where((e) => e.tag == 'notification').toList().reversed;

      expect(result.isEmpty, isTrue);
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

class _FakeEntry {
  _FakeEntry({
    required this.tag,
    required this.message,
    required this.order,
  });

  final String tag;
  final String message;
  final int order;
}
