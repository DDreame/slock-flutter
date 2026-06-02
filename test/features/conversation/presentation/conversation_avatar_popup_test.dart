import 'dart:async';

import 'package:dio/dio.dart';
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
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #535: Avatar Popup — Phase B
//
// Verifies that tapping a sender name in the conversation message card
// opens the member profile bottom sheet with the expected content.
//
// The production flow:
//   1. User taps sender name label in _ConversationMessageCard
//   2. App calls ProfileRepository.loadProfile(serverId, userId: senderId)
//   3. App calls showMemberProfileSheet(context, member: profile)
//   4. Profile sheet renders: display name, @username, role badge,
//      presence dot + label, and a "Message" button to open DM.
//
// Invariants:
//   INV-AVATAR-1: Tap sender name → profile sheet appears
//   INV-AVATAR-2: Profile sheet shows display name, @username, role badge
//   INV-AVATAR-3: Profile sheet "Message" button → opens DM
//   INV-AVATAR-4: Profile sheet shows presence status (online dot + label)
// ---------------------------------------------------------------------------

void main() {
  final channelTarget = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  // -----------------------------------------------------------------------
  // INV-AVATAR-1: Tapping the sender name label opens the member profile
  // bottom sheet.
  //
  // Setup: Render a conversation with a message from another user. Tap the
  // sender name text. After pumpAndSettle, the profile sheet (keyed
  // 'profile-sheet-name') should be visible.
  // -----------------------------------------------------------------------
  testWidgets(
    'Tap sender name opens member profile sheet (INV-AVATAR-1)',
    (tester) async {
      final profileRepo = _FakeProfileRepository(
        profile: _testProfile,
      );

      await tester.pumpWidget(
        _buildApp(
          repository: _fakeConversationRepo(channelTarget),
          target: channelTarget,
          profileRepository: profileRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Sender name should be visible.
      expect(find.text('Alex'), findsOneWidget);

      // Tap the sender name.
      // The sender-name tap routes through MessageGestureWrapper's
      // timer-based single-tap detection (300ms double-tap window),
      // so we must explicitly advance past the timer before settling.
      await tester.tap(find.text('Alex'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Profile sheet should appear with the display name.
      expect(
        find.byKey(const ValueKey('profile-sheet-name')),
        findsOneWidget,
        reason: 'Profile sheet must appear after tapping sender name '
            '(INV-AVATAR-1)',
      );
    },
  );

  testWidgets(
    'Profile loading sheet ignores future completion after dispose (#705)',
    (tester) async {
      final profileRepo = _CompleterProfileRepository();
      await tester.pumpWidget(
        _buildApp(
          repository: _fakeConversationRepo(channelTarget),
          target: channelTarget,
          profileRepository: profileRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alex'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('profile-loading-indicator')),
        findsOneWidget,
      );

      Navigator.of(
        tester.element(find.byKey(const ValueKey('profile-loading-indicator'))),
      ).pop();
      await tester.pumpAndSettle();

      profileRepo.completer.completeError(StateError('late failure'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  // -----------------------------------------------------------------------
  // INV-AVATAR-2: The profile sheet displays display name, @username,
  // and role badge.
  //
  // Setup: Tap sender name to open profile sheet. Verify the sheet shows
  // the member's display name, @username, and role badge.
  // -----------------------------------------------------------------------
  testWidgets(
    'Profile sheet shows name, username, and role (INV-AVATAR-2)',
    (tester) async {
      final profileRepo = _FakeProfileRepository(
        profile: _testProfile,
      );

      await tester.pumpWidget(
        _buildApp(
          repository: _fakeConversationRepo(channelTarget),
          target: channelTarget,
          profileRepository: profileRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap sender name to open profile sheet.
      await tester.tap(find.text('Alex'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Display name.
      expect(
        find.byKey(const ValueKey('profile-sheet-name')),
        findsOneWidget,
        reason: 'Profile sheet must show display name (INV-AVATAR-2)',
      );

      // @username.
      expect(
        find.byKey(const ValueKey('profile-sheet-username')),
        findsOneWidget,
        reason: 'Profile sheet must show @username (INV-AVATAR-2)',
      );

      // Role badge.
      expect(
        find.byKey(const ValueKey('profile-sheet-role')),
        findsOneWidget,
        reason: 'Profile sheet must show role badge (INV-AVATAR-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-AVATAR-3: The profile sheet has a "Message" button that opens a
  // DM with the member.
  //
  // Setup: Open profile sheet, tap the "Message" button. After navigation,
  // the DM conversation page should appear (verified via stub route).
  //
  // NOTE: The key 'member-profile-dm-action' does NOT exist in the
  // current production code. Phase B must add this key to a new
  // ElevatedButton/TextButton in member_profile_sheet.dart's
  // _MemberProfileSheet widget (below the presence row). This is an
  // explicitly declared new seam, not an invented key anchored to
  // existing code.
  //
  // Phase B added this key to _MemberProfileSheet in
  // member_profile_sheet.dart via the onMessageTap callback.
  // -----------------------------------------------------------------------
  testWidgets(
    'Profile sheet Message button opens DM (INV-AVATAR-3)',
    (tester) async {
      final profileRepo = _FakeProfileRepository(
        profile: _testProfile,
      );
      final memberRepo = _FakeMemberRepository(
        openDmChannelId: 'dm-channel-alex',
      );

      await tester.pumpWidget(
        _buildApp(
          repository: _fakeConversationRepo(channelTarget),
          target: channelTarget,
          profileRepository: profileRepo,
          memberRepository: memberRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Open profile sheet.
      await tester.tap(find.text('Alex'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Tap the Message / DM button.
      final dmButton = find.byKey(
        const ValueKey('member-profile-dm-action'),
      );
      expect(dmButton, findsOneWidget,
          reason: 'Profile sheet must have a DM button (INV-AVATAR-3)');
      await tester.tap(dmButton);
      await tester.pumpAndSettle();

      // Should navigate to the DM conversation route.
      expect(
        find.text('dm-page-dm-channel-alex'),
        findsOneWidget,
        reason: 'Tapping DM button must navigate to DM conversation '
            '(INV-AVATAR-3)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-AVATAR-4: The profile sheet shows the member's presence status
  // (online/offline dot and label).
  //
  // Setup: Open profile sheet for a member whose profile has
  // presence='online'. The sheet should show the presence dot (keyed
  // 'profile-sheet-presence-dot') and label (keyed
  // 'profile-sheet-presence').
  // -----------------------------------------------------------------------
  testWidgets(
    'Profile sheet shows presence status (INV-AVATAR-4)',
    (tester) async {
      final profileRepo = _FakeProfileRepository(
        profile: _testProfile,
      );

      await tester.pumpWidget(
        _buildApp(
          repository: _fakeConversationRepo(channelTarget),
          target: channelTarget,
          profileRepository: profileRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Open profile sheet.
      await tester.tap(find.text('Alex'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Presence dot.
      expect(
        find.byKey(const ValueKey('profile-sheet-presence-dot')),
        findsOneWidget,
        reason: 'Profile sheet must show presence dot (INV-AVATAR-4)',
      );

      // Presence label.
      expect(
        find.byKey(const ValueKey('profile-sheet-presence')),
        findsOneWidget,
        reason: 'Profile sheet must show presence label (INV-AVATAR-4)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _testProfile = MemberProfile(
  id: 'user-2',
  displayName: 'Alex',
  username: 'alexdev',
  role: 'admin',
  presence: 'online',
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

_FakeConversationRepository _fakeConversationRepo(
  ConversationDetailTarget target,
) {
  return _FakeConversationRepository(
    snapshot: ConversationDetailSnapshot(
      target: target,
      title: '#general',
      messages: [
        ConversationMessageSummary(
          id: 'msg-1',
          content: 'Hello world',
          createdAt: DateTime.parse('2026-05-16T14:00:00Z'),
          senderId: 'user-2',
          senderType: 'human',
          messageType: 'message',
          senderName: 'Alex',
          seq: 1,
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    ),
  );
}

Widget _buildApp({
  required ConversationRepository repository,
  required ConversationDetailTarget target,
  ProfileRepository? profileRepository,
  MemberRepository? memberRepository,
}) {
  final router = GoRouter(
    initialLocation: '/conversation',
    routes: [
      GoRoute(
        path: '/conversation',
        builder: (_, __) => ConversationDetailPage(target: target),
      ),
      // Stub route for DM navigation after tapping the "Message" button.
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        builder: (_, state) => Scaffold(
          body: Center(
            child: Text(
              'dm-page-${state.pathParameters['channelId']}',
            ),
          ),
        ),
      ),
      // Stub route for thread navigation (needed to avoid missing route).
      GoRoute(
        path: '/servers/:serverId/threads/:threadId/replies',
        builder: (_, state) => Scaffold(
          body: Center(
            child: Text(
              'thread-page-${state.pathParameters['threadId']}',
            ),
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(repository),
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      sessionStoreProvider.overrideWith(
        () => _FakeSessionStore(),
      ),
      if (profileRepository != null)
        profileRepositoryProvider.overrideWithValue(profileRepository),
      if (memberRepository != null)
        memberRepositoryProvider.overrideWithValue(memberRepository),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({required this.profile});

  final MemberProfile profile;

  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    return profile;
  }
}

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({this.openDmChannelId = 'dm-default'});

  final String openDmChannelId;

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    return const [];
  }

  @override
  Future<String> createInvite(ServerScopeId serverId) async {
    return 'invite-code';
  }

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
  }) async {
    return openDmChannelId;
  }

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async {
    return openDmChannelId;
  }
}

class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _FakeConversationRepository({required this.snapshot});

  final ConversationDetailSnapshot snapshot;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return snapshot;
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
      hasNewer: false,
    );
  }

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
  }) async {
    return 'attachment-1';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    String? clientId,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    return message;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    return null;
  }

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
  ) async {
    return const [];
  }

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

class _CompleterProfileRepository implements ProfileRepository {
  final Completer<MemberProfile> completer = Completer<MemberProfile>();

  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) {
    return completer.future;
  }
}
