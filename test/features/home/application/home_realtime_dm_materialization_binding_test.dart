import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_realtime_dm_materialization_binding.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';

import '../../../core/local_data/fake_conversation_local_store.dart';
import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  final List<(String, Object?)> emitted = [];

  @override
  Stream<RealtimeSocketSignal> get signals => const Stream.empty();

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void emit(String eventName, Object? payload) {
    emitted.add((eventName, payload));
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  const serverId = ServerScopeId('server-1');

  ProviderContainer createContainer({
    required _FakeRealtimeSocketClient fakeSocket,
    List<HomeDirectMessageSummary> existingDms = const [],
  }) {
    final ingress = RealtimeReductionIngress();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        realtimeSocketClientProvider.overrideWithValue(fakeSocket),
        activeServerScopeIdProvider.overrideWithValue(serverId),
        conversationLocalStoreProvider.overrideWithValue(
          FakeConversationLocalStore(),
        ),
        homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
          (scopeId) async => HomeWorkspaceSnapshot(
            serverId: scopeId,
            channels: const [],
            directMessages: existingDms,
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await ingress.dispose();
    });
    return container;
  }

  test('dm:new materializes new DM in home list', () async {
    final fakeSocket = _FakeRealtimeSocketClient();
    final container = createContainer(fakeSocket: fakeSocket);

    container.read(homeRealtimeDmMaterializationBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeDmNewEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: const {
              'channelId': 'dm-new-conversation',
              'participant': {'displayName': 'Bob'},
            },
          ),
        );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(homeListStoreProvider);
    expect(state.directMessages.length, 1);
    expect(state.directMessages.first.scopeId.value, 'dm-new-conversation');
    expect(state.directMessages.first.title, 'Bob');
  });

  test('dm:new emits join:channel back to server', () async {
    final fakeSocket = _FakeRealtimeSocketClient();
    final container = createContainer(fakeSocket: fakeSocket);

    container.read(homeRealtimeDmMaterializationBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeDmNewEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: const {'channelId': 'dm-new-conversation'},
          ),
        );
    await Future<void>.delayed(Duration.zero);

    expect(fakeSocket.emitted, hasLength(1));
    expect(fakeSocket.emitted.first.$1, 'join:channel');
    expect(fakeSocket.emitted.first.$2, 'dm-new-conversation');
  });

  test('dm:new before homeListStore success still emits join:channel',
      () async {
    final fakeSocket = _FakeRealtimeSocketClient();
    final container = createContainer(fakeSocket: fakeSocket);

    container.read(homeRealtimeDmMaterializationBindingProvider);
    // Do NOT call load() — homeListStore stays in initial status

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeDmNewEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: const {
              'channelId': 'dm-early',
              'displayName': 'Early Bob'
            },
          ),
        );
    await Future<void>.delayed(Duration.zero);

    expect(fakeSocket.emitted, hasLength(1));
    expect(fakeSocket.emitted.first.$1, 'join:channel');
    expect(fakeSocket.emitted.first.$2, 'dm-early');

    final state = container.read(homeListStoreProvider);
    expect(
      state.directMessages.any((dm) => dm.scopeId.value == 'dm-early'),
      isFalse,
      reason: 'DM should not be materialized when homeListStore is not ready',
    );
  });

  test('dm:new for already-known DM is deduped', () async {
    final fakeSocket = _FakeRealtimeSocketClient();
    final container = createContainer(
      fakeSocket: fakeSocket,
      existingDms: const [
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(
            serverId: serverId,
            value: 'dm-existing',
          ),
          title: 'Existing DM',
        ),
      ],
    );

    container.read(homeRealtimeDmMaterializationBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeDmNewEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: const {
              'channelId': 'dm-existing',
              'displayName': 'Existing'
            },
          ),
        );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(homeListStoreProvider);
    expect(state.directMessages.length, 1);
    expect(state.directMessages.first.title, 'Existing DM');
    expect(fakeSocket.emitted, hasLength(1));
  });
}
