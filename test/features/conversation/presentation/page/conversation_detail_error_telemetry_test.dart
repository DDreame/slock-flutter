// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:dio/dio.dart';

// ---------------------------------------------------------------------------
// #562 Phase A — Silent Error → Diagnostic Telemetry (ConversationDetail)
//
// Verifies that silent catch blocks in ConversationDetailPage methods
// route errors to DiagnosticsCollector instead of swallowing silently.
//
// INV-TELEM-9: sender profile fetch failure → logged + no crash
// INV-TELEM-10: DM open failure → logged + no crash
//
// Trigger paths (verified against production source):
//   - _openSenderProfile (line 2353): tap sender name → loadProfile()
//   - _openDirectMessage (line 2384): called from profile sheet's
//     "Message" button (key 'member-profile-dm-action' in
//     member_profile_sheet.dart:172), wired via onMessageTap callback
//     in _openSenderProfile (line 2371-2375).
//
// Phase A — all tests skip: true.
// ---------------------------------------------------------------------------

void main() {
  group('ConversationDetailPage error telemetry', () {
    testWidgets(
      'sender profile fetch failure → logged + no crash (INV-TELEM-9)',
      (tester) async {
        // Setup: Render ConversationDetailPage with a message from a
        // non-self sender. profileRepository.loadProfile throws.
        // Tap the sender name to trigger _openSenderProfile.
        //
        // Assert:
        //   - diagnosticsCollector has error entry with
        //     tag='ConversationDetail', message contains 'profile'
        //   - Widget remains mounted (no crash)
        //
        // Currently _openSenderProfile (line 2378) has:
        //   catch (_) { // Fail-soft: if profile fetch fails, do nothing. }
        // Phase B will add diagnostics.error(...) in that catch.
        final diagnostics = DiagnosticsCollector();
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-1',
          ),
        );

        await tester.pumpWidget(
          _buildApp(
            target: target,
            diagnostics: diagnostics,
            conversationRepository: _FakeConversationRepository(
              snapshot: _makeSnapshot(target),
            ),
            profileRepository: _ThrowingProfileRepository(),
            memberRepository: const _FakeMemberRepository(),
          ),
        );
        await tester.pumpAndSettle();

        // Locate the sender name "Alice" and tap it to trigger
        // _openSenderProfile → loadProfile() throws → catch block fires.
        final senderLabel = find.text('Alice');
        expect(senderLabel, findsOneWidget,
            reason: 'Sender name must be rendered');
        await tester.tap(senderLabel);
        // Advance clock past the 300 ms double-tap window in
        // MessageGestureWrapper so onTap fires → _handleMessageTap →
        // _openSenderProfile. Raw Timer does not schedule frames, so
        // pumpAndSettle() alone cannot advance past it.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Widget must remain mounted after the failure.
        expect(find.byType(ConversationDetailPage), findsOneWidget,
            reason: 'Page must remain mounted after profile fetch failure');

        // DiagnosticsCollector must have an error entry.
        expect(
          diagnostics.entries.any(
            (e) =>
                e.tag == 'ConversationDetail' &&
                e.level == DiagnosticsLevel.error &&
                e.message.toLowerCase().contains('profile'),
          ),
          isTrue,
          reason:
              'Profile fetch failure must be logged to diagnostics (INV-TELEM-9)',
        );
      },
    );

    testWidgets(
      'DM open failure → logged + no crash (INV-TELEM-10)',
      (tester) async {
        // Setup: Render ConversationDetailPage with a message from a
        // non-self sender.
        //   - profileRepository succeeds → profile sheet opens
        //   - memberRepository.openDirectMessage throws
        //
        // Trigger path (matches production wiring):
        //   1. Tap sender name → _openSenderProfile → loadProfile succeeds
        //   2. Profile sheet appears with "Message" button
        //      (key 'member-profile-dm-action', member_profile_sheet.dart:172)
        //   3. Tap "Message" → onMessageTap → _openDirectMessage → throws
        //   4. _openDirectMessage catch (line 2396) fires
        //
        // Assert:
        //   - diagnosticsCollector has error entry with
        //     tag='ConversationDetail', message contains 'direct'
        //   - Widget remains mounted (no crash)
        //
        // Currently _openDirectMessage (line 2396) has:
        //   catch (_) { // Fail-soft: if DM open fails, do nothing. }
        // Phase B will add diagnostics.error(...) in that catch.
        final diagnostics = DiagnosticsCollector();
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'ch-1',
          ),
        );

        await tester.pumpWidget(
          _buildApp(
            target: target,
            diagnostics: diagnostics,
            conversationRepository: _FakeConversationRepository(
              snapshot: _makeSnapshot(target),
            ),
            // Profile loads successfully → sheet appears with DM button.
            profileRepository: _FakeProfileRepository(),
            // DM open throws → catch block fires.
            memberRepository: const _ThrowingMemberRepository(),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1: Tap sender name to trigger _openSenderProfile.
        // Profile loads successfully → profile sheet opens.
        final senderLabel = find.text('Alice');
        expect(senderLabel, findsOneWidget,
            reason: 'Sender name must be rendered');
        await tester.tap(senderLabel);
        // Advance clock past the 300 ms double-tap window in
        // MessageGestureWrapper so onTap fires → _openSenderProfile →
        // loadProfile succeeds → showMemberProfileSheet renders.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Step 2: Profile sheet must be visible with the DM action button.
        final dmButton = find.byKey(const ValueKey('member-profile-dm-action'));
        expect(dmButton, findsOneWidget,
            reason: 'Profile sheet must show Message button '
                '(member-profile-dm-action)');

        // Step 3: Tap the "Message" button → triggers _openDirectMessage
        // → memberRepository.openDirectMessage throws → catch block fires.
        await tester.tap(dmButton);
        // Flush async from _openDirectMessage (memberRepository throws →
        // catch → diagnostics.error). The DM button is outside the
        // MessageGestureWrapper, so no 300 ms double-tap delay here.
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        // Widget must remain mounted after the failure.
        expect(find.byType(ConversationDetailPage), findsOneWidget,
            reason: 'Page must remain mounted after DM open failure');

        // DiagnosticsCollector must have an error entry.
        expect(
          diagnostics.entries.any(
            (e) =>
                e.tag == 'ConversationDetail' &&
                e.level == DiagnosticsLevel.error &&
                e.message.toLowerCase().contains('direct'),
          ),
          isTrue,
          reason:
              'DM open failure must be logged to diagnostics (INV-TELEM-10)',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ConversationDetailSnapshot _makeSnapshot(ConversationDetailTarget target) {
  return ConversationDetailSnapshot(
    target: target,
    title: '#general',
    messages: [
      ConversationMessageSummary(
        id: 'msg-1',
        content: 'Hello from Alice',
        createdAt: DateTime.parse('2026-05-18T00:00:00Z'),
        senderId: 'user-2',
        senderType: 'human',
        senderName: 'Alice',
        messageType: 'message',
        seq: 1,
      ),
    ],
    historyLimited: false,
    hasOlder: false,
  );
}

Widget _buildApp({
  required ConversationDetailTarget target,
  required DiagnosticsCollector diagnostics,
  required ConversationRepository conversationRepository,
  required ProfileRepository profileRepository,
  required MemberRepository memberRepository,
}) {
  return ProviderScope(
    overrides: [
      diagnosticsCollectorProvider.overrideWithValue(diagnostics),
      conversationRepositoryProvider.overrideWithValue(conversationRepository),
      profileRepositoryProvider.overrideWithValue(profileRepository),
      memberRepositoryProvider.overrideWithValue(memberRepository),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => ConversationDetailPage(target: target),
          ),
          GoRoute(
            path: '/servers/:serverId/dms/:dmId',
            builder: (_, __) => const Scaffold(body: Placeholder()),
          ),
        ],
      ),
      theme: AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  const _FakeConversationRepository({required this.snapshot});

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
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async =>
      'attachment-1';

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async =>
      ConversationMessageSummary(
        id: 'sent-1',
        content: content,
        createdAt: DateTime.now(),
        senderType: 'human',
        messageType: 'message',
        seq: 999,
      );

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async =>
      message;

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async =>
      null;

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async =>
      [];

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Me',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}

/// Profile repository that returns a valid profile (for DM open flow).
class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) async =>
      MemberProfile(
        id: userId,
        displayName: 'Alice',
      );
}

/// Profile repository that always throws (for testing TELEM-9 catch).
class _ThrowingProfileRepository implements ProfileRepository {
  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) async =>
      throw const ServerFailure(
        message: 'Profile fetch failed',
        statusCode: 500,
      );
}

class _FakeMemberRepository implements MemberRepository {
  const _FakeMemberRepository();

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async =>
      const [];

  @override
  Future<String> createInvite(ServerScopeId serverId) async => 'invite-token';

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) async {}

  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) async {}

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async =>
      'dm-channel-1';

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'dm-agent-channel-1';
}

/// Member repository that always throws on DM open (for testing TELEM-10 catch).
class _ThrowingMemberRepository implements MemberRepository {
  const _ThrowingMemberRepository();

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async =>
      const [];

  @override
  Future<String> createInvite(ServerScopeId serverId) async => 'invite-token';

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) async {}

  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) async {}

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async =>
      throw const ServerFailure(
        message: 'DM open failed',
        statusCode: 500,
      );

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      throw const ServerFailure(
        message: 'Agent DM open failed',
        statusCode: 500,
      );
}
