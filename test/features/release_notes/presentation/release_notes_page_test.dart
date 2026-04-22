import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/release_notes/presentation/page/release_notes_page.dart';

void main() {
  testWidgets('release notes page shows packaged entries', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReleaseNotesPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('release-notes-list')), findsOneWidget);
    expect(find.text('Members and profile expansion landed'), findsOneWidget);
    expect(
      find.text('Search and channel management foundations landed'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Notifications and realtime groundwork stabilized'),
      200,
    );
    expect(
      find.text('Notifications and realtime groundwork stabilized'),
      findsOneWidget,
    );
  });
}
