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
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedText = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      final error =
          StateError('Missing required dart-define: SLOCK_API_BASE_URL');

      await tester.pumpWidget(FatalBootstrapScreen(error: error));
      await tester.tap(find.byKey(const ValueKey('copy-diagnostics')));
      await tester.pumpAndSettle();

      expect(
        find.text('Diagnostics copied to clipboard'),
        findsOneWidget,
      );

      expect(copiedText, contains('Missing required dart-define'));
      expect(copiedText, contains('StateError'));
      expect(copiedText, contains('Slock Diagnostics'));
    });

    testWidgets(
        'diagnostics payload includes error type and detail for generic error',
        (tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedText = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      final error = Exception('bootstrap failed: disk full');

      await tester.pumpWidget(FatalBootstrapScreen(error: error));
      await tester.tap(find.byKey(const ValueKey('copy-diagnostics')));
      await tester.pumpAndSettle();

      expect(copiedText, contains('_Exception'));
      expect(copiedText, contains('bootstrap failed: disk full'));
    });

    testWidgets(
        'diagnostics payload uses DiagnosticLogService format with header',
        (tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedText = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      final error =
          StateError('Missing required dart-define: SLOCK_API_BASE_URL');

      await tester.pumpWidget(FatalBootstrapScreen(error: error));
      await tester.tap(find.byKey(const ValueKey('copy-diagnostics')));
      await tester.pumpAndSettle();

      // Uses DiagnosticLogService format: header + structured entry
      expect(copiedText, contains('=== Slock Diagnostics ==='));
      expect(copiedText, contains('[ERROR]'));
      expect(copiedText, contains('bootstrap'));
    });

    testWidgets('diagnostics payload includes errorType metadata',
        (tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedText = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      final error = StateError('test bootstrap failure');

      await tester.pumpWidget(FatalBootstrapScreen(error: error));
      await tester.tap(find.byKey(const ValueKey('copy-diagnostics')));
      await tester.pumpAndSettle();

      // Metadata should include error type
      expect(copiedText, contains('errorType: StateError'));
    });
  });
}
