// =============================================================================
// Scan #50 — Load-bearing test for outbox queue capacity limit.
//
// Proves:
// 1. enqueue rejects the 51st message for a target (returns false).
// 2. Queue holds exactly maxOutboxItemsPerTarget items after fill.
// 3. After removing an item, enqueue succeeds again.
// 4. Different targets have independent capacities.
// 5. Dedup (existing localId) still returns true even when full.
//
// Reverting the capacity check in OutboxStore.enqueue → allows unbounded
// growth → tests RED.
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart'
    show conversationRepositoryProvider;
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  late ProviderContainer container;
  late StreamController<ConnectivityStatus> connectivityController;

  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  final target2 = ConversationDetailTarget.directMessage(
    const DirectMessageScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'dm-1',
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    connectivityController = StreamController<ConnectivityStatus>.broadcast();
    // Start offline so drainAll doesn't fire.
    final connectivityService = ConnectivityService.withInitialStatus(
      ConnectivityStatus.offline,
      controller: connectivityController,
    );

    container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider
            .overrideWithValue(_FakeConversationRepository()),
        connectivityServiceProvider.overrideWithValue(connectivityService),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    await connectivityController.close();
  });

  group('Outbox queue capacity limit', () {
    test('enqueue rejects 51st message for same target (returns false)', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      // Fill queue to capacity.
      for (var i = 0; i < maxOutboxItemsPerTarget; i++) {
        final result = notifier.enqueue(target, 'msg-$i', localId: 'id-$i');
        expect(result, isTrue, reason: 'Item $i should enqueue successfully');
      }

      // Verify queue is at capacity.
      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey], hasLength(maxOutboxItemsPerTarget));

      // 51st message should be rejected.
      final rejected = notifier.enqueue(target, 'overflow', localId: 'id-50');
      expect(
        rejected,
        isFalse,
        reason: 'Reverting capacity check → unbounded growth → RED. '
            'enqueue must return false when queue is at capacity.',
      );

      // Queue size unchanged.
      final afterState = container.read(outboxStoreProvider);
      expect(afterState.items[targetKey], hasLength(maxOutboxItemsPerTarget));
    });

    test('after removing an item, enqueue succeeds again', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      // Fill to capacity.
      for (var i = 0; i < maxOutboxItemsPerTarget; i++) {
        notifier.enqueue(target, 'msg-$i', localId: 'id-$i');
      }

      // Remove one item.
      notifier.removeItem(target, 'id-0');

      // Now enqueue should succeed.
      final result = notifier.enqueue(target, 'new-msg', localId: 'id-new');
      expect(result, isTrue);

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey], hasLength(maxOutboxItemsPerTarget));
    });

    test('different targets have independent capacities', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      // Fill target1 to capacity.
      for (var i = 0; i < maxOutboxItemsPerTarget; i++) {
        notifier.enqueue(target, 'msg-$i', localId: 'ch-$i');
      }

      // Target2 should still accept messages.
      final result = notifier.enqueue(target2, 'dm-msg', localId: 'dm-0');
      expect(result, isTrue);

      // Target1 should still reject.
      final rejected =
          notifier.enqueue(target, 'overflow', localId: 'ch-overflow');
      expect(rejected, isFalse);
    });

    test('dedup localId returns true even when queue is full', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      // Fill to capacity.
      for (var i = 0; i < maxOutboxItemsPerTarget; i++) {
        notifier.enqueue(target, 'msg-$i', localId: 'id-$i');
      }

      // Re-enqueue an existing localId — dedup returns true (not an error).
      final result = notifier.enqueue(target, 'msg-0', localId: 'id-0');
      expect(
        result,
        isTrue,
        reason: 'Dedup of existing localId is not a rejection — returns true',
      );
    });

    test('maxOutboxItemsPerTarget is 50', () {
      // This test documents the constant value. If someone changes it,
      // this test forces a conscious decision.
      expect(maxOutboxItemsPerTarget, 50);
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeConversationRepository implements ConversationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
