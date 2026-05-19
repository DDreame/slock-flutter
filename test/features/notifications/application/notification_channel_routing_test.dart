// ignore_for_file: unused_local_variable
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/notifications/application/notification_channel_router.dart';

void main() {
  group('Android notification channel routing', () {
    test(
      'T1: DM notification routes to DM channel',
      skip: true,
      () {
        // Arrange — payload with direct_message type.
        final payload = <String, dynamic>{'type': 'direct_message'};

        // Act
        final channelId =
            NotificationChannelRouter.channelIdForPayload(payload);

        // Assert
        expect(channelId, equals('slock_direct_messages'));
      },
    );

    test(
      'T2: Mention notification routes to mention channel',
      skip: true,
      () {
        // Arrange — payload with mention type.
        final payload = <String, dynamic>{'type': 'mention'};

        // Act
        final channelId =
            NotificationChannelRouter.channelIdForPayload(payload);

        // Assert
        expect(channelId, equals('slock_mentions'));
      },
    );

    test(
      'T3: General notification routes to default channel',
      skip: true,
      () {
        // Arrange — payload with channel_message type.
        final payload = <String, dynamic>{'type': 'channel_message'};

        // Act
        final channelId =
            NotificationChannelRouter.channelIdForPayload(payload);

        // Assert
        expect(channelId, equals('slock_general'));
      },
    );

    test(
      'T4: Channel metadata includes correct importance levels',
      skip: true,
      () {
        // Act
        final metadata = NotificationChannelRouter.channelMetadata;

        // Assert — DM channel has high importance.
        final dmChannel = metadata.firstWhere(
          (c) => c.id == 'slock_direct_messages',
        );
        expect(dmChannel.importance, NotificationImportance.high);

        // Assert — Mentions channel has high importance.
        final mentionChannel = metadata.firstWhere(
          (c) => c.id == 'slock_mentions',
        );
        expect(mentionChannel.importance, NotificationImportance.high);

        // Assert — General channel has default importance.
        final generalChannel = metadata.firstWhere(
          (c) => c.id == 'slock_general',
        );
        expect(
          generalChannel.importance,
          NotificationImportance.defaultImportance,
        );
      },
    );
  });
}
