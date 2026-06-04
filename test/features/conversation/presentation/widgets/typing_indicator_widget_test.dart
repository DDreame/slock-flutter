import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/application/typing_indicator_store.dart';
import 'package:slock_app/features/conversation/presentation/widgets/typing_indicator_widget.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  Widget buildApp({
    required TypingIndicatorState typingState,
  }) {
    return ProviderScope(
      overrides: [
        typingIndicatorStoreProvider.overrideWith(() {
          return _FixedTypingIndicatorStore(typingState);
        }),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TypingIndicatorWidget(),
        ),
      ),
    );
  }

  group('TypingIndicatorWidget', () {
    testWidgets('hidden when no one is typing', (tester) async {
      await tester.pumpWidget(
        buildApp(typingState: const TypingIndicatorState()),
      );
      // Use pump() with extra time because the animated dots have a repeating
      // animation that prevents pumpAndSettle from ever completing.
      await tester.pump(const Duration(milliseconds: 300));

      // Widget is still in tree but at zero size/opacity via SizeTransition.
      final sizeTransition = tester.widget<SizeTransition>(
        find.byType(SizeTransition),
      );
      expect(sizeTransition.sizeFactor.value, 0.0);
    });

    testWidgets('shows single typer text', (tester) async {
      await tester.pumpWidget(
        buildApp(
          typingState: const TypingIndicatorState(
            activeTypers: [ActiveTyper(userId: 'u1', displayName: 'Alice')],
          ),
        ),
      );
      // Use pump() instead of pumpAndSettle() because the animated dots
      // widget has a repeating animation that never settles.
      await tester.pump();

      expect(
        find.byKey(const ValueKey('typing-indicator')),
        findsOneWidget,
      );
      expect(find.text('Alice is typing...'), findsOneWidget);
    });

    testWidgets('shows two typers text', (tester) async {
      await tester.pumpWidget(
        buildApp(
          typingState: const TypingIndicatorState(
            activeTypers: [
              ActiveTyper(userId: 'u1', displayName: 'Alice'),
              ActiveTyper(userId: 'u2', displayName: 'Bob'),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Alice and Bob are typing...'),
        findsOneWidget,
      );
    });

    testWidgets('shows "Several people" for 3+ typers', (tester) async {
      await tester.pumpWidget(
        buildApp(
          typingState: const TypingIndicatorState(
            activeTypers: [
              ActiveTyper(userId: 'u1', displayName: 'Alice'),
              ActiveTyper(userId: 'u2', displayName: 'Bob'),
              ActiveTyper(userId: 'u3', displayName: 'Carol'),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Several people are typing...'),
        findsOneWidget,
      );
    });

    testWidgets('contains animated dots indicator', (tester) async {
      await tester.pumpWidget(
        buildApp(
          typingState: const TypingIndicatorState(
            activeTypers: [ActiveTyper(userId: 'u1', displayName: 'Alice')],
          ),
        ),
      );
      await tester.pump();

      // The animated dots indicator should be present.
      expect(
        find.byKey(const ValueKey('typing-dots')),
        findsOneWidget,
      );
    });
  });
}

class _FixedTypingIndicatorStore extends TypingIndicatorStore {
  _FixedTypingIndicatorStore(this._initialState);

  final TypingIndicatorState _initialState;

  @override
  TypingIndicatorState build() {
    ref.onDispose(() {});
    return _initialState;
  }
}
