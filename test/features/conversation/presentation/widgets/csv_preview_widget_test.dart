import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/csv_preview_widget.dart';

void main() {
  testWidgets('CSV preview shows loading then table on success (INV-ATTACH-1)',
      (tester) async {
    // Use a data URI to avoid real HTTP calls.
    final attachment = MessageAttachment(
      name: 'data.csv',
      type: 'text/csv',
      url: 'data:text/csv,Name%2CAge%0AAlice%2C30%0ABob%2C25',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CsvPreviewWidget(attachment: attachment),
        ),
      ),
    );

    // Initially shows loading state.
    expect(find.byKey(ValueKey('csv-loading-data.csv')), findsOneWidget);
  });

  testWidgets('CSV preview shows fallback when no URL (INV-ATTACH-2)',
      (tester) async {
    final attachment = MessageAttachment(
      name: 'broken.csv',
      type: 'text/csv',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CsvPreviewWidget(attachment: attachment),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should show fallback with error.
    expect(find.byKey(ValueKey('csv-fallback-broken.csv')), findsOneWidget);
    expect(find.text('No download URL'), findsOneWidget);
  });
}
