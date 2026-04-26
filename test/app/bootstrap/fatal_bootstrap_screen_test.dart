import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/fatal_bootstrap_screen.dart';

void main() {
  testWidgets('renders error message', (tester) async {
    final error =
        StateError('Missing required dart-define: SLOCK_API_BASE_URL');

    await tester.pumpWidget(FatalBootstrapScreen(error: error));

    expect(find.text('App Failed to Start'), findsOneWidget);
    expect(
      find.textContaining('Missing required dart-define: SLOCK_API_BASE_URL'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Try restarting the app'),
      findsOneWidget,
    );
  });

  testWidgets('renders generic exception', (tester) async {
    final error = Exception('network timeout during bootstrap');

    await tester.pumpWidget(FatalBootstrapScreen(error: error));

    expect(find.text('App Failed to Start'), findsOneWidget);
    expect(
      find.textContaining('network timeout during bootstrap'),
      findsOneWidget,
    );
  });

  testWidgets('shows error icon', (tester) async {
    await tester.pumpWidget(
      FatalBootstrapScreen(error: StateError('test')),
    );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
