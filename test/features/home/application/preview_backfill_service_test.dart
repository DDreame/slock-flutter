// =============================================================================
// #567 Phase A — Channel/Inbox Preview Backfill (test-only)
//
// Feature: Fill missing lastMessagePreview on channels/DMs after load.
// Phase 1: Check SQLite cache. Phase 2: Lazy-load from API (concurrency-capped,
// viewport-prioritized).
//
// Phase B: Implement PreviewBackfillService + wire into HomeListStore.
//
// All tests skip:true — Phase A only.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/preview_backfill_service.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_channel_row.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';

import '../../../support/support.dart';
import '../../../stores/session/session_store_persistence_test.dart'
    show FakeAuthRepository;

// ---------------------------------------------------------------------------
// FakeMessageApi — simulates GET /messages/channel/{id}?limit=1
// ---------------------------------------------------------------------------

/// Records which channel IDs had their messages fetched, and returns
/// preset single-message responses for lazy-load testing.
class FakeMessageApi {
  final List<String> fetchedChannelIds = [];
  final Map<String, FakeMessageResponse> _responses = {};
  int _activeFetches = 0;
  int peakConcurrency = 0;

  /// Completers for controlling when each fetch resolves.
  final Map<String, Completer<void>> _completers = {};

  /// Seed a response for a channel ID.
  void seedResponse(
    String channelId, {
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) {
    _responses[channelId] = FakeMessageResponse(
      messageId: messageId,
      preview: preview,
      activityAt: activityAt,
    );
  }

  /// Seed a delayed response (controlled by completer).
  void seedDelayedResponse(
    String channelId, {
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) {
    _responses[channelId] = FakeMessageResponse(
      messageId: messageId,
      preview: preview,
      activityAt: activityAt,
    );
    _completers[channelId] = Completer<void>();
  }

  /// Complete a delayed fetch so it resolves.
  void completeFetch(String channelId) {
    _completers[channelId]?.complete();
  }

  /// Simulate a fetch for the given channel ID.
  Future<FakeMessageResponse?> fetchLastMessage(String channelId) async {
    fetchedChannelIds.add(channelId);
    _activeFetches++;
    if (_activeFetches > peakConcurrency) {
      peakConcurrency = _activeFetches;
    }

    // Wait for completer if delayed.
    if (_completers.containsKey(channelId)) {
      await _completers[channelId]!.future;
    }

    _activeFetches--;
    return _responses[channelId];
  }
}

class FakeMessageResponse {
  const FakeMessageResponse({
    required this.messageId,
    required this.preview,
    required this.activityAt,
  });

  final String messageId;
  final String preview;
  final DateTime activityAt;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const serverId = ServerScopeId('server-1');

  HomeChannelSummary makeChannel(
    String id, {
    String? lastMessagePreview,
    String? lastMessageId,
  }) {
    return HomeChannelSummary(
      scopeId: ChannelScopeId(serverId: serverId, value: id),
      name: '#$id',
      lastMessageId: lastMessageId,
      lastMessagePreview: lastMessagePreview,
    );
  }

  group('PreviewBackfillService', () {
    // T1: SQLite cache hit fills preview
    test(
      'SQLite cache hit fills preview for channels missing lastMessagePreview',
      skip: true,
      () async {
        // Setup: HomeListStore loaded with 3 channels — API returned null
        // previews for all. SQLite has cached previews for 2 of them.
        final localStore = FakeConversationLocalStore();
        // Pre-seed SQLite with cached previews for channels 'ch-1' and 'ch-2'.
        await localStore.upsertConversationSummaries([
          LocalConversationSummaryUpsert(
            serverId: 'server-1',
            conversationId: 'ch-1',
            surface: 'channel',
            title: '#ch-1',
            sortIndex: 0,
            lastMessageId: 'msg-1',
            lastMessagePreview: 'Hello from cache',
            lastActivityAt: DateTime.parse('2026-05-01T10:00:00Z'),
          ),
          LocalConversationSummaryUpsert(
            serverId: 'server-1',
            conversationId: 'ch-2',
            surface: 'channel',
            title: '#ch-2',
            sortIndex: 1,
            lastMessageId: 'msg-2',
            lastMessagePreview: 'Second cached msg',
            lastActivityAt: DateTime.parse('2026-05-01T11:00:00Z'),
          ),
        ]);

        final channels = [
          makeChannel('ch-1'),
          makeChannel('ch-2'),
          makeChannel('ch-3'),
        ];

        final container = ProviderContainer(
          overrides: [
            appLocalizationsProvider.overrideWithValue(
              lookupAppLocalizations(const Locale('en')),
            ),
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            activeServerScopeIdProvider.overrideWithValue(serverId),
            conversationLocalStoreProvider.overrideWithValue(localStore),
            sidebarOrderRepositoryProvider.overrideWithValue(
              FakeSidebarOrderRepository(),
            ),
            homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
              (scopeId) async => HomeWorkspaceSnapshot(
                serverId: scopeId,
                channels: channels,
                directMessages: const [],
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Load the home list first.
        await container.read(homeListStoreProvider.notifier).load();

        // Run backfill.
        await container
            .read(previewBackfillServiceProvider.notifier)
            .backfill(channels);

        // Assert: 2/3 channels should now have preview from cache.
        final state = container.read(homeListStoreProvider);
        final ch1 = state.channels.firstWhere(
          (c) => c.scopeId.value == 'ch-1',
        );
        final ch2 = state.channels.firstWhere(
          (c) => c.scopeId.value == 'ch-2',
        );
        final ch3 = state.channels.firstWhere(
          (c) => c.scopeId.value == 'ch-3',
        );
        expect(ch1.lastMessagePreview, 'Hello from cache');
        expect(ch2.lastMessagePreview, 'Second cached msg');
        expect(ch3.lastMessagePreview, isNull);
      },
    );

    // T2: Lazy load fills remaining nulls
    test(
      'lazy-load API fills channels with no SQLite cache',
      skip: true,
      () async {
        // Setup: 1 channel with no SQLite cache. After backfill Phase 1 (cache
        // check) returns null, Phase 2 should call GET /messages/channel/{id}
        // and populate the preview.
        final localStore = FakeConversationLocalStore();
        final messageApi = FakeMessageApi();
        messageApi.seedResponse(
          'ch-1',
          messageId: 'msg-remote-1',
          preview: 'Fetched from API',
          activityAt: DateTime.parse('2026-05-17T15:00:00Z'),
        );

        final channels = [makeChannel('ch-1')];

        final container = ProviderContainer(
          overrides: [
            appLocalizationsProvider.overrideWithValue(
              lookupAppLocalizations(const Locale('en')),
            ),
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            activeServerScopeIdProvider.overrideWithValue(serverId),
            conversationLocalStoreProvider.overrideWithValue(localStore),
            sidebarOrderRepositoryProvider.overrideWithValue(
              FakeSidebarOrderRepository(),
            ),
            homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
              (scopeId) async => HomeWorkspaceSnapshot(
                serverId: scopeId,
                channels: channels,
                directMessages: const [],
              ),
            ),
            // Phase B will inject the message API via a provider.
            previewMessageFetcherProvider.overrideWithValue(
              (serverId, channelId) async {
                final resp = await messageApi.fetchLastMessage(channelId);
                if (resp == null) return null;
                return PreviewFetchResult(
                  messageId: resp.messageId,
                  preview: resp.preview,
                  activityAt: resp.activityAt,
                );
              },
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();

        // After backfill, channel should have preview from API.
        await container
            .read(previewBackfillServiceProvider.notifier)
            .backfill(channels);

        final state = container.read(homeListStoreProvider);
        final ch1 = state.channels.firstWhere(
          (c) => c.scopeId.value == 'ch-1',
        );
        expect(ch1.lastMessagePreview, 'Fetched from API');
        expect(messageApi.fetchedChannelIds, contains('ch-1'));
      },
    );

    // T3: Concurrency cap (max 5)
    test(
      'limits concurrent lazy-load API calls to maxConcurrent (5)',
      skip: true,
      () async {
        // Setup: 10 channels all need lazy load (no cache).
        final messageApi = FakeMessageApi();
        final channels = <HomeChannelSummary>[];

        for (var i = 0; i < 10; i++) {
          final id = 'ch-$i';
          channels.add(makeChannel(id));
          messageApi.seedDelayedResponse(
            id,
            messageId: 'msg-$i',
            preview: 'Preview $i',
            activityAt: DateTime.parse('2026-05-01T10:00:00Z'),
          );
        }

        final container = ProviderContainer(
          overrides: [
            appLocalizationsProvider.overrideWithValue(
              lookupAppLocalizations(const Locale('en')),
            ),
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            activeServerScopeIdProvider.overrideWithValue(serverId),
            conversationLocalStoreProvider.overrideWithValue(
              FakeConversationLocalStore(),
            ),
            sidebarOrderRepositoryProvider.overrideWithValue(
              FakeSidebarOrderRepository(),
            ),
            homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
              (scopeId) async => HomeWorkspaceSnapshot(
                serverId: scopeId,
                channels: channels,
                directMessages: const [],
              ),
            ),
            previewMessageFetcherProvider.overrideWithValue(
              (serverId, channelId) async {
                final resp = await messageApi.fetchLastMessage(channelId);
                if (resp == null) return null;
                return PreviewFetchResult(
                  messageId: resp.messageId,
                  preview: resp.preview,
                  activityAt: resp.activityAt,
                );
              },
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();

        // Start backfill (non-blocking — returns future).
        final backfillFuture = container
            .read(previewBackfillServiceProvider.notifier)
            .backfill(channels);

        // Allow initial batch to start.
        await Future<void>.delayed(Duration.zero);

        // At most 5 should be in flight concurrently.
        expect(messageApi.peakConcurrency, lessThanOrEqualTo(5));

        // Complete all to allow backfill to finish.
        for (var i = 0; i < 10; i++) {
          messageApi.completeFetch('ch-$i');
        }
        await backfillFuture;

        // All 10 should have been fetched eventually.
        expect(messageApi.fetchedChannelIds.length, equals(10));
      },
    );

    // T4: Viewport priority ordering
    test(
      'loads visible channels before offscreen channels',
      skip: true,
      () async {
        // Setup: 10 channels, 3 marked as visible. Visible should load first.
        final messageApi = FakeMessageApi();
        final channels = <HomeChannelSummary>[];

        for (var i = 0; i < 10; i++) {
          final id = 'ch-$i';
          channels.add(makeChannel(id));
          messageApi.seedResponse(
            id,
            messageId: 'msg-$i',
            preview: 'Preview $i',
            activityAt: DateTime.parse('2026-05-01T10:00:00Z'),
          );
        }

        final container = ProviderContainer(
          overrides: [
            appLocalizationsProvider.overrideWithValue(
              lookupAppLocalizations(const Locale('en')),
            ),
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            activeServerScopeIdProvider.overrideWithValue(serverId),
            conversationLocalStoreProvider.overrideWithValue(
              FakeConversationLocalStore(),
            ),
            sidebarOrderRepositoryProvider.overrideWithValue(
              FakeSidebarOrderRepository(),
            ),
            homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
              (scopeId) async => HomeWorkspaceSnapshot(
                serverId: scopeId,
                channels: channels,
                directMessages: const [],
              ),
            ),
            previewMessageFetcherProvider.overrideWithValue(
              (serverId, channelId) async {
                final resp = await messageApi.fetchLastMessage(channelId);
                if (resp == null) return null;
                return PreviewFetchResult(
                  messageId: resp.messageId,
                  preview: resp.preview,
                  activityAt: resp.activityAt,
                );
              },
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();

        // Run backfill with viewport priority.
        await container.read(previewBackfillServiceProvider.notifier).backfill(
          channels,
          visibleChannelIds: {'ch-7', 'ch-8', 'ch-9'},
        );

        // Visible channels (ch-7, ch-8, ch-9) should be fetched before
        // offscreen channels (ch-0 through ch-6).
        final visibleIndices = [
          messageApi.fetchedChannelIds.indexOf('ch-7'),
          messageApi.fetchedChannelIds.indexOf('ch-8'),
          messageApi.fetchedChannelIds.indexOf('ch-9'),
        ];
        final offscreenIndices = [
          for (var i = 0; i < 7; i++)
            messageApi.fetchedChannelIds.indexOf('ch-$i'),
        ];

        // All visible should appear before any offscreen.
        for (final vIdx in visibleIndices) {
          expect(vIdx, greaterThanOrEqualTo(0));
          for (final oIdx in offscreenIndices) {
            if (oIdx >= 0) {
              expect(vIdx, lessThan(oIdx));
            }
          }
        }
      },
    );

    // T5: Realtime event updates preview (protects against overwrite)
    test(
      'realtime message:new event is not overwritten by backfill',
      skip: true,
      () async {
        // Setup: Channel receives a realtime message:new event after backfill
        // starts. The realtime preview should NOT be overwritten by the
        // (stale) lazy-load result.
        final localStore = FakeConversationLocalStore();
        final messageApi = FakeMessageApi();
        messageApi.seedDelayedResponse(
          'ch-1',
          messageId: 'msg-old',
          preview: 'Old API preview',
          activityAt: DateTime.parse('2026-05-01T10:00:00Z'),
        );

        final channels = [makeChannel('ch-1')];
        final ingress = RealtimeReductionIngress();

        final container = ProviderContainer(
          overrides: [
            appLocalizationsProvider.overrideWithValue(
              lookupAppLocalizations(const Locale('en')),
            ),
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            activeServerScopeIdProvider.overrideWithValue(serverId),
            conversationLocalStoreProvider.overrideWithValue(localStore),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            sidebarOrderRepositoryProvider.overrideWithValue(
              FakeSidebarOrderRepository(),
            ),
            homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
              (scopeId) async => HomeWorkspaceSnapshot(
                serverId: scopeId,
                channels: channels,
                directMessages: const [],
              ),
            ),
            previewMessageFetcherProvider.overrideWithValue(
              (serverId, channelId) async {
                final resp = await messageApi.fetchLastMessage(channelId);
                if (resp == null) return null;
                return PreviewFetchResult(
                  messageId: resp.messageId,
                  preview: resp.preview,
                  activityAt: resp.activityAt,
                );
              },
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await ingress.dispose();
        });

        await container.read(homeListStoreProvider.notifier).load();

        // Start backfill — API fetch is delayed.
        final backfillFuture = container
            .read(previewBackfillServiceProvider.notifier)
            .backfill(channels);
        await Future<void>.delayed(Duration.zero);

        // Before the API responds, a realtime event arrives with newer preview.
        container.read(homeListStoreProvider.notifier).updateChannelLastMessage(
              conversationId: 'ch-1',
              messageId: 'msg-new',
              preview: 'Fresh realtime msg',
              activityAt: DateTime.parse('2026-05-18T09:00:00Z'),
            );

        // Now let the API respond.
        messageApi.completeFetch('ch-1');
        await backfillFuture;

        // Realtime preview should be preserved (not overwritten).
        final state = container.read(homeListStoreProvider);
        final ch1 = state.channels.firstWhere(
          (c) => c.scopeId.value == 'ch-1',
        );
        expect(ch1.lastMessagePreview, 'Fresh realtime msg');
        expect(ch1.lastMessageId, 'msg-new');
      },
    );

    // T6: Integration — widget renders backfilled preview
    testWidgets(
      'channel row displays backfilled preview text instead of fallback',
      skip: true,
      (tester) async {
        // Setup: Channel with null preview from API, but SQLite has cache.
        final localStore = FakeConversationLocalStore();
        await localStore.upsertConversationSummaries([
          LocalConversationSummaryUpsert(
            serverId: 'server-1',
            conversationId: 'ch-1',
            surface: 'channel',
            title: '#ch-1',
            sortIndex: 0,
            lastMessageId: 'msg-cached',
            lastMessagePreview: 'Cached preview text',
            lastActivityAt: DateTime.parse('2026-05-17T12:00:00Z'),
          ),
        ]);

        final channels = [
          makeChannel('ch-1'), // No preview from API, but has cache
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appLocalizationsProvider.overrideWithValue(
                lookupAppLocalizations(const Locale('en')),
              ),
              secureStorageProvider.overrideWithValue(FakeSecureStorage()),
              authRepositoryProvider
                  .overrideWithValue(const FakeAuthRepository()),
              activeServerScopeIdProvider.overrideWithValue(serverId),
              conversationLocalStoreProvider.overrideWithValue(localStore),
              sidebarOrderRepositoryProvider.overrideWithValue(
                FakeSidebarOrderRepository(),
              ),
              homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
                (scopeId) async => HomeWorkspaceSnapshot(
                  serverId: scopeId,
                  channels: channels,
                  directMessages: const [],
                ),
              ),
            ],
            child: MaterialApp(
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    final state = ref.watch(homeListStoreProvider);
                    if (state.status != HomeListStatus.success) {
                      return const SizedBox.shrink();
                    }
                    final ch = state.channels.first;
                    return HomeChannelRow(
                      channel: ch,
                      onTap: () {},
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Load the home store so channel rows render.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(Consumer)),
        );
        await container.read(homeListStoreProvider.notifier).load();
        await tester.pumpAndSettle();

        // Initially shows fallback text (no preview from API).
        expect(find.text('New message'), findsOneWidget);

        // Trigger backfill — should fill from SQLite cache.
        await container
            .read(previewBackfillServiceProvider.notifier)
            .backfill(channels);
        await tester.pumpAndSettle();

        // After backfill, row should show cached preview.
        expect(find.text('Cached preview text'), findsOneWidget);
        expect(find.text('New message'), findsNothing);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------
