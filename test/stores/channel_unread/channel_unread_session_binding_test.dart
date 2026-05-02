import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/scope/channel_scope_id.dart';
import 'package:slock_app/core/scope/direct_message_scope_id.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/threads/application/known_thread_channel_ids_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_session_binding.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

void main() {
  const server1 = ServerScopeId('server-1');
  const channelGeneral = ChannelScopeId(
    serverId: server1,
    value: 'general',
  );
  const dmAlice = DirectMessageScopeId(
    serverId: server1,
    value: 'dm-alice',
  );

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('channelUnreadSessionBindingProvider', () {
    test(
      'clears ChannelUnreadStore on logout',
      () async {
        // Activate the binding
        container.read(channelUnreadSessionBindingProvider);

        // Login
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await Future<void>.delayed(Duration.zero);

        // Populate unread counts
        container
            .read(channelUnreadStoreProvider.notifier)
            .hydrateChannelUnreads({channelGeneral: 5});
        container
            .read(channelUnreadStoreProvider.notifier)
            .hydrateDmUnreads({dmAlice: 3});

        // Populate known thread channel IDs
        container.read(knownThreadChannelIdsProvider.notifier).state = {
          'server-1/thread-1',
          'server-1/thread-2',
        };

        expect(
          container.read(channelUnreadStoreProvider).totalUnreadCount,
          8,
        );

        // Logout
        await container.read(sessionStoreProvider.notifier).logout();
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(channelUnreadStoreProvider).totalUnreadCount,
          0,
        );
        expect(
          container.read(channelUnreadStoreProvider).channelUnreadCounts,
          isEmpty,
        );
        expect(
          container.read(channelUnreadStoreProvider).dmUnreadCounts,
          isEmpty,
        );
        expect(
          container.read(knownThreadChannelIdsProvider),
          isEmpty,
          reason: 'Known thread channel IDs must be cleared on logout',
        );
      },
    );

    test(
      'does not clear on login transition',
      () async {
        // Pre-populate (simulates a server switch reload)
        container
            .read(channelUnreadStoreProvider.notifier)
            .hydrateChannelUnreads({channelGeneral: 5});

        // Activate binding
        container.read(channelUnreadSessionBindingProvider);

        // Login
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'a@b.com', password: 'p');
        await Future<void>.delayed(Duration.zero);

        // Counts should still be there
        expect(
          container
              .read(channelUnreadStoreProvider)
              .channelUnreadCount(channelGeneral),
          5,
        );
      },
    );
  });
}
