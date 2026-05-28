// =============================================================================
// #859 — Reconnect Fixes
//
// Load-bearing tests for three fixes:
// 1. Dual-loop disabled: socket.io built-in reconnection is disabled via
//    .disableReconnection(). Verified by inspecting OptionBuilder output.
// 2. Banner 2s grace period: The banner does NOT appear for disconnects
//    shorter than 2000ms (preventing flashes during WiFi handoffs).
// 3. AppLifecycleState.resumed → reconnect: When the app is resumed after
//    backgrounding, syncConnection() fires immediately to restore WebSocket.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/connection_status_banner.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

void main() {
  // ===========================================================================
  // Group 1: Banner grace period (2000ms)
  // ===========================================================================
  group('#859 — Banner grace period', () {
    Widget buildBannerApp({
      required RealtimeConnectionState initialState,
    }) {
      return ProviderScope(
        overrides: [
          realtimeServiceProvider.overrideWith(() {
            return _ControllableRealtimeService(initialState);
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: Column(
              children: [
                ConnectionStatusBanner(),
                Expanded(child: Placeholder()),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets(
      'banner does NOT appear during grace period (sub-2s disconnect)',
      (tester) async {
        await tester.pumpWidget(buildBannerApp(
          initialState: const RealtimeConnectionState(
            status: RealtimeConnectionStatus.disconnected,
          ),
        ));
        // Pump less than the grace period (e.g., 1500ms).
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump();

        // Banner must NOT be visible yet — still within grace period.
        expect(
          find.byKey(const ValueKey('connection-status-banner')),
          findsNothing,
          reason: '#859: Banner must not show during the 2s grace period. '
              'Removing grace timer → banner shows immediately → RED.',
        );
      },
    );

    testWidgets(
      'banner DOES appear after grace period elapses',
      (tester) async {
        await tester.pumpWidget(buildBannerApp(
          initialState: const RealtimeConnectionState(
            status: RealtimeConnectionStatus.disconnected,
          ),
        ));
        // Advance past grace period.
        await tester.pump(bannerGracePeriod);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('connection-status-banner')),
          findsOneWidget,
          reason: '#859: Banner must appear after 2s grace period.',
        );
      },
    );

    testWidgets(
      'sub-2s reconnection prevents banner entirely',
      (tester) async {
        await tester.pumpWidget(buildBannerApp(
          initialState: const RealtimeConnectionState(
            status: RealtimeConnectionStatus.disconnected,
          ),
        ));
        // Advance 1s (within grace period).
        await tester.pump(const Duration(milliseconds: 1000));

        // Now reconnect before grace fires.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ConnectionStatusBanner)),
        );
        container.read(realtimeServiceProvider.notifier).state =
            const RealtimeConnectionState(
          status: RealtimeConnectionStatus.connected,
        );
        // Advance past the original grace period — timer should be cancelled.
        await tester.pump(const Duration(milliseconds: 2000));
        await tester.pump();

        // Banner must NEVER have appeared.
        expect(
          find.byKey(const ValueKey('connection-status-banner')),
          findsNothing,
          reason: '#859: Reconnection within grace period must cancel banner. '
              'Removing grace cancel logic → banner appears → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // Group 2: AppLifecycleState.resumed → reconnect
  // ===========================================================================
  group('#859 — App lifecycle resume reconnect', () {
    test(
      'resumed lifecycle triggers syncConnection when disconnected',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final socket = _FakeRealtimeSocketClient();
        final storage = FakeSecureStorage();
        final ingress = RealtimeReductionIngress();
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeSocketClientProvider.overrideWithValue(socket),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await ingress.dispose();
        });

        // Boot lifecycle binding, login, and mark app ready.
        container.read(realtimeLifecycleBindingProvider);
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'test@example.com', password: 'password');
        container.read(appReadyProvider.notifier).state = true;
        await Future<void>.delayed(Duration.zero);

        // Should have connected once.
        expect(socket.connectCalls, 1);

        // Simulate disconnect (OS killed WebSocket during backgrounding).
        await container.read(realtimeServiceProvider.notifier).disconnect();
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(realtimeServiceProvider).status,
          RealtimeConnectionStatus.disconnected,
        );

        // Simulate AppLifecycleState.resumed.
        final binding = TestWidgetsFlutterBinding.instance;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);

        // syncConnection should reconnect because authenticated + disconnected.
        expect(
          socket.connectCalls,
          2,
          reason: '#859: On app resume when disconnected, syncConnection must '
              'trigger connect(). Removing lifecycle observer → stays at 1 → RED.',
        );
      },
    );

    test(
      'resumed lifecycle does NOT reconnect when already connected',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final socket = _FakeRealtimeSocketClient();
        final storage = FakeSecureStorage();
        final ingress = RealtimeReductionIngress();
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeSocketClientProvider.overrideWithValue(socket),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await ingress.dispose();
        });

        container.read(realtimeLifecycleBindingProvider);
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'test@example.com', password: 'password');
        container.read(appReadyProvider.notifier).state = true;
        await Future<void>.delayed(Duration.zero);

        expect(socket.connectCalls, 1);

        // App is still connected. Simulate resume.
        final binding = TestWidgetsFlutterBinding.instance;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);

        // Should NOT call connect again — already connected.
        expect(
          socket.connectCalls,
          1,
          reason:
              '#859: Resume when connected must not trigger duplicate connect.',
        );
      },
    );

    test(
      'paused/inactive lifecycle does NOT trigger reconnect',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final socket = _FakeRealtimeSocketClient();
        final storage = FakeSecureStorage();
        final ingress = RealtimeReductionIngress();
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeSocketClientProvider.overrideWithValue(socket),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await ingress.dispose();
        });

        container.read(realtimeLifecycleBindingProvider);
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'test@example.com', password: 'password');
        container.read(appReadyProvider.notifier).state = true;
        await Future<void>.delayed(Duration.zero);

        expect(socket.connectCalls, 1);

        // Disconnect, then send paused/inactive (not resumed).
        await container.read(realtimeServiceProvider.notifier).disconnect();
        await Future<void>.delayed(Duration.zero);

        final binding = TestWidgetsFlutterBinding.instance;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await Future<void>.delayed(Duration.zero);

        // Should not reconnect on paused/inactive — only resumed.
        expect(
          socket.connectCalls,
          1,
          reason: '#859: Only resumed triggers reconnect, not paused/inactive.',
        );
      },
    );
  });

  // ===========================================================================
  // Group 3: Dual-loop disabled (disableReconnection)
  // ===========================================================================
  group('#859 — Dual-loop disabled', () {
    test(
      'SocketIoRealtimeSocketClient options have reconnection disabled',
      () {
        // Build the socket client with default options.
        const options = RealtimeSocketOptions(
          uri: 'https://test.slock.invalid',
        );
        final client = SocketIoRealtimeSocketClient(options: options);
        addTearDown(() async => client.dispose());

        // The underlying socket.io options must have reconnection set to false.
        // Removing .disableReconnection() from the OptionBuilder → this fails RED.
        final socketOpts = client.socketOptions;
        expect(
          socketOpts?['reconnection'],
          false,
          reason: '#859: .disableReconnection() must set reconnection=false. '
              'Removing it → reconnection defaults to true → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // Group 4: P1 — refreshSavedMessageIds disposed guard
  // ===========================================================================
  group('#859 — P1 refreshSavedMessageIds disposed guard', () {
    test(
      'does not throw when container disposed during await',
      () async {
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('srv-1'),
            value: 'ch-1',
          ),
        );
        final savedRepo = _SlowSavedMessagesRepository();
        final convRepo = _FakeConversationRepository();
        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(convRepo),
            savedMessagesRepositoryProvider.overrideWithValue(savedRepo),
          ],
        );
        final sub =
            container.listen(conversationDetailStoreProvider, (_, __) {});

        // Load data so store reaches success state.
        await container.read(conversationDetailStoreProvider.notifier).load();
        await Future<void>.delayed(Duration.zero);

        // Start refreshSavedMessageIds — it will await the completer.
        final future = container
            .read(conversationDetailStoreProvider.notifier)
            .refreshSavedMessageIds();

        // Dispose container before completing the saved messages fetch.
        sub.close();
        container.dispose();

        // Complete the completer — the guard must prevent ref.read/state access.
        savedRepo.completer.complete({'msg-1'});

        // This must not throw StateError.
        await expectLater(future, completes);
      },
    );
  });

  // ===========================================================================
  // Group 5: P2 — Sync livelock defensive break
  // ===========================================================================
  group('#859 — P2 sync livelock defensive break', () {
    test(
      'hasMore:true with empty messages and no currentSeq emits batch-complete',
      () async {
        final ingress = RealtimeReductionIngress();
        addTearDown(ingress.dispose);
        final socket = _FakeRealtimeSocketClient();
        final container = ProviderContainer(
          overrides: [
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeSocketClientProvider.overrideWithValue(socket),
            realtimeWatchdogTimerFactoryProvider
                .overrideWithValue((_, __) => _NoopTimer()),
            realtimeBackoffSleeperProvider.overrideWithValue((_) async {}),
          ],
        );
        addTearDown(container.dispose);

        // Connect service so signal processing is active.
        await container.read(realtimeServiceProvider.notifier).connect();
        await Future<void>.delayed(Duration.zero);

        // Collect events from ingress.
        final events = <RealtimeEventEnvelope>[];
        ingress.acceptedEvents.listen(events.add);

        // Simulate a sync:resume:response with hasMore:true but empty messages
        // and no currentSeq — this is the livelock edge case.
        socket.simulateRawEvent('sync:resume:response', [
          {'messages': <dynamic>[], 'hasMore': true},
        ]);
        await Future<void>.delayed(Duration.zero);

        // The defensive break should emit batch-complete instead of re-emitting
        // sync:resume, preventing an infinite loop.
        expect(
          events.any((e) => e.eventType == syncBatchCompleteEvent),
          isTrue,
          reason: '#859 P2: Empty hasMore response without cursor must emit '
              'batch-complete. Removing defensive break → re-emits sync:resume '
              '→ infinite loop → RED.',
        );

        // Verify no sync:resume was re-emitted.
        expect(
          socket.emittedEvents
              .where((e) => e.eventName == 'sync:resume')
              .length,
          0,
          reason:
              '#859 P2: Must NOT re-emit sync:resume on livelock condition.',
        );

        container.dispose();
      },
    );

    test(
      'hasMore:true with messages continues sync (no livelock break)',
      () async {
        final ingress = RealtimeReductionIngress();
        addTearDown(ingress.dispose);
        final socket = _FakeRealtimeSocketClient();
        final container = ProviderContainer(
          overrides: [
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeSocketClientProvider.overrideWithValue(socket),
            realtimeWatchdogTimerFactoryProvider
                .overrideWithValue((_, __) => _NoopTimer()),
            realtimeBackoffSleeperProvider.overrideWithValue((_) async {}),
          ],
        );
        addTearDown(container.dispose);

        await container.read(realtimeServiceProvider.notifier).connect();
        await Future<void>.delayed(Duration.zero);

        // Simulate response WITH messages + hasMore:true — should continue.
        socket.simulateRawEvent('sync:resume:response', [
          {
            'messages': [
              {
                'eventType': 'message:new',
                'scopeKey': 'server:1/channel:2',
                'seq': 5,
                'id': 'm1',
              },
            ],
            'hasMore': true,
            'currentSeq': 5,
          },
        ]);
        await Future<void>.delayed(Duration.zero);

        // Should re-emit sync:resume to continue fetching.
        expect(
          socket.emittedEvents
              .where((e) => e.eventName == 'sync:resume')
              .length,
          1,
          reason: 'Normal hasMore with messages should continue sync loop.',
        );

        container.dispose();
      },
    );

    test(
      'hasMore:true with empty messages and stale currentSeq emits batch-complete',
      () async {
        final ingress = RealtimeReductionIngress();
        addTearDown(ingress.dispose);
        final socket = _FakeRealtimeSocketClient();
        final container = ProviderContainer(
          overrides: [
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeSocketClientProvider.overrideWithValue(socket),
            realtimeWatchdogTimerFactoryProvider
                .overrideWithValue((_, __) => _NoopTimer()),
            realtimeBackoffSleeperProvider.overrideWithValue((_) async {}),
          ],
        );
        addTearDown(container.dispose);

        await container.read(realtimeServiceProvider.notifier).connect();
        await Future<void>.delayed(Duration.zero);

        // Pre-seed ingress with seq 42 so currentSeq:42 is stale.
        ingress.advanceSeq(RealtimeEventEnvelope.globalScopeKey, 42);

        // Collect events from ingress.
        final events = <RealtimeEventEnvelope>[];
        ingress.acceptedEvents.listen(events.add);

        // Simulate: hasMore:true, messages:[], currentSeq:42 (stale — won't
        // advance past the already-known 42). This is the edge case where
        // currentSeq IS provided but doesn't advance the cursor.
        socket.simulateRawEvent('sync:resume:response', [
          {
            'messages': <dynamic>[],
            'hasMore': true,
            'currentSeq': 42,
            'scopeKey': RealtimeEventEnvelope.globalScopeKey,
          },
        ]);
        await Future<void>.delayed(Duration.zero);

        // The defensive break must fire: newSeq (42) <= prevSeq (42).
        expect(
          events.any((e) => e.eventType == syncBatchCompleteEvent),
          isTrue,
          reason: '#859 P2: Stale currentSeq (no cursor progress) with empty '
              'messages must emit batch-complete. Removing newSeq<=prevSeq '
              'check → re-emits sync:resume → infinite loop → RED.',
        );

        // Verify no sync:resume was re-emitted.
        expect(
          socket.emittedEvents
              .where((e) => e.eventName == 'sync:resume')
              .length,
          0,
          reason: '#859 P2: Must NOT re-emit sync:resume when cursor stalled.',
        );

        container.dispose();
      },
    );
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _ControllableRealtimeService extends RealtimeService {
  _ControllableRealtimeService(this._initialState);

  final RealtimeConnectionState _initialState;

  @override
  RealtimeConnectionState build() => _initialState;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}
}

class _EmittedEvent {
  _EmittedEvent(this.eventName, this.payload);
  final String eventName;
  final Object? payload;
}

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  final StreamController<RealtimeSocketSignal> _signalsController =
      StreamController<RealtimeSocketSignal>.broadcast();

  bool _isConnected = false;
  int connectCalls = 0;
  int disconnectCalls = 0;
  final List<_EmittedEvent> emittedEvents = [];

  @override
  Stream<RealtimeSocketSignal> get signals => _signalsController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    connectCalls += 1;
    _isConnected = true;
    _signalsController.add(const RealtimeSocketConnected());
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    _isConnected = false;
  }

  @override
  void emit(String eventName, Object? payload) {
    emittedEvents.add(_EmittedEvent(eventName, payload));
  }

  void simulateRawEvent(String eventName, Object? payload) {
    _signalsController.add(
      RealtimeSocketRawEvent(eventName: eventName, payload: payload),
    );
  }

  @override
  Future<void> dispose() async {
    await _signalsController.close();
  }
}

class _NoopTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}

class _SlowSavedMessagesRepository implements SavedMessagesRepository {
  final Completer<Set<String>> completer = Completer<Set<String>>();

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) =>
      completer.future;

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

class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return ConversationDetailSnapshot(
      target: target,
      title: 'Test',
      messages: [
        ConversationMessageSummary(
          id: 'msg-1',
          content: 'hello',
          createdAt: DateTime(2026, 5, 1),
          senderType: 'agent',
          messageType: 'text',
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
