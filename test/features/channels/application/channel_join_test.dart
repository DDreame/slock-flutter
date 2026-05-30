// =============================================================================
// B126 PR B — Load-bearing test for channel join (POST /channels/{id}/join).
//
// Proves:
// 1. ChannelManagementStore.joinChannel() calls repository.joinChannel().
// 2. After success, emits 'join:channel' on the realtime socket.
// 3. After success, refreshes the home list.
// 4. On failure, surfaces the AppFailure without crashing.
//
// Reverting the joinChannel implementation → test 1 fails (method not called).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/channels/data/channel_management_repository.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';

void main() {
  group('B126 — ChannelManagementStore.joinChannel', () {
    late ProviderContainer container;
    late _TrackingChannelManagementRepository repo;
    late _FakeRealtimeSocketClient socket;
    late _FakeHomeListStore homeStore;

    const scopeId = ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'channel-abc',
    );

    setUp(() {
      repo = _TrackingChannelManagementRepository();
      socket = _FakeRealtimeSocketClient();
      homeStore = _FakeHomeListStore();

      container = ProviderContainer(
        overrides: [
          channelManagementRepositoryProvider.overrideWithValue(repo),
          realtimeSocketClientProvider.overrideWithValue(socket),
          homeListStoreProvider.overrideWith(() => homeStore),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('calls repository.joinChannel with correct params', () async {
      final notifier = container.read(channelManagementStoreProvider.notifier);

      final result = await notifier.joinChannel(scopeId);

      expect(result, isTrue);
      expect(
        repo.joinCalls,
        [('server-1', 'channel-abc')],
        reason: 'Reverting joinChannel → repo not called → RED.',
      );
    });

    test('emits join:channel on the realtime socket after success', () async {
      final notifier = container.read(channelManagementStoreProvider.notifier);

      await notifier.joinChannel(scopeId);

      expect(
        socket.emittedEvents,
        [('join:channel', 'channel-abc')],
        reason: 'Reverting socket emit → event not fired → RED.',
      );
    });

    test('refreshes home list after successful join', () async {
      final notifier = container.read(channelManagementStoreProvider.notifier);

      await notifier.joinChannel(scopeId);

      expect(homeStore.loadCallCount, greaterThan(0));
    });

    test('surfaces AppFailure on server error', () async {
      repo.shouldFail = true;

      final notifier = container.read(channelManagementStoreProvider.notifier);

      await expectLater(
        () => notifier.joinChannel(scopeId),
        throwsA(isA<AppFailure>()),
      );

      // State reflects the failure.
      final state = container.read(channelManagementStoreProvider);
      expect(state.failure, isNotNull);
      // Socket should NOT have been emitted on failure.
      expect(socket.emittedEvents, isEmpty);
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _TrackingChannelManagementRepository
    implements ChannelManagementRepository {
  final List<(String serverId, String channelId)> joinCalls = [];
  bool shouldFail = false;

  @override
  Future<void> joinChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    if (shouldFail) {
      throw const ServerFailure(message: 'Internal server error');
    }
    joinCalls.add((serverId.value, channelId));
  }

  @override
  Future<String> createChannel(
    ServerScopeId serverId, {
    required String name,
    String? description,
    bool? isPrivate,
  }) async =>
      'id';

  @override
  Future<void> updateChannel(
    ServerScopeId serverId, {
    required String channelId,
    String? name,
    String? description,
    bool? isPrivate,
  }) async {}

  @override
  Future<void> deleteChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> leaveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> archiveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> unarchiveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> stopAllAgents(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> resumeAllAgents(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}
}

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  final List<(String event, dynamic data)> emittedEvents = [];

  @override
  void emit(String event, [dynamic data]) {
    emittedEvents.add((event, data));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHomeListStore extends HomeListStore {
  int loadCallCount = 0;

  @override
  HomeListState build() => HomeListState(status: HomeListStatus.success);

  @override
  Future<void> load() async {
    loadCallCount++;
  }

  @override
  Future<void> refresh({String reason = ''}) async {}
}
