import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/settings/presentation/page/appearance_settings_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

// ---------------------------------------------------------------------------
// #521: Theme Toggle — widget tests for AppearanceSettingsPage
//
// 4 tests:
//   INV-THEME-1a: Tapping Dark option updates selection UI
//   INV-THEME-1b: Theme selection persists to SharedPreferences
//   INV-THEME-2 : Default selection is System (follows OS)
//   INV-THEME-3 : All three options rendered with correct keys
// ---------------------------------------------------------------------------

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildApp({SharedPreferences? prefsOverride}) {
    final p = prefsOverride ?? prefs;
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(p),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const AppearanceSettingsPage(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // 1. Default selection is System (INV-THEME-2)
  // -----------------------------------------------------------------------
  testWidgets(
    'AppearanceSettingsPage: default selection is System '
    '(INV-THEME-2)',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // System option must show filled check_circle (selected).
      final systemTile = find.byKey(const ValueKey('theme-option-system'));
      expect(systemTile, findsOneWidget);

      // Find check_circle icon as descendant of system tile (selected).
      expect(
        find.descendant(
          of: systemTile,
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
        reason: 'System option must be selected by default (INV-THEME-2)',
      );

      // Light and Dark must show circle_outlined (unselected).
      final lightTile = find.byKey(const ValueKey('theme-option-light'));
      expect(
        find.descendant(
          of: lightTile,
          matching: find.byIcon(Icons.circle_outlined),
        ),
        findsOneWidget,
        reason: 'Light option must be unselected by default',
      );

      final darkTile = find.byKey(const ValueKey('theme-option-dark'));
      expect(
        find.descendant(
          of: darkTile,
          matching: find.byIcon(Icons.circle_outlined),
        ),
        findsOneWidget,
        reason: 'Dark option must be unselected by default',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 2. All three options rendered with correct keys (INV-THEME-3)
  // -----------------------------------------------------------------------
  testWidgets(
    'AppearanceSettingsPage: all three theme options rendered '
    '(INV-THEME-3)',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('theme-option-system')),
        findsOneWidget,
        reason: 'System option must be rendered',
      );
      expect(
        find.byKey(const ValueKey('theme-option-light')),
        findsOneWidget,
        reason: 'Light option must be rendered',
      );
      expect(
        find.byKey(const ValueKey('theme-option-dark')),
        findsOneWidget,
        reason: 'Dark option must be rendered',
      );

      // Verify labels
      expect(find.text('Follow System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    },
  );

  // -----------------------------------------------------------------------
  // 3. Tapping Dark option updates selection UI (INV-THEME-1a)
  // -----------------------------------------------------------------------
  testWidgets(
    'AppearanceSettingsPage: tapping Dark updates selection '
    '(INV-THEME-1a)',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Tap Dark option.
      await tester.tap(find.byKey(const ValueKey('theme-option-dark')));
      await tester.pumpAndSettle();

      // Dark must now show check_circle (selected).
      final darkTile = find.byKey(const ValueKey('theme-option-dark'));
      expect(
        find.descendant(
          of: darkTile,
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
        reason: 'Dark option must be selected after tap (INV-THEME-1a)',
      );

      // System must now show circle_outlined (unselected).
      final systemTile = find.byKey(const ValueKey('theme-option-system'));
      expect(
        find.descendant(
          of: systemTile,
          matching: find.byIcon(Icons.circle_outlined),
        ),
        findsOneWidget,
        reason: 'System option must be unselected after Dark is selected',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 4. Theme selection persists to SharedPreferences (INV-THEME-1b)
  // -----------------------------------------------------------------------
  testWidgets(
    'AppearanceSettingsPage: selection persists to SharedPreferences '
    '(INV-THEME-1b)',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Tap Light option.
      await tester.tap(find.byKey(const ValueKey('theme-option-light')));
      await tester.pumpAndSettle();

      // SharedPreferences must now contain 'light'.
      expect(
        prefs.getString('theme_preference'),
        'light',
        reason: 'Theme selection must persist to SharedPreferences '
            '(INV-THEME-1b)',
      );

      // Tap Dark option.
      await tester.tap(find.byKey(const ValueKey('theme-option-dark')));
      await tester.pumpAndSettle();

      // SharedPreferences must now contain 'dark'.
      expect(
        prefs.getString('theme_preference'),
        'dark',
        reason: 'Changing theme to dark must persist (INV-THEME-1b)',
      );

      // Tap System option.
      await tester.tap(find.byKey(const ValueKey('theme-option-system')));
      await tester.pumpAndSettle();

      // SharedPreferences must now contain 'system'.
      expect(
        prefs.getString('theme_preference'),
        'system',
        reason: 'Changing theme back to system must persist (INV-THEME-1b)',
      );
    },
  );
}
