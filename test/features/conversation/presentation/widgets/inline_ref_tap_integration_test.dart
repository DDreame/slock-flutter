// =============================================================================
// B123 PR 5 — Channel/task ref tap → navigation INTEGRATION tests.
//
// These tests mount a real ConversationDetailPage (which internally builds
// ConversationMessageCard), tap a #channel or task #N chip, and assert
// navigation fires to the correct route.
//
// Tests prove:
// 1. Tapping #channel in ConversationMessageCard navigates to channel route.
// 2. Tapping task #N in ConversationMessageCard navigates to tasks page.
// 3. Unresolvable channel name → no navigation, no crash.
//
// Reverting onChannelRefTap/onTaskRefTap wiring or context.push → tests RED.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  final channelTarget = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'current-channel',
    ),
  );

  // ---------------------------------------------------------------------------
  // Integration: Channel ref tap → channel navigation
  // ---------------------------------------------------------------------------
  group('B123 PR 5 — ConversationMessageCard channel ref tap integration', () {
    testWidgets(
      'tapping #general navigates to /servers/{serverId}/channels/{channelId}',
      (tester) async {
        String? navigatedTo;

        await tester.pumpWidget(
          _buildApp(
            target: channelTarget,
            messageContent: 'Check #general for updates',
            channels: [
              const HomeChannelSummary(
                scopeId: ChannelScopeId(
                  serverId: ServerScopeId('server-1'),
                  value: 'channel-abc-123',
                ),
                name: 'general',
              ),
            ],
            onNavigate: (route) => navigatedTo = route,
          ),
        );
        await tester.pumpAndSettle();

        // Find the channel ref tap target.
        final channelRefTap =
            find.byKey(const ValueKey('channel-ref-tap-general'));
        expect(
          channelRefTap,
          findsOneWidget,
          reason:
              'Reverting onChannelRefTap: _onChannelRefTap wiring → no tap target → RED.',
        );

        await tester.tap(channelRefTap);
        await tester.pumpAndSettle();

        expect(
          navigatedTo,
          '/servers/server-1/channels/channel-abc-123',
          reason:
              'Reverting context.push in _onChannelRefTap → no navigation → RED.',
        );
      },
    );

    testWidgets(
      'unresolvable #nonexistent channel → no navigation, no crash',
      (tester) async {
        String? navigatedTo;

        await tester.pumpWidget(
          _buildApp(
            target: channelTarget,
            messageContent: 'See #nonexistent for details',
            channels: [
              // Only "general" is available — "nonexistent" won't resolve.
              const HomeChannelSummary(
                scopeId: ChannelScopeId(
                  serverId: ServerScopeId('server-1'),
                  value: 'channel-abc-123',
                ),
                name: 'general',
              ),
            ],
            onNavigate: (route) => navigatedTo = route,
          ),
        );
        await tester.pumpAndSettle();

        // Channel ref should still render as a tappable chip.
        final channelRefTap =
            find.byKey(const ValueKey('channel-ref-tap-nonexistent'));
        expect(channelRefTap, findsOneWidget);

        await tester.tap(channelRefTap);
        await tester.pumpAndSettle();

        // No navigation should occur — graceful no-op.
        expect(
          navigatedTo,
          isNull,
          reason:
              'Unresolvable channel name must produce no navigation (graceful no-op).',
        );

        // No exceptions thrown.
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Integration: Task ref tap → tasks page navigation
  // ---------------------------------------------------------------------------
  group('B123 PR 5 — ConversationMessageCard task ref tap integration', () {
    testWidgets(
      'tapping task #5 navigates to /servers/{serverId}/tasks',
      (tester) async {
        String? navigatedTo;

        await tester.pumpWidget(
          _buildApp(
            target: channelTarget,
            messageContent: 'Please review task #5 ASAP',
            channels: const [],
            onNavigate: (route) => navigatedTo = route,
          ),
        );
        await tester.pumpAndSettle();

        // Find the task ref tap target.
        final taskRefTap = find.byKey(const ValueKey('task-ref-tap-5'));
        expect(
          taskRefTap,
          findsOneWidget,
          reason:
              'Reverting onTaskRefTap: _onTaskRefTap wiring → no tap target → RED.',
        );

        await tester.tap(taskRefTap);
        await tester.pumpAndSettle();

        expect(
          navigatedTo,
          '/servers/server-1/tasks',
          reason:
              'Reverting context.push in _onTaskRefTap → no navigation → RED.',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Integration: Thread ref tap → thread page navigation
  // ---------------------------------------------------------------------------
  group('B125 PR 1 — ConversationMessageCard thread ref tap integration', () {
    testWidgets(
      'tapping #general:a1b2c3d4 navigates to thread route with correct channelId',
      (tester) async {
        String? navigatedTo;

        await tester.pumpWidget(
          _buildApp(
            target: channelTarget,
            messageContent: 'See the thread #general:a1b2c3d4 for details',
            channels: [
              const HomeChannelSummary(
                scopeId: ChannelScopeId(
                  serverId: ServerScopeId('server-1'),
                  value: 'channel-general-id',
                ),
                name: 'general',
              ),
            ],
            onNavigate: (route) => navigatedTo = route,
          ),
        );
        await tester.pumpAndSettle();

        // Find the thread ref tap target.
        final threadRefTap =
            find.byKey(const ValueKey('thread-ref-tap-general-a1b2c3d4'));
        expect(
          threadRefTap,
          findsOneWidget,
          reason:
              'Reverting onThreadRefTap wiring or ThreadRefBuilder → no tap target → RED.',
        );

        await tester.tap(threadRefTap);
        await tester.pumpAndSettle();

        expect(
          navigatedTo,
          '/servers/server-1/threads/a1b2c3d4/replies?channelId=channel-general-id',
          reason:
              'Reverting context.push(threadTarget.toLocation()) → no navigation → RED.',
        );
      },
    );

    testWidgets(
      'tapping dm:@alice:f5e6d7c8 navigates to DM thread route',
      (tester) async {
        String? navigatedTo;

        await tester.pumpWidget(
          _buildApp(
            target: channelTarget,
            messageContent: 'Check dm:@alice:f5e6d7c8 for context',
            channels: const [],
            directMessages: [
              const HomeDirectMessageSummary(
                scopeId: DirectMessageScopeId(
                  serverId: ServerScopeId('server-1'),
                  value: 'dm-alice-id',
                ),
                title: 'alice',
              ),
            ],
            onNavigate: (route) => navigatedTo = route,
          ),
        );
        await tester.pumpAndSettle();

        // Find the DM thread ref tap target.
        final threadRefTap =
            find.byKey(const ValueKey('thread-ref-tap-alice-f5e6d7c8'));
        expect(
          threadRefTap,
          findsOneWidget,
          reason:
              'Reverting DM thread ref builder or tap wiring → no target → RED.',
        );

        await tester.tap(threadRefTap);
        await tester.pumpAndSettle();

        expect(
          navigatedTo,
          '/servers/server-1/threads/f5e6d7c8/replies?channelId=dm-alice-id',
          reason:
              'Reverting DM resolution in _onThreadRefTap → no navigation → RED.',
        );
      },
    );

    testWidgets(
      'unresolvable #nonexistent:a1b2c3d4 → no navigation, no crash',
      (tester) async {
        String? navigatedTo;

        await tester.pumpWidget(
          _buildApp(
            target: channelTarget,
            messageContent: 'See #nonexistent:a1b2c3d4 thread',
            channels: [
              const HomeChannelSummary(
                scopeId: ChannelScopeId(
                  serverId: ServerScopeId('server-1'),
                  value: 'channel-general-id',
                ),
                name: 'general',
              ),
            ],
            onNavigate: (route) => navigatedTo = route,
          ),
        );
        await tester.pumpAndSettle();

        // Thread ref chip should still render (builder doesn't know it's unresolvable).
        final threadRefTap =
            find.byKey(const ValueKey('thread-ref-tap-nonexistent-a1b2c3d4'));
        expect(threadRefTap, findsOneWidget);

        await tester.tap(threadRefTap);
        await tester.pumpAndSettle();

        // No navigation — graceful no-op.
        expect(
          navigatedTo,
          isNull,
          reason:
              'Unresolvable channel name must produce no navigation (graceful no-op).',
        );

        // No exceptions thrown.
        expect(tester.takeException(), isNull);
      },
    );
  });
}

// =============================================================================
// Helpers
// =============================================================================

Widget _buildApp({
  required ConversationDetailTarget target,
  required String messageContent,
  required List<HomeChannelSummary> channels,
  required void Function(String route) onNavigate,
  List<HomeDirectMessageSummary> directMessages = const [],
}) {
  final conversationRepo = _FakeConversationRepository(
    snapshot: ConversationDetailSnapshot(
      target: target,
      title: '#current-channel',
      messages: [
        ConversationMessageSummary(
          id: 'msg-1',
          content: messageContent,
          createdAt: DateTime.parse('2026-05-29T10:00:00Z'),
          senderId: 'user-2',
          senderType: 'human',
          messageType: 'message',
          senderName: 'Sender',
          seq: 1,
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    ),
  );

  final router = GoRouter(
    initialLocation: '/conversation',
    routes: [
      GoRoute(
        path: '/conversation',
        builder: (_, __) => ConversationDetailPage(target: target),
      ),
      // Channel route stub — captures navigation for assertion.
      GoRoute(
        path: '/servers/:serverId/channels/:channelId',
        builder: (_, state) {
          final route =
              '/servers/${state.pathParameters['serverId']}/channels/${state.pathParameters['channelId']}';
          onNavigate(route);
          return Scaffold(
            body: Center(child: Text('channel-$route')),
          );
        },
      ),
      // Tasks route stub — captures navigation for assertion.
      GoRoute(
        path: '/servers/:serverId/tasks',
        builder: (_, state) {
          final route = '/servers/${state.pathParameters['serverId']}/tasks';
          onNavigate(route);
          return Scaffold(
            body: Center(child: Text('tasks-$route')),
          );
        },
      ),
      // Thread route stub — captures navigation for assertion.
      GoRoute(
        path: '/servers/:serverId/threads/:messageId/replies',
        builder: (_, state) {
          final serverId = state.pathParameters['serverId'];
          final messageId = state.pathParameters['messageId'];
          final channelId = state.uri.queryParameters['channelId'];
          final route =
              '/servers/$serverId/threads/$messageId/replies?channelId=$channelId';
          onNavigate(route);
          return Scaffold(
            body: Center(child: Text('thread-$route')),
          );
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(conversationRepo),
      channelMemberRepositoryProvider
          .overrideWithValue(_FakeChannelMemberRepository()),
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
      memberRepositoryProvider.overrideWithValue(_FakeMemberRepository()),
      homeListStoreProvider
          .overrideWith(() => _FakeHomeListStore(channels, directMessages)),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeHomeListStore extends HomeListStore {
  _FakeHomeListStore(this._channels, this._directMessages);
  final List<HomeChannelSummary> _channels;
  final List<HomeDirectMessageSummary> _directMessages;

  @override
  HomeListState build() => HomeListState(
        status: HomeListStatus.success,
        channels: _channels,
        directMessages: _directMessages,
      );
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Robin',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}

class _FakeChannelMemberRepository implements ChannelMemberRepository {
  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async =>
      const [];

  @override
  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

  @override
  Future<void> addAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}

  @override
  Future<void> removeHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

  @override
  Future<void> removeAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    return const MemberProfile(
      id: 'user-2',
      displayName: 'Sender',
      username: 'sender',
      role: 'member',
      presence: 'online',
    );
  }
}

class _FakeMemberRepository implements MemberRepository {
  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async =>
      const [];

  @override
  Future<String> createInvite(ServerScopeId serverId) async => 'code';

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
      'dm-default';

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'dm-default';
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({required this.snapshot});
  final ConversationDetailSnapshot snapshot;

  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

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
    bool? asTask,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

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
      const [];

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
