import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

import '../../../core/local_data/fake_conversation_local_store.dart';

// ---------------------------------------------------------------------------
// #577: Channel Description Display — Phase A (test-only)
//
// Tests for channel description being parsed from API, displayed in the
// conversation header, hidden when null/empty, and shown on the info page.
//
// Invariants verified:
// T1: Channel model includes description field (parsed from API JSON)
// T2: Channel header shows description when present
// T3: Channel header hides description area when null/empty
// T4: Channel info page shows description section
// ---------------------------------------------------------------------------

void main() {
  const serverId = ServerScopeId('server-1');
  const channelScopeId = ChannelScopeId(serverId: serverId, value: 'general');

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // -------------------------------------------------------------------------
  // T1: Channel model includes description field (parsed from API JSON)
  // -------------------------------------------------------------------------
  test(
    'ConversationDetailSnapshot includes description from API response',
    () async {
      // Set up a fake API client that returns a channel with a description.
      final appDioClient = _FakeAppDioClient(
        responses: {
          '/messages/channel/general': {
            'messages': [
              {
                'id': 'msg-1',
                'content': 'Hello',
                'createdAt': '2026-05-16T10:00:00Z',
                'senderType': 'human',
                'messageType': 'message',
                'seq': 1,
              },
            ],
          },
          '/channels/general': {
            'id': 'general',
            'name': 'general',
            'description': 'A channel for general discussion',
          },
        },
      );

      final container = ProviderContainer(
        overrides: [
          appDioClientProvider.overrideWithValue(appDioClient),
          conversationLocalStoreProvider.overrideWithValue(
            FakeConversationLocalStore(),
          ),
          savedMessagesRepositoryProvider
              .overrideWithValue(_NoOpSavedMessagesRepository()),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(conversationRepositoryProvider);
      final snapshot = await repository.loadConversation(
        ConversationDetailTarget.channel(channelScopeId),
      );

      // The snapshot must carry the description from the API response.
      expect(
        snapshot.description,
        'A channel for general discussion',
        reason: 'ConversationDetailSnapshot must parse description from '
            'the channel metadata API response',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T2: Channel header shows description when present
  // -------------------------------------------------------------------------
  testWidgets(
    'Channel header shows description text when present',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: ConversationDetailTarget.channel(channelScopeId),
          title: '#general',
          description: 'Team-wide announcements and updates',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
          memberCount: 5,
        ),
      );

      await tester.pumpWidget(
        _buildConversationApp(repo, prefs: prefs),
      );
      await tester.pumpAndSettle();

      // Description text widget should be visible in the header.
      expect(
        find.byKey(const ValueKey('channel-description-text')),
        findsOneWidget,
        reason: 'Channel header must display description text when description '
            'is non-null and non-empty',
      );

      // The actual description text must match.
      expect(
        find.text('Team-wide announcements and updates'),
        findsOneWidget,
        reason: 'Description text content must match the channel description',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T3: Channel header hides description area when null/empty
  // -------------------------------------------------------------------------
  testWidgets(
    'Channel header hides description when null or empty',
    (tester) async {
      // First: verify that description IS shown when present (guards against
      // the test passing trivially when the feature doesn't exist at all).
      final repoWithDesc = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: ConversationDetailTarget.channel(channelScopeId),
          title: '#general',
          description: 'Has a description',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
          memberCount: 5,
        ),
      );

      await tester.pumpWidget(
        _buildConversationApp(repoWithDesc, prefs: prefs),
      );
      await tester.pumpAndSettle();

      // Positive guard: description text must be shown when present.
      expect(
        find.byKey(const ValueKey('channel-description-text')),
        findsOneWidget,
        reason: 'Guard: description text must be shown when present '
            '(this ensures the feature exists before testing the hide case)',
      );

      // Dispose old tree cleanly before creating a new one with different
      // provider state. This avoids Riverpod's "modify during build" error
      // while ensuring the provider container is truly fresh.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // Now test the hide case: null description.
      final repoNull = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: ConversationDetailTarget.channel(channelScopeId),
          title: '#general',
          description: null,
          messages: const [],
          historyLimited: false,
          hasOlder: false,
          memberCount: 5,
        ),
      );

      await tester.pumpWidget(
        _buildConversationApp(repoNull, prefs: prefs),
      );
      await tester.pumpAndSettle();

      // No description widget when description is null.
      expect(
        find.byKey(const ValueKey('channel-description-text')),
        findsNothing,
        reason: 'Description text must not appear when description is null',
      );

      // Dispose old tree cleanly before next scenario.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // Also test with empty string description.
      final repoEmpty = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: ConversationDetailTarget.channel(channelScopeId),
          title: '#general',
          description: '',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
          memberCount: 5,
        ),
      );

      await tester.pumpWidget(
        _buildConversationApp(repoEmpty, prefs: prefs),
      );
      await tester.pumpAndSettle();

      // No description widget when description is empty string.
      expect(
        find.byKey(const ValueKey('channel-description-text')),
        findsNothing,
        reason:
            'Description text must not appear when description is empty string',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T4: Channel info page shows description section
  // -------------------------------------------------------------------------
  testWidgets(
    'Channel info page shows description section',
    (tester) async {
      final repo = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: ConversationDetailTarget.channel(channelScopeId),
          title: '#general',
          description: 'Discussion about engineering topics',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
          memberCount: 5,
        ),
      );

      await tester.pumpWidget(
        _buildConversationApp(repo, prefs: prefs),
      );
      await tester.pumpAndSettle();

      // Navigate to the info page via the members shortcut.
      final membersToggle =
          find.byKey(const ValueKey('conversation-members-shortcut'));
      expect(membersToggle, findsOneWidget,
          reason: 'Members toggle must be in app bar');

      await tester.tap(membersToggle);
      await tester.pumpAndSettle();

      // The info page must show the description section.
      expect(
        find.byKey(const ValueKey('conversation-info-description')),
        findsOneWidget,
        reason: 'Channel info page must display a description section '
            'with the channel description text',
      );

      // The description text must be visible on the info page.
      expect(
        find.text('Discussion about engineering topics'),
        findsOneWidget,
        reason: 'Info page description section must show the description text',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildConversationApp(
  _FakeConversationRepository repo, {
  required SharedPreferences prefs,
}) {
  final target = repo.snapshot.target;

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      conversationRepositoryProvider.overrideWithValue(repo),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: ConversationDetailPage(target: target),
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
    return ConversationMessageSummary(
      id: 'sent-1',
      content: content,
      createdAt: DateTime.now(),
      senderType: 'human',
      messageType: 'message',
      seq: 999,
    );
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
        displayName: 'Test User',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}

/// Minimal fake AppDioClient for T1 (repository parsing test).
class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({
    Map<String, Object?> responses = const {},
  })  : _responses = responses,
        super(Dio());

  final Map<String, Object?> _responses;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final data = _responses[path];
    return Response<T>(
      data: data as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> request<T>(
    String path, {
    Object? data,
    required String method,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    void Function(int, int)? onSendProgress,
  }) async {
    return get<T>(path, queryParameters: queryParameters, options: options);
  }
}

/// No-op saved messages repository for tests that don't exercise saved logic.
class _NoOpSavedMessagesRepository implements SavedMessagesRepository {
  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      {};

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async =>
      const SavedMessagesPage(items: [], hasMore: false);
}
