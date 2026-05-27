import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/application/typing_indicator_store.dart';

void main() {
  late ProviderContainer container;
  // Keep a listener alive so AutoDispose doesn't reclaim during async tests.
  ProviderSubscription<TypingIndicatorState>? sub;

  setUp(() {
    container = ProviderContainer();
    sub = container.listen(typingIndicatorStoreProvider, (_, __) {});
  });

  tearDown(() {
    sub?.close();
    container.dispose();
  });

  group('TypingIndicatorStore', () {
    test('initial state has no active typers', () {
      final state = container.read(typingIndicatorStoreProvider);
      expect(state.activeTypers, isEmpty);
    });

    test('addTyper adds a user to active typers', () {
      container.read(typingIndicatorStoreProvider.notifier).addTyper(
            userId: 'user-1',
            displayName: 'Alice',
          );

      final state = container.read(typingIndicatorStoreProvider);
      expect(state.activeTypers, hasLength(1));
      expect(state.activeTypers.first.userId, 'user-1');
      expect(state.activeTypers.first.displayName, 'Alice');
    });

    test('addTyper with same userId resets expiry without duplicating', () {
      final notifier = container.read(typingIndicatorStoreProvider.notifier);
      notifier.addTyper(userId: 'user-1', displayName: 'Alice');
      notifier.addTyper(userId: 'user-1', displayName: 'Alice');

      final state = container.read(typingIndicatorStoreProvider);
      expect(state.activeTypers, hasLength(1));
    });

    test('removeTyper removes a user from active typers', () {
      final notifier = container.read(typingIndicatorStoreProvider.notifier);
      notifier.addTyper(userId: 'user-1', displayName: 'Alice');
      notifier.removeTyper('user-1');

      final state = container.read(typingIndicatorStoreProvider);
      expect(state.activeTypers, isEmpty);
    });

    test('removeTyper on unknown userId is a no-op', () {
      final notifier = container.read(typingIndicatorStoreProvider.notifier);
      notifier.addTyper(userId: 'user-1', displayName: 'Alice');
      notifier.removeTyper('user-unknown');

      final state = container.read(typingIndicatorStoreProvider);
      expect(state.activeTypers, hasLength(1));
    });

    test('typer auto-expires after timeout', () async {
      final notifier = container.read(typingIndicatorStoreProvider.notifier);
      notifier.addTyper(
        userId: 'user-1',
        displayName: 'Alice',
        expiry: const Duration(milliseconds: 50),
      );

      expect(
        container.read(typingIndicatorStoreProvider).activeTypers,
        hasLength(1),
      );

      // Wait for expiry.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        container.read(typingIndicatorStoreProvider).activeTypers,
        isEmpty,
      );
    });

    test('addTyper resets expiry timer on repeat call', () async {
      final notifier = container.read(typingIndicatorStoreProvider.notifier);
      notifier.addTyper(
        userId: 'user-1',
        displayName: 'Alice',
        expiry: const Duration(milliseconds: 200),
      );

      // Wait 100ms, then refresh.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      notifier.addTyper(
        userId: 'user-1',
        displayName: 'Alice',
        expiry: const Duration(milliseconds: 200),
      );

      // At 200ms total, the original timer would have expired, but the
      // refreshed timer should still be active (only 100ms since refresh).
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        container.read(typingIndicatorStoreProvider).activeTypers,
        hasLength(1),
      );

      // Wait for the refreshed timer to expire.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(
        container.read(typingIndicatorStoreProvider).activeTypers,
        isEmpty,
      );
    });

    test('clearAll removes all typers', () {
      final notifier = container.read(typingIndicatorStoreProvider.notifier);
      notifier.addTyper(userId: 'user-1', displayName: 'Alice');
      notifier.addTyper(userId: 'user-2', displayName: 'Bob');
      notifier.clearAll();

      final state = container.read(typingIndicatorStoreProvider);
      expect(state.activeTypers, isEmpty);
    });
  });

  group('send debounce', () {
    test('notifyTyping is true initially, then throttled', () {
      final notifier = container.read(typingIndicatorStoreProvider.notifier);

      // First call should allow sending.
      expect(notifier.shouldEmitTyping(), isTrue);

      // Immediately after, should be throttled.
      expect(notifier.shouldEmitTyping(), isFalse);
    });

    test('notifyTyping re-enables after cooldown expires', () async {
      final notifier = container.read(typingIndicatorStoreProvider.notifier);

      expect(
          notifier.shouldEmitTyping(
            cooldown: const Duration(milliseconds: 50),
          ),
          isTrue);
      expect(
          notifier.shouldEmitTyping(
            cooldown: const Duration(milliseconds: 50),
          ),
          isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(
          notifier.shouldEmitTyping(
            cooldown: const Duration(milliseconds: 50),
          ),
          isTrue);
    });
  });
}
