import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_realtime_refresh_binding.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';

void main() {
  const serverId = ServerScopeId('server-1');
  final now = DateTime.utc(2026, 5, 5);

  late _FakeInboxRepository repo;
  late RealtimeReductionIngress ingress;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeInboxRepository();
    ingress = RealtimeReductionIngress();
  });

  tearDown(() {
    container.dispose();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        inboxRepositoryProvider.overrideWithValue(repo),
        activeServerScopeIdProvider.overrideWithValue(serverId),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
      ],
    );
  }

  group('InboxRealtimeRefreshBinding', () {
    test('does not trigger refresh when inbox is not loaded', () async {
      container = createContainer();
      container.read(inboxRealtimeRefreshBindingProvider);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        payload: const <String, dynamic>{},
        scopeKey: 'ch-1',
        receivedAt: now,
      ));

      await Future<void>.delayed(const Duration(milliseconds: 2100));
      expect(repo.fetchCallCount, 0);
    });

    test('debounces message:new events', () async {
      container = createContainer();
      await container.read(inboxStoreProvider.notifier).load();
      final callsAfterLoad = repo.fetchCallCount;

      container.read(inboxRealtimeRefreshBindingProvider);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        payload: const <String, dynamic>{},
        scopeKey: 'ch-1',
        seq: 1,
        receivedAt: now,
      ));
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        payload: const <String, dynamic>{},
        scopeKey: 'ch-1',
        seq: 2,
        receivedAt: now,
      ));
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        payload: const <String, dynamic>{},
        scopeKey: 'ch-1',
        seq: 3,
        receivedAt: now,
      ));

      // Before debounce fires
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(repo.fetchCallCount, callsAfterLoad,
          reason: 'should not refresh yet (debounce pending)');

      // After debounce
      await Future<void>.delayed(const Duration(milliseconds: 2000));
      expect(repo.fetchCallCount, callsAfterLoad + 1,
          reason: 'should refresh once after debounce');
    });

    test('dm:new event triggers debounced refresh', () async {
      container = createContainer();
      await container.read(inboxStoreProvider.notifier).load();
      final callsAfterLoad = repo.fetchCallCount;

      container.read(inboxRealtimeRefreshBindingProvider);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'dm:new',
        payload: const <String, dynamic>{},
        scopeKey: 'dm-1',
        seq: 1,
        receivedAt: now,
      ));

      await Future<void>.delayed(const Duration(milliseconds: 2100));
      expect(repo.fetchCallCount, callsAfterLoad + 1);
    });

    test('connect event triggers immediate refresh', () async {
      container = createContainer();
      await container.read(inboxStoreProvider.notifier).load();
      final callsAfterLoad = repo.fetchCallCount;

      container.read(inboxRealtimeRefreshBindingProvider);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'connect',
        payload: const <String, dynamic>{},
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: now,
      ));

      await Future<void>.delayed(Duration.zero);
      expect(repo.fetchCallCount, callsAfterLoad + 1);
    });

    test('unrelated event types are ignored', () async {
      container = createContainer();
      await container.read(inboxStoreProvider.notifier).load();
      final callsAfterLoad = repo.fetchCallCount;

      container.read(inboxRealtimeRefreshBindingProvider);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:updated',
        payload: const <String, dynamic>{},
        scopeKey: 'ch-1',
        seq: 1,
        receivedAt: now,
      ));
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'channel:created',
        payload: const <String, dynamic>{},
        scopeKey: 'ch-2',
        seq: 2,
        receivedAt: now,
      ));

      await Future<void>.delayed(const Duration(milliseconds: 2500));
      expect(repo.fetchCallCount, callsAfterLoad);
    });

    test('connect cancels pending debounce timer', () async {
      container = createContainer();
      await container.read(inboxStoreProvider.notifier).load();
      final callsAfterLoad = repo.fetchCallCount;

      container.read(inboxRealtimeRefreshBindingProvider);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        payload: const <String, dynamic>{},
        scopeKey: 'ch-1',
        seq: 1,
        receivedAt: now,
      ));

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'connect',
        payload: const <String, dynamic>{},
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: now,
      ));

      await Future<void>.delayed(Duration.zero);
      expect(repo.fetchCallCount, callsAfterLoad + 1);

      // After original debounce period — should NOT fire again
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      expect(repo.fetchCallCount, callsAfterLoad + 1);
    });
  });
}

class _FakeInboxRepository implements InboxRepository {
  int fetchCallCount = 0;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    fetchCallCount++;
    return const InboxResponse(
      items: [
        InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          unreadCount: 1,
        ),
      ],
      totalCount: 1,
      totalUnreadCount: 1,
      hasMore: false,
    );
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}
