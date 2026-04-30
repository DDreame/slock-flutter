import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/fatal_bootstrap_screen.dart';

void main() {
  group('FatalBootstrapScreen', () {
    testWidgets('shows friendly message for missing dart-define error',
        (tester) async {
      final error =
          StateError('Missing required dart-define: SLOCK_API_BASE_URL');

      await tester.pumpWidget(FatalBootstrapScreen(error: error));

      expect(find.text('Unable to Start'), findsOneWidget);
      expect(
        find.textContaining('missing required configuration'),
        findsOneWidget,
      );
      expect(
        find.textContaining('--dart-define'),
        findsOneWidget,
      );
      // Raw error NOT shown on screen
      expect(
        find.text(error.toString()),
        findsNothing,
      );
    });

    testWidgets('shows friendly message for generic error', (tester) async {
      final error = Exception('network timeout during bootstrap');

      await tester.pumpWidget(FatalBootstrapScreen(error: error));

      expect(find.text('Unable to Start'), findsOneWidget);
      expect(
        find.textContaining('Something went wrong during startup'),
        findsOneWidget,
      );
      // Raw error NOT shown on screen
      expect(
        find.text(error.toString()),
        findsNothing,
      );
    });

    testWidgets('shows warning icon', (tester) async {
      await tester.pumpWidget(
        FatalBootstrapScreen(error: StateError('test')),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('has copy diagnostics button', (tester) async {
      await tester.pumpWidget(
        FatalBootstrapScreen(error: StateError('test')),
      );

      expect(find.byKey(const ValueKey('copy-diagnostics')), findsOneWidget);
      expect(find.text('Copy diagnostics'), findsOneWidget);
    });

    testWidgets('copy diagnostics copies error details to clipboard',
        (tester) async {
      final error =
          StateError('Missing required dart-define: SLOCK_API_BASE_URL');

      await tester.pumpWidget(FatalBootstrapScreen(error: error));

      // Tap the copy button
      await tester.tap(find.byKey(const ValueKey('copy-diagnostics')));
      await tester.pumpAndSettle();

      // Verify snackbar appears
      expect(
        find.text('Diagnostics copied to clipboard'),
        findsOneWidget,
      );

      // Verify clipboard content includes the error detail
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, contains('Missing required dart-define'));
      expect(clipboardData?.text, contains('StateError'));
      expect(clipboardData?.text, contains('Slock Diagnostics'));
    });

    testWidgets(
        'diagnostics payload includes error type and detail for generic error',
        (tester) async {
      final error = Exception('bootstrap failed: disk full');

      await tester.pumpWidget(FatalBootstrapScreen(error: error));

      await tester.tap(find.byKey(const ValueKey('copy-diagnostics')));
      await tester.pumpAndSettle();

      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboardData?.text, contains('_Exception'));
      expect(clipboardData?.text, contains('bootstrap failed: disk full'));
    });
  });
}
