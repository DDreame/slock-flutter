import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/widgets/friendly_error_state.dart';

void main() {
  group('FriendlyErrorState', () {
    testWidgets('renders error icon, title, message and retry button', (
      tester,
    ) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendlyErrorState(
              title: 'Load failed',
              message: 'Could not fetch data.',
              onRetry: () async {
                retried = true;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Load failed'), findsOneWidget);
      expect(find.text('Could not fetch data.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('hides share diagnostics button when callback is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendlyErrorState(
              title: 'Error',
              message: 'Something went wrong.',
              onRetry: () async {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('error-share-diagnostics')),
        findsNothing,
      );
    });

    testWidgets('shows share diagnostics button when callback is provided', (
      tester,
    ) async {
      var shareTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendlyErrorState(
              title: 'Error',
              message: 'Something went wrong.',
              onRetry: () async {},
              onShareDiagnostics: () {
                shareTapped = true;
              },
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('error-share-diagnostics')),
        findsOneWidget,
      );
      expect(find.text('Share diagnostics'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('error-share-diagnostics')),
      );
      await tester.pump();

      expect(shareTapped, isTrue);
    });

    testWidgets('share diagnostics button shows bug report icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendlyErrorState(
              title: 'Error',
              message: 'Something went wrong.',
              onRetry: () async {},
              onShareDiagnostics: () {},
            ),
          ),
        ),
      );

      // The share diagnostics button should have a bug report icon
      final button = find.byKey(const ValueKey('error-share-diagnostics'));
      expect(button, findsOneWidget);
      expect(
        find.descendant(
          of: button,
          matching: find.byIcon(Icons.bug_report_outlined),
        ),
        findsOneWidget,
      );
    });
  });
}
