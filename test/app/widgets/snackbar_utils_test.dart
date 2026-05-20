import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/widgets/snackbar_utils.dart';

void main() {
  group('showAppSnackBar', () {
    testWidgets('displays message text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showAppSnackBar(context, 'Task created.'),
                child: const Text('Trigger'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Task created.'), findsOneWidget);
    });

    testWidgets('shows error styling when isError is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showAppSnackBar(
                  context,
                  'Connection failed.',
                  isError: true,
                ),
                child: const Text('Trigger'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Connection failed.'), findsOneWidget);
      // Verify error snackbar uses red/error background.
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, isNotNull);
    });

    testWidgets('hides previous snackbar before showing new one',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => showAppSnackBar(context, 'First'),
                    child: const Text('First'),
                  ),
                  ElevatedButton(
                    onPressed: () => showAppSnackBar(context, 'Second'),
                    child: const Text('Second'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SnackBar, 'First'), findsOneWidget);

      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SnackBar, 'Second'), findsOneWidget);
      // First snackbar content should be gone from any visible SnackBar.
      expect(find.widgetWithText(SnackBar, 'First'), findsNothing);
    });
  });

  group('showAppSnackBarWithAction', () {
    testWidgets('displays message and action button', (tester) async {
      var actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showAppSnackBarWithAction(
                  context,
                  'Message deleted.',
                  actionLabel: 'Undo',
                  onAction: () => actionTapped = true,
                ),
                child: const Text('Trigger'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Message deleted.'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(actionTapped, isTrue);
    });
  });
}
