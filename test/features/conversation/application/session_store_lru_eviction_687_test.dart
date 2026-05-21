// ignore_for_file: prefer_const_constructors

// =============================================================================
// #687 — ConversationDetailSessionStore LRU eviction test
//
// Tests that the session store caps at maxEntries (8) and evicts the
// oldest-accessed entry when a 9th is inserted.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  ConversationDetailState makeState(int index) {
    final target = ConversationDetailTarget.channel(
      ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'channel-$index',
      ),
    );
    return ConversationDetailState(
      target: target,
      status: ConversationDetailStatus.success,
      title: 'Channel $index',
      messages: [
        ConversationMessageSummary(
          id: 'msg-$index',
          content: 'Message in channel $index',
          createdAt: DateTime(2026, 5, 21, 12, index),
          senderType: 'human',
          messageType: 'message',
          seq: index,
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    );
  }

  group('#687 — ConversationDetailSessionStore LRU eviction', () {
    test('stores up to maxEntries without eviction', () {
      final store =
          container.read(conversationDetailSessionStoreProvider.notifier);

      // Insert exactly maxEntries (8) entries.
      for (var i = 1; i <= ConversationDetailSessionStore.maxEntries; i++) {
        store.saveSuccessState(makeState(i), scrollOffset: 0.0);
      }

      final state = container.read(conversationDetailSessionStoreProvider);
      expect(
        state.length,
        ConversationDetailSessionStore.maxEntries,
        reason: 'Should store exactly maxEntries without eviction',
      );
    });

    test('9th insert evicts oldest (first-inserted) entry', () {
      final store =
          container.read(conversationDetailSessionStoreProvider.notifier);

      // Insert 8 entries (channels 1-8).
      for (var i = 1; i <= 8; i++) {
        store.saveSuccessState(makeState(i), scrollOffset: 0.0);
      }

      // Insert 9th entry — should evict channel-1 (oldest).
      store.saveSuccessState(makeState(9), scrollOffset: 0.0);

      final state = container.read(conversationDetailSessionStoreProvider);
      expect(state.length, 8, reason: 'Should cap at maxEntries');

      // channel-1 should be evicted.
      final channel1Target = ConversationDetailTarget.channel(
        ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'channel-1',
        ),
      );
      expect(
        state.containsKey(channel1Target),
        isFalse,
        reason: 'Oldest entry (channel-1) should be evicted',
      );

      // channel-9 (newest) should be present.
      final channel9Target = ConversationDetailTarget.channel(
        ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'channel-9',
        ),
      );
      expect(
        state.containsKey(channel9Target),
        isTrue,
        reason: 'Newest entry (channel-9) should be present',
      );
    });

    test('re-saving existing entry promotes it (not evicted on overflow)', () {
      final store =
          container.read(conversationDetailSessionStoreProvider.notifier);

      // Insert 8 entries (channels 1-8).
      for (var i = 1; i <= 8; i++) {
        store.saveSuccessState(makeState(i), scrollOffset: 0.0);
      }

      // Re-save channel-1 — this should promote it to most-recent.
      store.saveSuccessState(makeState(1), scrollOffset: 100.0);

      // Insert 9th entry — should evict channel-2 (now oldest), NOT channel-1.
      store.saveSuccessState(makeState(9), scrollOffset: 0.0);

      final state = container.read(conversationDetailSessionStoreProvider);
      expect(state.length, 8);

      final channel1Target = ConversationDetailTarget.channel(
        ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'channel-1',
        ),
      );
      final channel2Target = ConversationDetailTarget.channel(
        ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'channel-2',
        ),
      );

      expect(
        state.containsKey(channel1Target),
        isTrue,
        reason: 'Re-saved entry should be promoted (not evicted)',
      );
      expect(
        state.containsKey(channel2Target),
        isFalse,
        reason: 'Next-oldest entry should be evicted instead',
      );
    });

    test('non-success state is not stored', () {
      final store =
          container.read(conversationDetailSessionStoreProvider.notifier);

      final target = ConversationDetailTarget.channel(
        ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'channel-loading',
        ),
      );
      final loadingState = ConversationDetailState(
        target: target,
        status: ConversationDetailStatus.loading,
        title: null,
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      );

      store.saveSuccessState(loadingState, scrollOffset: 0.0);

      final state = container.read(conversationDetailSessionStoreProvider);
      expect(state, isEmpty, reason: 'Non-success state should not be stored');
    });
  });
}
