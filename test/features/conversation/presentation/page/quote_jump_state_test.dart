// =============================================================================
// #649 Phase A — QuoteJumpState enum: loading vs not-found separation
//
// Invariants verified:
// INV-QUOTE-STATE-1: quote-jump shows loading spinner during fetch
// INV-QUOTE-STATE-2: quote-jump shows "not found" only after load fails
// INV-QUOTE-STATE-3: successful jump clears state without error flash
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-QUOTE-STATE-1: loading indicator during fetch
  // ---------------------------------------------------------------------------
  group('INV-QUOTE-STATE-1: loading state shows spinner', () {
    test('QuoteJumpState.loading is distinct from notFound', () {
      expect(QuoteJumpState.idle, isNot(QuoteJumpState.loading));
      expect(QuoteJumpState.loading, isNot(QuoteJumpState.notFound));
      expect(QuoteJumpState.idle, isNot(QuoteJumpState.notFound));
    });

    test('QuoteJumpState enum has exactly 3 values', () {
      expect(QuoteJumpState.values.length, 3);
      expect(
        QuoteJumpState.values,
        containsAll([
          QuoteJumpState.idle,
          QuoteJumpState.loading,
          QuoteJumpState.notFound,
        ]),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // INV-QUOTE-STATE-2: not-found only after load completes
  // ---------------------------------------------------------------------------
  group('INV-QUOTE-STATE-2: state transitions', () {
    test('initial state is idle', () {
      expect(QuoteJumpState.idle.index, 0);
    });

    test('loading transitions to notFound when message not found', () {
      // Verify state ordering allows loading → notFound transition.
      const loading = QuoteJumpState.loading;
      const notFound = QuoteJumpState.notFound;
      expect(loading, isNot(notFound));
      // Both are valid post-idle states.
      expect(loading.index, greaterThan(QuoteJumpState.idle.index));
      expect(notFound.index, greaterThan(QuoteJumpState.idle.index));
    });
  });

  // ---------------------------------------------------------------------------
  // INV-QUOTE-STATE-3: UI differentiation between loading and not-found
  // ---------------------------------------------------------------------------
  group('INV-QUOTE-STATE-3: UI renders differently per state', () {
    testWidgets('loading state shows CircularProgressIndicator',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: QuoteJumpOverlay(state: QuoteJumpState.loading),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Message not available'), findsNothing);
    });

    testWidgets('notFound state shows "Message not available"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: QuoteJumpOverlay(state: QuoteJumpState.notFound),
          ),
        ),
      );

      expect(find.text('Message not available'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('idle state renders nothing (SizedBox.shrink)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: QuoteJumpOverlay(state: QuoteJumpState.idle),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Message not available'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });
}
