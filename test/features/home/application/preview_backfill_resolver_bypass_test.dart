// =============================================================================
// #637 — PreviewBackfillService bypass MessagePreviewResolver
//
// Root cause: 3 bugs working together make message previews show "New message"
// (previewFallback) instead of actual content:
//
// BUG 1 (PRIMARY) — DM never enters backfill
//   home_list_store.dart L220 only backfills channels.
//   _allDirectMessages with null preview are permanently stuck.
//
// BUG 2 (PRIMARY) — SQLite null-coalescing undoes #606
//   conversation_local_dao.dart L41-43:
//     entry.lastMessagePreview ?? current?.lastMessagePreview
//   When API returns null (the "needs backfill" signal), SQLite restores
//   the old "New message" value, blocking backfill.
//
// BUG 3 (SECONDARY) — Realtime path writes "New message" to SQLite
//   domain_runtime_event_router.dart L416-419:
//   Empty-content message from WS → MessagePreviewResolver produces
//   "New message" → written to memory + SQLite + blocks backfill via
//   _realtimePreviewIds.
//
// Strategy:
// T1: DM with null preview triggers backfill (skip:true — currently doesn't).
// T2: SQLite upsert with non-null messageId + null preview clears old value
//     (skip:true — currently preserves stale value).
// T3: Realtime message with empty content + non-empty attachments → preview
//     = attachment label, not "New message" (skip:true — currently produces
//     correct result from resolver but the real bug is that the WS event
//     may not include attachments; test verifies the fix handles this).
// T4: Realtime message with empty content + no attachments → should NOT
//     write "New message" as preview (skip:true — currently writes it).
// T5: PreviewBackfillService fetcher resolves attachment-only message
//     correctly (skip:true — verifies end-to-end fetcher→resolver path).
//
// Phase A: All tests skip:true.
// Phase B: Fix all 3 bugs, un-skip tests. ← DONE
// =============================================================================

import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/preview_backfill_service.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/session/session_state.dart';

import '../../../support/support.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _serverId = ServerScopeId('server-1');

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _TrackingPreviewFetcher {
  final List<(String serverId, String channelId)> calls = [];
  final Map<String, PreviewFetchResult> _results = {};

  void seed(String channelId, PreviewFetchResult result) {
    _results[channelId] = result;
  }

  Future<PreviewFetchResult?> call(String serverId, String channelId) async {
    calls.add((serverId, channelId));
    return _results[channelId];
  }
}

class _TrackingHomeRepository implements HomeRepository {
  _TrackingHomeRepository({
    this.channels = const [],
    this.directMessages = const [],
  });

  final List<HomeChannelSummary> channels;
  final List<HomeDirectMessageSummary> directMessages;
  final List<_PersistedActivity> persistedActivities = [];

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
  }

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: channels,
      directMessages: directMessages,
    );
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async {
    return summary;
  }

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {
    persistedActivities.add(_PersistedActivity(
      conversationId: conversationId,
      messageId: messageId,
      preview: preview,
    ));
  }

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
}

class _PersistedActivity {
  const _PersistedActivity({
    required this.conversationId,
    required this.messageId,
    required this.preview,
  });

  final String conversationId;
  final String messageId;
  final String preview;
}

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  @override
  Stream<RealtimeSocketSignal> get signals => const Stream.empty();
  @override
  bool get isConnected => false;
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  void emit(String eventName, Object? payload) {}
  @override
  Future<void> dispose() async {}
}

class _PresetSessionStore extends SessionStore {
  _PresetSessionStore(this._userId);
  final String _userId;

  @override
  SessionState build() => SessionState(
        status: AuthStatus.authenticated,
        userId: _userId,
        token: 'test-token',
      );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppLocalizations l10n;

