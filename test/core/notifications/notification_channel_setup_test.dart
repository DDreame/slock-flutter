import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/notification_actions.dart';
import 'package:slock_app/core/notifications/notification_channel_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default channels define DM, mention, and channel message buckets', () {
    expect(defaultSlockNotificationChannels, hasLength(3));
    expect(
      defaultSlockNotificationChannels.map((channel) => channel.toJson()),
      containsAll([
        containsPair('id', 'slock_direct_messages'),
        containsPair('id', 'slock_mentions'),
        containsPair('id', 'slock_channel_messages'),
      ]),
    );
  });

  test('channel config serializes user-configurable importance', () {
    const config = SlockNotificationChannelConfig(
      type: SlockNotificationChannelType.directMessage,
      name: 'Direct Messages',
      description: 'DM notifications',
      importance: SlockNotificationImportance.high,
    );

    expect(config.toJson(), {
      'id': 'slock_direct_messages',
      'type': 'direct_message',
      'name': 'Direct Messages',
      'description': 'DM notifications',
      'importance': 'high',
    });
  });

  test('method channel bridge configures native notification channels',
      () async {
    const channel = MethodChannel(notificationChannelSetupMethodChannelName);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await const MethodChannelNotificationChannelSetupBridge(
      channel: channel,
    ).configureChannels(defaultSlockNotificationChannels);

    expect(calls.single.method, 'configureNotificationChannels');
    expect(calls.single.arguments, [
      {
        'id': 'slock_direct_messages',
        'type': 'direct_message',
        'name': 'Direct Messages',
        'description': 'Notifications for direct messages',
        'importance': 'high',
      },
      {
        'id': 'slock_mentions',
        'type': 'mention',
        'name': 'Mentions',
        'description': 'Notifications for @mentions',
        'importance': 'high',
      },
      {
        'id': 'slock_channel_messages',
        'type': 'channel',
        'name': 'Channel Messages',
        'description': 'Notifications for channel messages',
        'importance': 'normal',
      },
    ]);
  });
}
