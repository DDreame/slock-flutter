import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';

import '../../../support/support.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  test('loads first page of channels and expands on loadMoreChannels',
      () async {
    final fixture = RuntimeAppFixture();
    fixture.seedHome(channels: _channels(serverId, 35));
    final container = await fixture.boot();
    addTearDown(fixture.dispose);

    await container.read(homeListStoreProvider.notifier).load();
    var state = container.read(homeListStoreProvider);

    expect(state.status, HomeListStatus.success);
    expect(state.channels, hasLength(homeListPageSize));
    expect(state.channels.first.scopeId.value, 'channel-00');
    expect(state.channels.last.scopeId.value, 'channel-29');
    expect(state.hasMoreChannels, isTrue);
    expect(state.isLoadingMoreChannels, isFalse);

    final loadMore =
        container.read(homeListStoreProvider.notifier).loadMoreChannels();
    expect(container.read(homeListStoreProvider).isLoadingMoreChannels, isTrue);
    await loadMore;
    state = container.read(homeListStoreProvider);

    expect(state.channels, hasLength(35));
    expect(state.channels.last.scopeId.value, 'channel-34');
    expect(state.hasMoreChannels, isFalse);
    expect(state.isLoadingMoreChannels, isFalse);
  });

  test('channel and DM load more fetch only the requested page', () async {
    final repository = _PaginatedHomeRepository(
      serverId: serverId,
      channels: _channels(serverId, 35),
      directMessages: _directMessages(serverId, 33),
    );
    final fixture = RuntimeAppFixture(
      extraOverrides: [homeRepositoryProvider.overrideWithValue(repository)],
    );
    final container = await fixture.boot();
    addTearDown(fixture.dispose);

    await container.read(homeListStoreProvider.notifier).load();

    await container.read(homeListStoreProvider.notifier).loadMoreChannels();
    expect(repository.channelPageCalls, [30]);
    expect(repository.directMessagePageCalls, isEmpty);
    var state = container.read(homeListStoreProvider);
    expect(state.channels, hasLength(35));
    expect(state.directMessages, hasLength(30));

    await container
        .read(homeListStoreProvider.notifier)
        .loadMoreDirectMessages();
    expect(repository.channelPageCalls, [30]);
    expect(repository.directMessagePageCalls, [30]);
    state = container.read(homeListStoreProvider);
    expect(state.channels, hasLength(35));
    expect(state.directMessages, hasLength(33));
  });

  test('loads first page of DMs and expands on loadMoreDirectMessages',
      () async {
    final fixture = RuntimeAppFixture();
    fixture.seedHome(directMessages: _directMessages(serverId, 33));
    final container = await fixture.boot();
    addTearDown(fixture.dispose);

    await container.read(homeListStoreProvider.notifier).load();
    var state = container.read(homeListStoreProvider);

    expect(state.directMessages, hasLength(homeListPageSize));
    expect(state.directMessages.first.scopeId.value, 'dm-00');
    expect(state.directMessages.last.scopeId.value, 'dm-29');
    expect(state.hasMoreDirectMessages, isTrue);

    await container
        .read(homeListStoreProvider.notifier)
        .loadMoreDirectMessages();
    state = container.read(homeListStoreProvider);

    expect(state.directMessages, hasLength(33));
    expect(state.directMessages.last.scopeId.value, 'dm-32');
    expect(state.hasMoreDirectMessages, isFalse);
  });

  test('new realtime DM prepends without dropping already visible rows',
      () async {
    final fixture = RuntimeAppFixture();
    fixture.seedHome(directMessages: _directMessages(serverId, 31));
    final container = await fixture.boot();
    addTearDown(fixture.dispose);

    await container.read(homeListStoreProvider.notifier).load();
    expect(container.read(homeListStoreProvider).directMessages, hasLength(30));

    container.read(homeListStoreProvider.notifier).addDirectMessage(
          const HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-new'),
            title: 'New DM',
          ),
        );
    final state = container.read(homeListStoreProvider);

    expect(state.directMessages, hasLength(31));
    expect(state.directMessages.first.scopeId.value, 'dm-new');
    expect(
      state.directMessages.map((dm) => dm.scopeId.value),
      contains('dm-29'),
    );
    expect(state.hasMoreDirectMessages, isTrue);
  });
}

List<HomeChannelSummary> _channels(ServerScopeId serverId, int count) {
  return List.generate(
    count,
    (index) => HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: serverId,
        value: 'channel-${index.toString().padLeft(2, '0')}',
      ),
      name: 'channel-${index.toString().padLeft(2, '0')}',
      lastMessageId: 'msg-${index.toString().padLeft(2, '0')}',
      lastMessagePreview: 'Preview ${index.toString().padLeft(2, '0')}',
    ),
  );
}

List<HomeDirectMessageSummary> _directMessages(
    ServerScopeId serverId, int count) {
  return List.generate(
    count,
    (index) => HomeDirectMessageSummary(
      scopeId: DirectMessageScopeId(
        serverId: serverId,
        value: 'dm-${index.toString().padLeft(2, '0')}',
      ),
      title: 'DM ${index.toString().padLeft(2, '0')}',
    ),
  );
}

class _PaginatedHomeRepository
    implements HomeRepository, PaginatedHomeRepository {
  _PaginatedHomeRepository({
    required this.serverId,
    required this.channels,
    required this.directMessages,
  });

  final ServerScopeId serverId;
  final List<HomeChannelSummary> channels;
  final List<HomeDirectMessageSummary> directMessages;
  final List<int> channelPageCalls = [];
  final List<int> directMessagePageCalls = [];

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    throw StateError('loadWorkspace should not be used for paginated tests');
  }

  @override
  Future<HomeWorkspacePage> loadWorkspacePage(
    ServerScopeId serverId, {
    required int channelOffset,
    required int directMessageOffset,
    required int limit,
  }) async {
    return HomeWorkspacePage(
      snapshot: HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: channels.take(limit).toList(growable: false),
        directMessages: directMessages.take(limit).toList(growable: false),
      ),
      hasMoreChannels: channels.length > limit,
      hasMoreDirectMessages: directMessages.length > limit,
    );
  }

  @override
  Future<HomeChannelPage> loadChannelPage(
    ServerScopeId serverId, {
    required int offset,
    required int limit,
  }) async {
    channelPageCalls.add(offset);
    final end = (offset + limit).clamp(offset, channels.length);
    return HomeChannelPage(
      channels: channels.sublist(offset, end),
      hasMore: end < channels.length,
    );
  }

  @override
  Future<HomeDirectMessagePage> loadDirectMessagePage(
    ServerScopeId serverId, {
    required int offset,
    required int limit,
  }) async {
    directMessagePageCalls.add(offset);
    final end = (offset + limit).clamp(offset, directMessages.length);
    return HomeDirectMessagePage(
      directMessages: directMessages.sublist(offset, end),
      hasMore: end < directMessages.length,
    );
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async =>
      summary;

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
}
