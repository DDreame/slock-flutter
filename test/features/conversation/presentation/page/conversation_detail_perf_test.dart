// =============================================================================
// #651 — Conversation Detail Perf: attachment download guard + GlobalKeys eviction
//
// Invariants verified:
// INV-ATTACH-GUARD-1: _registerAttachmentDownloads does NOT fire on
//                     non-message state changes (same message count)
// INV-KEYS-EVICT-1: _messageGlobalKeys stays bounded after pagination
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    ConversationDetailPage.debugAttachmentRegistrationCount = 0;
  });

  // ---------------------------------------------------------------------------
  // INV-ATTACH-GUARD-1: Attachment registration fires only on message changes
  // ---------------------------------------------------------------------------
  group('INV-ATTACH-GUARD-1: attachment download guard', () {
    testWidgets(
      'fires on initial load (messages appear)',
      (tester) async {
        final store = _ControllableConversationDetailStore(
          initialMessages: _makeMessages(3),
        );

        await tester.pumpWidget(_buildApp(store: store, prefs: prefs));
        await tester.pumpAndSettle();

        // Should have fired exactly once on initial load.
        expect(
          ConversationDetailPage.debugAttachmentRegistrationCount,
          1,
          reason: 'Should fire once on initial load '
              '(INV-ATTACH-GUARD-1)',
        );
      },
    );

    testWidgets(
      'does NOT re-fire when message count is unchanged '
      '(reaction/typing state change)',
      (tester) async {
        final store = _ControllableConversationDetailStore(
          initialMessages: _makeMessages(3),
        );

        await tester.pumpWidget(_buildApp(store: store, prefs: prefs));
        await tester.pumpAndSettle();

        final countAfterLoad =
            ConversationDetailPage.debugAttachmentRegistrationCount;
        expect(countAfterLoad, 1,
            reason: 'Initial load should fire once');

        // Simulate a non-message state emission (e.g. typing indicator,
        // reaction update, isRefreshing toggle). The store emits a new state
        // with the SAME messages but different metadata.
        store.emitNonMessageChange();
        await tester.pump();

        // Should NOT have fired again (same message count).
        expect(
          ConversationDetailPage.debugAttachmentRegistrationCount,
          countAfterLoad,
          reason: 'Must NOT re-fire when message count is unchanged '
              '(INV-ATTACH-GUARD-1)',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-KEYS-EVICT-1: GlobalKeys eviction keeps map bounded
  // ---------------------------------------------------------------------------
  group('INV-KEYS-EVICT-1: GlobalKeys eviction', () {
    testWidgets(
      'keys are bounded after messages shrink (messages.length + 20)',
      (tester) async {
        // Start with 50 messages to build up keys.
        final store = _ControllableConversationDetailStore(
          initialMessages: _makeMessages(50),
        );

        await tester.pumpWidget(_buildApp(store: store, prefs: prefs));
        await tester.pumpAndSettle();

        final keyCountAfterLoad =
            ConversationDetailPage.debugMessageGlobalKeyCount?.call() ?? 0;
        expect(keyCountAfterLoad, greaterThan(0),
            reason: 'Should have created keys for visible messages');

        // Now simulate state emission with fewer messages (pagination shrink).
        // The eviction guard fires when keys > messages.length + 20.
        // With 50 keys accumulated and only 5 messages in new state,
        // 50 > 5 + 20 = true, so eviction runs.
        store.emitNewMessages(_makeMessages(5));
        await tester.pump();

        final keyCountAfterShrink =
            ConversationDetailPage.debugMessageGlobalKeyCount?.call() ?? 0;

        // Production guard: evicts keys not in current message set.
        // After eviction, only keys matching the 5 current messages remain.
        // Assert tight bound: messages.length + 20 = 25.
        expect(
          keyCountAfterShrink,
          lessThanOrEqualTo(25),
          reason: 'GlobalKeys must be bounded to messages.length + 20 '
              'after eviction (INV-KEYS-EVICT-1)',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _target = ConversationDetailTarget.channel(
  const ChannelScopeId(
    serverId: ServerScopeId('server-1'),
    value: 'ch-1',
  ),
);

List<ConversationMessageSummary> _makeMessages(int count) {
  return List.generate(
    count,
    (i) => ConversationMessageSummary(
      id: 'msg-$i',
      content: 'Message $i',
      createdAt: DateTime.parse('2026-05-16T14:00:00Z').add(
        Duration(minutes: i),
      ),
      senderType: 'human',
      messageType: 'message',
      seq: i + 1,
    ),
  );
}

Widget _buildApp({
  required _ControllableConversationDetailStore store,
  required SharedPreferences prefs,
}) {
  return ProviderScope(
    overrides: [
      conversationDetailStoreProvider.overrideWith(() => store),
      conversationDetailSessionStoreProvider
          .overrideWith(() => _FakeConversationDetailSessionStore()),
      voiceMessageStoreProvider.overrideWith(() => _FakeVoiceMessageStore()),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      sharedPreferencesProvider.overrideWithValue(prefs),
      realtimeReductionIngressProvider
          .overrideWithValue(RealtimeReductionIngress()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: ConversationDetailPage(
        target: _target,
        registerOpenTarget: false,
      ),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// A controllable store that starts with given messages (status=success)
/// and allows explicit state emissions for testing guards.
class _ControllableConversationDetailStore extends ConversationDetailStore {
  _ControllableConversationDetailStore({
    required this.initialMessages,
  });

  final List<ConversationMessageSummary> initialMessages;

  @override
  ConversationDetailState build() => ConversationDetailState(
        target: _target,
        status: ConversationDetailStatus.success,
        messages: initialMessages,
      );

  @override
  Future<void> ensureLoaded() async {
    // Already loaded via build().
  }

  @override
  Future<void> refresh({String reason = 'manual'}) async {}

  @override
  Future<void> loadOlder() async {}

  @override
  Future<void> loadNewer() async {}

  /// Emit a state change that does NOT alter messages (simulates typing,
  /// reaction update, or refresh status toggle). This is the exact scenario
  /// where the attachment guard must NOT fire.
  void emitNonMessageChange() {
    state = state.copyWith(isRefreshing: !state.isRefreshing);
  }

  /// Emit a state change with a new message list (simulates pagination
  /// or message removal). Triggers the eviction guard if key count exceeds
  /// messages.length + 20.
  void emitNewMessages(List<ConversationMessageSummary> messages) {
    state = state.copyWith(messages: messages);
  }
}

class _FakeConversationDetailSessionStore
    extends ConversationDetailSessionStore {
  @override
  Map<ConversationDetailTarget, ConversationDetailSessionEntry> build() =>
      const {};
}

class _FakeVoiceMessageStore extends VoiceMessageStore {
  @override
  VoiceMessageState build() => const VoiceMessageState();
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Alice',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}
