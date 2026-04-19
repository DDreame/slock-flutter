import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/scope/channel_scope_id.dart';
import 'package:slock_app/core/scope/direct_message_scope_id.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_state.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

void main() {
  const server1 = ServerScopeId('server-1');
  const server2 = ServerScopeId('server-2');

  const channelGeneral = ChannelScopeId(
    serverId: server1,
    value: 'general',
  );
  const channelRandom = ChannelScopeId(
    serverId: server1,
    value: 'random',
  );
  const channelOtherServer = ChannelScopeId(
    serverId: server2,
    value: 'general',
  );
  const dmAlice = DirectMessageScopeId(
    serverId: server1,
    value: 'dm-alice',
  );
  const dmBob = DirectMessageScopeId(
    serverId: server1,
    value: 'dm-bob',
  );

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  ChannelUnreadStore readStore() =>
      container.read(channelUnreadStoreProvider.notifier);
  ChannelUnreadState readState() => container.read(channelUnreadStoreProvider);

  group('ChannelUnreadStore', () {
    test('initial state has empty unread counts', () {
      final state = readState();
      expect(state.channelUnreadCounts, isEmpty);
      expect(state.dmUnreadCounts, isEmpty);
      expect(state.totalUnreadCount, 0);
    });

    test('hydrateChannelUnreads populates channel counts', () {
      readStore().hydrateChannelUnreads({
        channelGeneral: 5,
        channelRandom: 3,
      });

      final state = readState();
      expect(state.channelUnreadCount(channelGeneral), 5);
      expect(state.channelUnreadCount(channelRandom), 3);
      expect(state.totalUnreadCount, 8);
    });

    test('hydrateDmUnreads populates DM counts', () {
      readStore().hydrateDmUnreads({
        dmAlice: 2,
        dmBob: 7,
      });

      final state = readState();
      expect(state.dmUnreadCount(dmAlice), 2);
      expect(state.dmUnreadCount(dmBob), 7);
      expect(state.totalUnreadCount, 9);
    });

    test('hydrateChannelUnreads replaces previous channel counts', () {
      readStore().hydrateChannelUnreads({channelGeneral: 5});
      readStore().hydrateChannelUnreads({channelRandom: 2});

      final state = readState();
      expect(state.channelUnreadCount(channelGeneral), 0);
      expect(state.channelUnreadCount(channelRandom), 2);
    });

    test('hydrateChannelUnreads does not affect DM counts', () {
      readStore().hydrateDmUnreads({dmAlice: 3});
      readStore().hydrateChannelUnreads({channelGeneral: 5});

      expect(readState().dmUnreadCount(dmAlice), 3);
    });

    test('markChannelRead removes channel unread entry', () {
      readStore().hydrateChannelUnreads({
        channelGeneral: 5,
        channelRandom: 3,
      });

      readStore().markChannelRead(channelGeneral);

      final state = readState();
      expect(state.channelUnreadCount(channelGeneral), 0);
      expect(state.hasChannelUnread(channelGeneral), false);
      expect(state.channelUnreadCount(channelRandom), 3);
    });

    test('markChannelRead on unknown channel is no-op', () {
      readStore().hydrateChannelUnreads({channelGeneral: 5});
      final before = readState();

      readStore().markChannelRead(channelRandom);

      expect(readState(), before);
    });

    test('markDmRead removes DM unread entry', () {
      readStore().hydrateDmUnreads({dmAlice: 4, dmBob: 2});

      readStore().markDmRead(dmAlice);

      final state = readState();
      expect(state.dmUnreadCount(dmAlice), 0);
      expect(state.hasDmUnread(dmAlice), false);
      expect(state.dmUnreadCount(dmBob), 2);
    });

    test('markDmRead on unknown DM is no-op', () {
      readStore().hydrateDmUnreads({dmAlice: 4});
      final before = readState();

      readStore().markDmRead(dmBob);

      expect(readState(), before);
    });

    test('incrementChannelUnread bumps existing count', () {
      readStore().hydrateChannelUnreads({channelGeneral: 5});

      readStore().incrementChannelUnread(channelGeneral);

      expect(readState().channelUnreadCount(channelGeneral), 6);
    });

    test('incrementChannelUnread on new channel creates entry with count 1',
        () {
      readStore().incrementChannelUnread(channelGeneral);

      expect(readState().channelUnreadCount(channelGeneral), 1);
      expect(readState().hasChannelUnread(channelGeneral), true);
    });

    test('incrementChannelUnread with custom amount', () {
      readStore().hydrateChannelUnreads({channelGeneral: 2});

      readStore().incrementChannelUnread(channelGeneral, by: 3);

      expect(readState().channelUnreadCount(channelGeneral), 5);
    });

    test('incrementDmUnread bumps existing count', () {
      readStore().hydrateDmUnreads({dmAlice: 3});

      readStore().incrementDmUnread(dmAlice);

      expect(readState().dmUnreadCount(dmAlice), 4);
    });

    test('incrementDmUnread on new DM creates entry with count 1', () {
      readStore().incrementDmUnread(dmAlice);

      expect(readState().dmUnreadCount(dmAlice), 1);
    });

    test('setChannelUnreadCount sets specific count', () {
      readStore().setChannelUnreadCount(channelGeneral, 10);

      expect(readState().channelUnreadCount(channelGeneral), 10);
    });

    test('setChannelUnreadCount with 0 removes entry', () {
      readStore().hydrateChannelUnreads({channelGeneral: 5});

      readStore().setChannelUnreadCount(channelGeneral, 0);

      expect(
          readState().channelUnreadCounts.containsKey(channelGeneral), false);
    });

    test('setDmUnreadCount sets specific count', () {
      readStore().setDmUnreadCount(dmAlice, 8);

      expect(readState().dmUnreadCount(dmAlice), 8);
    });

    test('setDmUnreadCount with 0 removes entry', () {
      readStore().hydrateDmUnreads({dmAlice: 5});

      readStore().setDmUnreadCount(dmAlice, 0);

      expect(readState().dmUnreadCounts.containsKey(dmAlice), false);
    });

    test('clearAll resets to empty state', () {
      readStore().hydrateChannelUnreads({channelGeneral: 5, channelRandom: 3});
      readStore().hydrateDmUnreads({dmAlice: 2, dmBob: 1});
      expect(readState().totalUnreadCount, 11);

      readStore().clearAll();

      final state = readState();
      expect(state.channelUnreadCounts, isEmpty);
      expect(state.dmUnreadCounts, isEmpty);
      expect(state.totalUnreadCount, 0);
    });

    test('scope identity is preserved: same channel value on different servers',
        () {
      readStore().hydrateChannelUnreads({
        channelGeneral: 5,
        channelOtherServer: 3,
      });

      final state = readState();
      expect(state.channelUnreadCount(channelGeneral), 5);
      expect(state.channelUnreadCount(channelOtherServer), 3);
    });

    test('full lifecycle: hydrate -> increment -> markRead -> clearAll', () {
      readStore().hydrateChannelUnreads({channelGeneral: 2});
      readStore().hydrateDmUnreads({dmAlice: 1});

      readStore().incrementChannelUnread(channelGeneral);
      expect(readState().channelUnreadCount(channelGeneral), 3);

      readStore().incrementDmUnread(dmBob);
      expect(readState().totalUnreadCount, 5);

      readStore().markChannelRead(channelGeneral);
      expect(readState().channelUnreadCount(channelGeneral), 0);
      expect(readState().totalUnreadCount, 2);

      readStore().clearAll();
      expect(readState().totalUnreadCount, 0);
    });
  });

  group('ChannelUnreadState', () {
    test('unreadCountFor returns 0 for unknown channel', () {
      const state = ChannelUnreadState();
      expect(state.channelUnreadCount(channelGeneral), 0);
      expect(state.dmUnreadCount(dmAlice), 0);
    });

    test('hasChannelUnread and hasDmUnread', () {
      final state = ChannelUnreadState(
        channelUnreadCounts: {channelGeneral: 1},
        dmUnreadCounts: {dmAlice: 0},
      );
      expect(state.hasChannelUnread(channelGeneral), true);
      expect(state.hasChannelUnread(channelRandom), false);
      expect(state.hasDmUnread(dmAlice), false);
    });

    test('totalUnreadCount sums channels and DMs', () {
      final state = ChannelUnreadState(
        channelUnreadCounts: {channelGeneral: 5, channelRandom: 3},
        dmUnreadCounts: {dmAlice: 2},
      );
      expect(state.totalUnreadCount, 10);
    });

    test('copyWith preserves fields when not overridden', () {
      final state = ChannelUnreadState(
        channelUnreadCounts: {channelGeneral: 5},
        dmUnreadCounts: {dmAlice: 2},
      );
      final copy = state.copyWith();
      expect(copy, state);
    });

    test('copyWith replaces specified fields', () {
      final state = ChannelUnreadState(
        channelUnreadCounts: {channelGeneral: 5},
        dmUnreadCounts: {dmAlice: 2},
      );
      final copy = state.copyWith(
        channelUnreadCounts: {channelRandom: 1},
      );
      expect(copy.channelUnreadCounts, {channelRandom: 1});
      expect(copy.dmUnreadCounts, {dmAlice: 2});
    });

    test('equality: same contents are equal', () {
      final a = ChannelUnreadState(
        channelUnreadCounts: {channelGeneral: 5},
        dmUnreadCounts: {dmAlice: 2},
      );
      final b = ChannelUnreadState(
        channelUnreadCounts: {channelGeneral: 5},
        dmUnreadCounts: {dmAlice: 2},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('equality: different contents are not equal', () {
      final a = ChannelUnreadState(
        channelUnreadCounts: {channelGeneral: 5},
      );
      final b = ChannelUnreadState(
        channelUnreadCounts: {channelGeneral: 3},
      );
      expect(a, isNot(b));
    });

    test('equality: empty states are equal', () {
      const a = ChannelUnreadState();
      const b = ChannelUnreadState();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
