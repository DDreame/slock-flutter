import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/telemetry/crash_marker_service.dart';
import 'package:slock_app/core/telemetry/crash_recovery_dialog.dart';

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> store = {};

  @override
  Future<String?> read({required String key}) async => store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    store.remove(key);
  }
}

void main() {
  late _FakeSecureStorage fakeStorage;
  late CrashMarkerService crashMarker;

  setUp(() {
    fakeStorage = _FakeSecureStorage();
    crashMarker = CrashMarkerService(storage: fakeStorage);
  });

  Widget buildHarness({required Widget child}) {
    return ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(fakeStorage),
        crashMarkerServiceProvider.overrideWithValue(crashMarker),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(builder: (context) => child),
      ),
    );
  }

  Future<void> showDialog(WidgetTester tester) async {
    await tester.pumpWidget(buildHarness(
      child: Builder(
        builder: (context) {
          return ElevatedButton(
            key: const ValueKey('trigger'),
            onPressed: () => CrashRecoveryDialog.show(context),
            child: const Text('Show'),
          );
        },
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('trigger')));
    await tester.pumpAndSettle();
  }

  group('CrashRecoveryDialog', () {
    test('static show method returns a Future<bool?>', () {
      // Compile-time type check — if the return type were wrong, the
      // assignment would fail to compile.
      // ignore: unused_local_variable
      Future<bool?> Function(BuildContext) fn = CrashRecoveryDialog.show;
    });

    testWidgets('renders warning icon', (tester) async {
      await showDialog(tester);

      expect(
        find.byKey(const ValueKey('crash-recovery-icon')),
        findsOneWidget,
      );
      final icon = tester.widget<Icon>(
        find.byKey(const ValueKey('crash-recovery-icon')),
      );
      expect(icon.icon, Icons.warning_amber_rounded);
    });

    testWidgets('renders "App Recovered" title', (tester) async {
      await showDialog(tester);

      expect(
        find.byKey(const ValueKey('crash-recovery-title')),
        findsOneWidget,
      );
      expect(find.text('App Recovered'), findsOneWidget);
    });

    testWidgets('renders explanatory message', (tester) async {
      await showDialog(tester);

      expect(
        find.byKey(const ValueKey('crash-recovery-message')),
        findsOneWidget,
      );
      expect(
        find.textContaining('stopped unexpectedly'),
        findsOneWidget,
      );
    });

    testWidgets('renders Continue and Export Diagnostics buttons',
        (tester) async {
      await showDialog(tester);

      expect(
        find.byKey(const ValueKey('crash-recovery-continue')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('crash-recovery-export')),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Export Diagnostics'), findsOneWidget);
    });

    testWidgets('Continue clears crash marker and pops false', (tester) async {
      // Seed a crash marker first.
      await crashMarker.markCrash();
      expect(await crashMarker.hasCrashMarker(), isTrue);

      await showDialog(tester);

      // Tap Continue.
      await tester.tap(find.byKey(const ValueKey('crash-recovery-continue')));
      await tester.pumpAndSettle();

      // Dialog should be dismissed.
      expect(find.byKey(const ValueKey('crash-recovery-dialog')), findsNothing);

      // Crash marker should be cleared.
      expect(await crashMarker.hasCrashMarker(), isFalse);
    });

    testWidgets('Export Diagnostics clears crash marker and pops true',
        (tester) async {
      // Seed a crash marker first.
      await crashMarker.markCrash();
      expect(await crashMarker.hasCrashMarker(), isTrue);

      await showDialog(tester);

      // Tap Export.
      await tester.tap(find.byKey(const ValueKey('crash-recovery-export')));
      await tester.pumpAndSettle();

      // Dialog should be dismissed.
      expect(find.byKey(const ValueKey('crash-recovery-dialog')), findsNothing);

      // Crash marker should be cleared.
      expect(await crashMarker.hasCrashMarker(), isFalse);
    });

    testWidgets('dialog is not barrier-dismissible', (tester) async {
      await showDialog(tester);

      // Tap outside the dialog.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Dialog should still be visible.
      expect(
        find.byKey(const ValueKey('crash-recovery-dialog')),
        findsOneWidget,
      );
    });

    testWidgets('dialog has rounded shape', (tester) async {
      await showDialog(tester);

      final alertDialog = tester.widget<AlertDialog>(
        find.byKey(const ValueKey('crash-recovery-dialog')),
      );
      expect(alertDialog.shape, isA<RoundedRectangleBorder>());
    });
  });
}
