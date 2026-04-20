import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/core/scope/channel_scope_id.dart';
import 'package:slock_app/core/scope/direct_message_scope_id.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/notification/notification_visible_target_binding.dart';

class _FakeNotificationInitializer implements NotificationInitializer {
  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.unknown;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async => null;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => const Stream.empty();

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) async {}
}

class _FakeSecureStorage implements SecureStorage {
  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}
}

void main() {
  group('conversationTargetToVisibleTarget', () {
    test('returns null for null target', () {
      expect(conversationTargetToVisibleTarget(null), isNull);
    });

    test('maps channel target', () {
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
      );

      final result = conversationTargetToVisibleTarget(target);

      expect(result, isNotNull);
      expect(result!.serverId, 's1');
      expect(result.surface, NotificationSurface.channel);
      expect(result.channelId, 'c1');
      expect(result.threadId, isNull);
    });

    test('maps direct message target', () {
      final target = ConversationDetailTarget.directMessage(
        const DirectMessageScopeId(
          serverId: ServerScopeId('s1'),
          value: 'dm1',
        ),
      );

      final result = conversationTargetToVisibleTarget(target);

      expect(result, isNotNull);
      expect(result!.serverId, 's1');
      expect(result.surface, NotificationSurface.dm);
      expect(result.channelId, 'dm1');
    });
  });

  group('notificationVisibleTargetBindingProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          notificationInitializerProvider
              .overrideWithValue(_FakeNotificationInitializer()),
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('sets visible target when conversation opens', () {
      container.read(notificationVisibleTargetBindingProvider);

      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
      );
      container.read(currentOpenConversationTargetProvider.notifier).state =
          target;

      final state = container.read(notificationStoreProvider);
      expect(state.visibleTarget, isNotNull);
      expect(state.visibleTarget!.serverId, 's1');
      expect(state.visibleTarget!.surface, NotificationSurface.channel);
      expect(state.visibleTarget!.channelId, 'c1');
    });

    test('clears visible target when conversation closes', () {
      container.read(notificationVisibleTargetBindingProvider);

      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
      );
      container.read(currentOpenConversationTargetProvider.notifier).state =
          target;
      expect(
        container.read(notificationStoreProvider).visibleTarget,
        isNotNull,
      );

      container.read(currentOpenConversationTargetProvider.notifier).state =
          null;
      expect(
        container.read(notificationStoreProvider).visibleTarget,
        isNull,
      );
    });

    test('updates visible target when navigating between conversations', () {
      container.read(notificationVisibleTargetBindingProvider);

      final channel = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
      );
      container.read(currentOpenConversationTargetProvider.notifier).state =
          channel;
      expect(
        container.read(notificationStoreProvider).visibleTarget!.channelId,
        'c1',
      );

      final dm = ConversationDetailTarget.directMessage(
        const DirectMessageScopeId(
          serverId: ServerScopeId('s1'),
          value: 'dm1',
        ),
      );
      container.read(currentOpenConversationTargetProvider.notifier).state = dm;
      final state = container.read(notificationStoreProvider);
      expect(state.visibleTarget!.surface, NotificationSurface.dm);
      expect(state.visibleTarget!.channelId, 'dm1');
    });
  });
}
