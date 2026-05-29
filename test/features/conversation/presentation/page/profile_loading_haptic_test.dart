// =============================================================================
// #656 — Profile Loading Indicator + Haptic Feedback
//
// Invariants verified:
// INV-PROFILE-LOADING-1: Tapping sender name shows loading indicator
//                         immediately (before profile fetch completes).
// INV-HAPTIC-REACTION-1: HapticFeedback.mediumImpact() is called on
//                         successful quick-react.
// INV-HAPTIC-MENTION-1: HapticFeedback.mediumImpact() is called on
//                        mention suggestion selection.
// =============================================================================

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-PROFILE-LOADING-1: Profile popup loading indicator
  // ---------------------------------------------------------------------------
  group('INV-PROFILE-LOADING: profile popup shows loading state', () {
    testWidgets(
      'INV-PROFILE-LOADING-1: tapping sender name shows loading indicator '
      'while profile data loads',
      (tester) async {
        // Use a Completer so we can control when the profile resolves.
        final profileCompleter = Completer<MemberProfile>();
        final profileRepo = _DelayedProfileRepository(
          completer: profileCompleter,
        );

        await tester.pumpWidget(
          _buildApp(
            target: _channelTarget,
            profileRepository: profileRepo,
          ),
        );
        await tester.pumpAndSettle();

        // Sender name should be visible.
        expect(find.text('Alex'), findsOneWidget);

        // Tap the sender name (with timer advancement for single-tap
        // detection through MessageGestureWrapper).
        await tester.tap(find.text('Alex'));
        await tester.pump(const Duration(milliseconds: 400));
        // Use pump() not pumpAndSettle() since the unresolved future
        // keeps the loading spinner animating indefinitely.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Loading indicator should appear in the bottom sheet.
        expect(
          find.byKey(const ValueKey('profile-loading-indicator')),
          findsOneWidget,
          reason: 'Loading indicator must appear immediately while profile '
              'data is being fetched (INV-PROFILE-LOADING-1)',
        );

        // Profile sheet name should NOT be visible yet.
        expect(
          find.byKey(const ValueKey('profile-sheet-name')),
          findsNothing,
          reason: 'Profile name must not show before data loads',
        );

        // Now complete the profile future.
        profileCompleter.complete(const MemberProfile(
          id: 'user-2',
          displayName: 'Alex',
          username: 'alexdev',
          role: 'admin',
          presence: 'online',
        ));
        await tester.pumpAndSettle();

        // Loading indicator should disappear and profile name should render.
        expect(
          find.byKey(const ValueKey('profile-loading-indicator')),
          findsNothing,
          reason: 'Loading indicator must disappear after data loads',
        );
        expect(
          find.byKey(const ValueKey('profile-sheet-name')),
          findsOneWidget,
          reason: 'Profile name must appear after data loads',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-HAPTIC-REACTION-1: Haptic feedback on reaction success
  // ---------------------------------------------------------------------------
  group('INV-HAPTIC-REACTION: haptic on reaction success', () {
    testWidgets(
      'INV-HAPTIC-REACTION-1: HapticFeedback.mediumImpact() fires on '
      'successful quick-react (double-tap)',
      (tester) async {
        final hapticLog = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              hapticLog.add(call.arguments as String);
            }
            return null;
          },
        );

        await tester.pumpWidget(
          _buildApp(target: _channelTarget),
        );
        await tester.pumpAndSettle();

        // Double-tap the message bubble to trigger quick-react.
        final messageFinder = find.byKey(const ValueKey('message-msg-1'));
        expect(messageFinder, findsOneWidget);

        // Clear haptic log BEFORE the action to isolate post-reaction haptics
        // from any pre-existing gesture haptics.
        hapticLog.clear();

        await tester.tap(messageFinder);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(messageFinder);
        await tester.pumpAndSettle();

        // The reaction success path fires HapticFeedback.mediumImpact(),
        // which sends 'HapticFeedbackType.mediumImpact' as the argument.
        // The gesture wrapper may also fire 'HapticFeedbackType.lightImpact'
        // for the double-tap itself, but we specifically need mediumImpact.
        expect(
          hapticLog.contains('HapticFeedbackType.mediumImpact'),
          isTrue,
          reason: 'HapticFeedback.mediumImpact must fire after successful '
              'addReaction() (INV-HAPTIC-REACTION-1). Got: $hapticLog',
        );

        // Clean up.
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-HAPTIC-MENTION-1: Haptic feedback on mention selection
  // ---------------------------------------------------------------------------
  group('INV-HAPTIC-MENTION: haptic on mention selection', () {
    testWidgets(
      'INV-HAPTIC-MENTION-1: HapticFeedback.mediumImpact() fires when '
      'user selects a mention suggestion',
      (tester) async {
        final hapticLog = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              hapticLog.add(call.arguments as String);
            }
            return null;
          },
        );

        await tester.pumpWidget(
          _buildApp(target: _channelTarget),
        );
        await tester.pumpAndSettle();

        // Type '@' in the composer to trigger mention overlay.
        final inputFinder = find.byKey(const ValueKey('composer-input'));
        expect(inputFinder, findsOneWidget);
        await tester.enterText(inputFinder, '@');
        await tester.pumpAndSettle();

        // Suggestion overlay MUST appear (unconditional assertion).
        final suggestionFinder =
            find.byKey(const ValueKey('mention-suggestion-0'));
        expect(
          suggestionFinder,
          findsOneWidget,
          reason: 'Mention suggestion must appear after typing @ '
              '(INV-HAPTIC-MENTION-1 precondition)',
        );

        // Clear haptic log BEFORE tapping suggestion.
        hapticLog.clear();
        await tester.tap(suggestionFinder);
        await tester.pumpAndSettle();

        // Assert specifically mediumImpact (not lightImpact or other types).
        expect(
          hapticLog.contains('HapticFeedbackType.mediumImpact'),
          isTrue,
          reason: 'HapticFeedback.mediumImpact must fire after selecting '
              'a mention suggestion (INV-HAPTIC-MENTION-1). Got: $hapticLog',
        );

        // Clean up.
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _channelTarget = ConversationDetailTarget.channel(
  const ChannelScopeId(
    serverId: ServerScopeId('server-1'),
    value: 'general',
  ),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp({
  required ConversationDetailTarget target,
  ProfileRepository? profileRepository,
}) {
  final router = GoRouter(
    initialLocation: '/conversation',
    routes: [
      GoRoute(
        path: '/conversation',
        builder: (_, __) => ConversationDetailPage(target: target),
      ),
      GoRoute(
        path: '/servers/:serverId/dms/:channelId',
        builder: (_, state) => Scaffold(
          body: Center(
            child: Text('dm-page-${state.pathParameters['channelId']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:serverId/threads/:threadId/replies',
        builder: (_, state) => Scaffold(
          body: Center(
            child: Text('thread-page-${state.pathParameters['threadId']}'),
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(
        _FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [
              ConversationMessageSummary(
                id: 'msg-1',
                content: 'Hello world',
                createdAt: DateTime.parse('2026-05-20T14:00:00Z'),
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
        ),
      ),
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      channelMemberRepositoryProvider.overrideWithValue(
        _FakeChannelMemberRepository(),
      ),
      if (profileRepository != null)
        profileRepositoryProvider.overrideWithValue(profileRepository),
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

class _DelayedProfileRepository implements ProfileRepository {
  _DelayedProfileRepository({required this.completer});

  final Completer<MemberProfile> completer;

  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) {
    return completer.future;
  }
}

class _FakeChannelMemberRepository implements ChannelMemberRepository {
  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    return const [
      ChannelMember(
        id: 'member-1',
        channelId: 'general',
        userId: 'user-alice',
        userName: 'Alice',
      ),
      ChannelMember(
        id: 'member-2',
        channelId: 'general',
        userId: 'user-parker',
        userName: 'Parker',
      ),
    ];
  }

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
