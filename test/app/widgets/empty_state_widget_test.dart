import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/widgets/empty_state_widget.dart';

void main() {
  group('EmptyStateWidget', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox_outlined,
              title: 'Nothing here',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
    });

    testWidgets('renders optional subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.bookmark_outline,
              title: 'No saved messages',
              subtitle: 'Save messages for quick access.',
            ),
          ),
        ),
      );

      expect(find.text('No saved messages'), findsOneWidget);
      expect(find.text('Save messages for quick access.'), findsOneWidget);
    });

    testWidgets('does not render subtitle when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox_outlined,
              title: 'Empty',
            ),
          ),
        ),
      );

      // Only icon + title — no Text widget beyond the title.
      expect(find.text('Empty'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders optional action widget', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.search_off,
              title: 'No results',
              action: ElevatedButton(
                onPressed: () => tapped = true,
                child: const Text('Clear filters'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Clear filters'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('is centered vertically', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox_outlined,
              title: 'Empty',
            ),
          ),
        ),
      );

      // Our Center wraps a Padding > Column containing the icon.
      expect(
        find.ancestor(
          of: find.byIcon(Icons.inbox_outlined),
          matching: find.byType(Center),
        ),
        findsOneWidget,
      );
    });
  });
}
