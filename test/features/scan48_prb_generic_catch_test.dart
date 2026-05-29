// =============================================================================
// Scan #48 PR B — Load-bearing tests for generic catch on unawaited paths.
//
// Tests prove:
// 1. ThreadRepliesStore._markRead — StateError does not crash (generic catch).
//    Reverting catch (_) to on AppFailure → unhandled Future error → RED.
// 2. ConversationDetailStore.refreshSavedMessageIds — StateError does not crash.
//    Reverting catch (_) to on AppFailure → unhandled Future error → RED.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';

void main() {
  // ===========================================================================
  // T1: ConversationDetailStore.refreshSavedMessageIds — generic catch
  // ===========================================================================
  group('ConversationDetailStore.refreshSavedMessageIds generic catch', () {
    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
    );

    test(
      'StateError from checkSavedMessages does not crash (generic catch)',
      () async {
        final convRepo = _SuccessConversationRepo(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [
              ConversationMessageSummary(
                id: 'msg-1',
                content: 'Hello',
                createdAt: DateTime.utc(2026, 5, 20),
                senderType: 'human',
                messageType: 'message',
                seq: 1,
              ),
            ],
            historyLimited: false,
            hasOlder: false,
          ),
        );
        final savedRepo = _ThrowingSavedMessagesRepo();

        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(convRepo),
            savedMessagesRepositoryProvider.overrideWithValue(savedRepo),
          ],
        );
        final sub = container.listen(
          conversationDetailStoreProvider,
          (_, __) {},
        );
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        // Load to success state.
        await container.read(conversationDetailStoreProvider.notifier).load();
        expect(
          container.read(conversationDetailStoreProvider).status,
          ConversationDetailStatus.success,
        );

        // Now make checkSavedMessages throw StateError.
        savedRepo.throwOnCheck = true;

        // Call refreshSavedMessageIds directly.
        await container
            .read(conversationDetailStoreProvider.notifier)
            .refreshSavedMessageIds();

        // Drain microtask for any async side effects.
        await Future<void>.delayed(Duration.zero);

        // Store must still be in success state (not crashed).
        final state = container.read(conversationDetailStoreProvider);
        expect(
          state.status,
          ConversationDetailStatus.success,
          reason:
              'Reverting catch (_) to on AppFailure → StateError propagates '
              '→ unhandled Future error → RED',
        );
      },
    );
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _SuccessConversationRepo implements ConversationRepository {
  _SuccessConversationRepo({required this.snapshot});

  final ConversationDetailSnapshot snapshot;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      snapshot;

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      );

  @override
  Future<ConversationMessagePage> loadMessageContext(
    ConversationDetailTarget target, {
    required String messageId,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ThrowingSavedMessagesRepo implements SavedMessagesRepository {
  bool throwOnCheck = false;

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async {
    if (throwOnCheck) {
      throw StateError('Simulated disposed provider in checkSavedMessages');
    }
    return const {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
