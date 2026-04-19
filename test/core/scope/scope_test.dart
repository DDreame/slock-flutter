import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';

void main() {
  test('server scope round-trips route param and equality', () {
    final first = ServerScopeId.fromRouteParam('server-1');
    const second = ServerScopeId('server-1');

    expect(first.value, 'server-1');
    expect(first.routeParam, 'server-1');
    expect(first.toString(), 'server-1');
    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('channel scope keeps explicit parent server scope', () {
    final channel = ChannelScopeId.fromRouteParams(
      serverId: 'server-1',
      channelId: 'channel-2',
    );

    expect(channel.serverId, const ServerScopeId('server-1'));
    expect(channel.value, 'channel-2');
    expect(channel.routeParam, 'channel-2');
    expect(channel.toString(), 'channel-2');
  });

  test('dm scope equality includes parent server scope', () {
    final left = DirectMessageScopeId.fromRouteParams(
      serverId: 'server-1',
      directMessageId: 'dm-7',
    );
    const same = DirectMessageScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'dm-7',
    );
    const differentServer = DirectMessageScopeId(
      serverId: ServerScopeId('server-2'),
      value: 'dm-7',
    );

    expect(left, same);
    expect(left.hashCode, same.hashCode);
    expect(left, isNot(differentServer));
    expect(left.routeParam, 'dm-7');
    expect(left.toString(), 'dm-7');
  });
}