  setUp(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  // =========================================================================
  // T1: DM with null preview triggers backfill
  // =========================================================================
  test(
    'BUG-1: DM with null lastMessagePreview should trigger backfill',
    () async {
      // Setup: Home store loaded with 1 DM that has null preview.
      // After load(), the backfill service should be called for DMs too.
      final fetcher = _TrackingPreviewFetcher();
      fetcher.seed(
        'dm-1',
        PreviewFetchResult(
          messageId: 'msg-dm-1',
          preview: 'Hey there!',
          activityAt: DateTime.parse('2026-05-01T10:00:00Z'),
        ),
      );

      final homeRepo = _TrackingHomeRepository(
        directMessages: const [
          HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(
              serverId: _serverId,
              value: 'dm-1',
            ),
            title: 'Alice',
            lastMessageId: 'msg-dm-1',
            lastMessagePreview: null, // <-- needs backfill
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          appLocalizationsProvider.overrideWithValue(l10n),
          activeServerScopeIdProvider.overrideWithValue(_serverId),
          homeRepositoryProvider.overrideWithValue(homeRepo),
          sidebarOrderRepositoryProvider.overrideWithValue(
            FakeSidebarOrderRepository(),
          ),
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          conversationLocalStoreProvider.overrideWithValue(
            FakeConversationLocalStore(),
          ),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          agentsRepositoryProvider.overrideWithValue(
            const _NoOpAgentsRepository(),
          ),
          agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
          tasksRepositoryProvider.overrideWithValue(
            const _NoOpTasksRepository(),
          ),
          threadRepositoryProvider.overrideWithValue(
            const _NoOpThreadRepository(),
          ),
          inboxRepositoryProvider.overrideWithValue(
            const _NoOpInboxRepository(),
          ),
          serverListRepositoryProvider.overrideWithValue(
            const _NoOpServerListRepository(),
          ),
          crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
          previewMessageFetcherProvider.overrideWithValue(fetcher.call),
        ],
      );
      addTearDown(container.dispose);

      // Load triggers backfill for channels. After fix, DMs too.
      await container.read(homeListStoreProvider.notifier).load();

      // Allow backfill to run.
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      // After fix: fetcher should have been called for 'dm-1'.
      expect(
        fetcher.calls.any((c) => c.$2 == 'dm-1'),
        isTrue,
        reason: 'DM with null preview must trigger backfill fetch',
      );

      // And the DM should now have the resolved preview.
      final state = container.read(homeListStoreProvider);
      final dm = state.directMessages.firstWhere(
        (d) => d.scopeId.value == 'dm-1',
      );
      expect(dm.lastMessagePreview, 'Hey there!');
    },
  );

  // =========================================================================
  // T2: SQLite upsert with non-null messageId + null preview clears old value
  // =========================================================================
  test(
    'BUG-2: SQLite upsert with null preview must NOT restore old "New message"',
    () async {
      // Setup: Local store already has a stale "New message" preview.
      // When we upsert with messageId set but preview null, the old value
      // should be CLEARED (not preserved via null-coalescing).
      final localStore = FakeConversationLocalStore();

      // Seed stale record.
      await localStore.upsertConversationSummaries([
        LocalConversationSummaryUpsert(
          serverId: 'server-1',
          conversationId: 'ch-1',
          surface: 'channel',
          title: '#general',
          sortIndex: 0,
          lastMessageId: 'msg-old',
          lastMessagePreview: 'New message', // stale fallback
          lastActivityAt: DateTime.parse('2026-05-01T10:00:00Z'),
        ),
      ]);

      // Upsert with newer messageId but null preview (the "needs backfill" signal).
      await localStore.upsertConversationSummaries([
        LocalConversationSummaryUpsert(
          serverId: 'server-1',
          conversationId: 'ch-1',
          surface: 'channel',
          title: '#general',
          sortIndex: 0,
          lastMessageId: 'msg-new',
          lastMessagePreview: null, // <-- should clear, not preserve old
          lastActivityAt: DateTime.parse('2026-05-01T12:00:00Z'),
        ),
      ]);

      // Read back.
      final records = await localStore.listConversationSummaries(
        'server-1',
        surface: 'channel',
      );
      expect(records, hasLength(1));
      final record = records.first;

      // After fix: lastMessagePreview should be null (cleared), not "New message".
      expect(
        record.lastMessagePreview,
        isNull,
        reason:
            'When messageId is updated but preview is null, stale preview must '
            'be cleared — not preserved via null-coalescing',
      );
      // messageId should be the new one.
      expect(record.lastMessageId, 'msg-new');
    },
  );

  // =========================================================================
  // T3: Realtime message with empty content + non-empty attachments → label
  // =========================================================================
  test(
    'BUG-3a: Realtime message:new with attachments resolves attachment label',
    () async {
      // Setup: Channel receives a message:new via WS with content=""
      // but with image attachment. The resolved preview should be
      // "Image" (l10n.previewImage), NOT "New message".
      const channelScopeId = ChannelScopeId(
        serverId: _serverId,
        value: 'ch-1',
      );
      final homeRepo = _TrackingHomeRepository(
        channels: const [
          HomeChannelSummary(
            scopeId: channelScopeId,
            name: 'general',
          ),
        ],
      );
      final ingress = RealtimeReductionIngress();

      final container = ProviderContainer(
        overrides: [
          appLocalizationsProvider.overrideWithValue(l10n),
          activeServerScopeIdProvider.overrideWithValue(_serverId),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          realtimeSocketClientProvider.overrideWithValue(
            _FakeRealtimeSocketClient(),
          ),
          homeRepositoryProvider.overrideWithValue(homeRepo),
          sidebarOrderRepositoryProvider.overrideWithValue(
            FakeSidebarOrderRepository(),
          ),
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          conversationLocalStoreProvider.overrideWithValue(
            FakeConversationLocalStore(),
          ),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          agentsRepositoryProvider.overrideWithValue(
            const _NoOpAgentsRepository(),
          ),
          agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
          tasksRepositoryProvider.overrideWithValue(
            const _NoOpTasksRepository(),
          ),
          threadRepositoryProvider.overrideWithValue(
            const _NoOpThreadRepository(),
          ),
          inboxRepositoryProvider.overrideWithValue(
            const _NoOpInboxRepository(),
          ),
          serverListRepositoryProvider.overrideWithValue(
            const _NoOpServerListRepository(),
          ),
          crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
          previewMessageFetcherProvider.overrideWithValue(
            (_, __) async => null,
          ),
          sessionStoreProvider.overrideWith(
            () => _PresetSessionStore('user-other'),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      await container.read(homeListStoreProvider.notifier).load();

      // Activate the event router.
      container.read(domainRuntimeEventRouterProvider);

      // Fire message:new with empty content but image attachment.
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: {
          'channelId': 'ch-1',
          'id': 'msg-img-1',
          'content': '',
          'createdAt': DateTime.now().toIso8601String(),
          'senderId': 'user-123',
          'senderName': 'Alice',
          'senderType': 'user',
          'messageType': 'message',
          'attachments': const [
            {'name': 'photo.png', 'type': 'image/png'},
          ],
        },
      ));
      await Future<void>.delayed(Duration.zero);

      final homeState = container.read(homeListStoreProvider);
      final channel = homeState.channels.firstWhere(
        (c) => c.scopeId == channelScopeId,
      );

      // After fix: preview should be "Image", not "New message".
      expect(
        channel.lastMessagePreview,
        l10n.previewImage,
        reason:
            'Attachment-only message from WS must resolve to attachment label',
      );
    },
  );

  // =========================================================================
  // T4: Realtime message with empty content + no attachments → NOT "New message"
  // =========================================================================
  test(
    'BUG-3b: Realtime message:new with empty content and no attachments '
    'must NOT write "New message" as preview',
    () async {
      // Setup: Channel receives a message:new via WS with content=""
      // and no attachments. This happens when WS doesn't include
      // attachments in the event payload. The preview should NOT be
      // "New message" — instead it should remain null/unchanged so
      // backfill can fetch the real content.
      const channelScopeId = ChannelScopeId(
        serverId: _serverId,
        value: 'ch-1',
      );
      final homeRepo = _TrackingHomeRepository(
        channels: const [
          HomeChannelSummary(
            scopeId: channelScopeId,
            name: 'general',
            lastMessageId: 'msg-existing',
            lastMessagePreview: 'Previous real message',
          ),
        ],
      );
      final ingress = RealtimeReductionIngress();

      final container = ProviderContainer(
        overrides: [
          appLocalizationsProvider.overrideWithValue(l10n),
          activeServerScopeIdProvider.overrideWithValue(_serverId),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          realtimeSocketClientProvider.overrideWithValue(
            _FakeRealtimeSocketClient(),
          ),
          homeRepositoryProvider.overrideWithValue(homeRepo),
          sidebarOrderRepositoryProvider.overrideWithValue(
            FakeSidebarOrderRepository(),
          ),
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          conversationLocalStoreProvider.overrideWithValue(
            FakeConversationLocalStore(),
          ),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          agentsRepositoryProvider.overrideWithValue(
            const _NoOpAgentsRepository(),
          ),
          agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
          tasksRepositoryProvider.overrideWithValue(
            const _NoOpTasksRepository(),
          ),
          threadRepositoryProvider.overrideWithValue(
            const _NoOpThreadRepository(),
          ),
          inboxRepositoryProvider.overrideWithValue(
            const _NoOpInboxRepository(),
          ),
          serverListRepositoryProvider.overrideWithValue(
            const _NoOpServerListRepository(),
          ),
          crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
          previewMessageFetcherProvider.overrideWithValue(
            (_, __) async => null,
          ),
          sessionStoreProvider.overrideWith(
            () => _PresetSessionStore('user-other'),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await ingress.dispose();
      });

      await container.read(homeListStoreProvider.notifier).load();

      // Activate the event router.
      container.read(domainRuntimeEventRouterProvider);

      // Fire message:new with empty content and NO attachments.
      // This simulates a WS event that doesn't include attachments
      // (e.g., image was sent but WS only forwards minimal fields).
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime.now(),
        payload: {
          'channelId': 'ch-1',
          'id': 'msg-empty-1',
          'content': '',
          'createdAt': DateTime.now().toIso8601String(),
          'senderId': 'user-123',
          'senderName': 'Alice',
          'senderType': 'user',
          'messageType': 'message',
          // NO attachments field
        },
      ));
      await Future<void>.delayed(Duration.zero);

      final homeState = container.read(homeListStoreProvider);
      final channel = homeState.channels.firstWhere(
        (c) => c.scopeId == channelScopeId,
      );

      // After fix: preview must NOT be "New message". Either:
      // - The preview is left unchanged (preserving old real content), OR
      // - The preview is null (triggering backfill to fetch real content).
      // Both are acceptable. "New message" is the WRONG answer.
      expect(
        channel.lastMessagePreview,
        isNot(l10n.previewFallback),
        reason: 'Empty-content + no-attachments message from WS must NOT write '
            '"New message" as preview — it should trigger backfill instead',
      );
    },
  );

  // =========================================================================
  // T5: PreviewBackfillService fetcher resolves attachment-only message
  // =========================================================================
  test(
    'BUG-1+3: Fetcher resolves attachment-only API response to correct label',
    () async {
      // Setup: The production previewMessageFetcherProvider receives a raw
      // API response with content="" and an image attachment. It must resolve
      // to l10n.previewImage via MessagePreviewResolver, NOT return "".
      //
      // We test this by calling the default fetcher implementation
      // (not an override) with a mocked Dio response.
      final dioClient = FakeAppDioClient(
        responses: {
          ('GET', '/messages/channel/ch-img'): {
            'messages': [
              {
                'id': 'msg-img-1',
                'content': '',
                'createdAt': '2026-05-19T10:00:00Z',
                'messageType': 'message',
                'isDeleted': false,
                'attachments': [
                  {'name': 'vacation.jpg', 'type': 'image/jpeg'},
                ],
              },
            ],
          },
        },
      );

      final container = ProviderContainer(
        overrides: [
          appLocalizationsProvider.overrideWithValue(l10n),
          appDioClientProvider.overrideWithValue(dioClient),
        ],
      );
      addTearDown(container.dispose);

      final fetcher = container.read(previewMessageFetcherProvider);
      final result = await fetcher('server-1', 'ch-img');

      expect(result, isNotNull);
      expect(
        result!.preview,
        l10n.previewImage,
        reason: 'Fetcher must pass attachment-only message through '
            'MessagePreviewResolver and produce "Image" label',
      );
      expect(result.messageId, 'msg-img-1');
    },
  );
}

// ---------------------------------------------------------------------------
// Minimal no-op repository fakes (only need to not crash)
// ---------------------------------------------------------------------------

class _NoOpAgentsRepository implements AgentsRepository {
  const _NoOpAgentsRepository();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoOpTasksRepository implements TasksRepository {
  const _NoOpTasksRepository();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoOpThreadRepository implements ThreadRepository {
  const _NoOpThreadRepository();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoOpInboxRepository implements InboxRepository {
  const _NoOpInboxRepository();

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async =>
      const InboxResponse(
        items: [],
        totalCount: 0,
        totalUnreadCount: 0,
        hasMore: false,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoOpServerListRepository implements ServerListRepository {
  const _NoOpServerListRepository();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
