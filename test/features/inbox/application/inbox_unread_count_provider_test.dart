import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/application/inbox_unread_count_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';

void main() {
  ProviderContainer createContainer(InboxState state) {
    return ProviderContainer(
      overrides: [
        inboxStoreProvider.overrideWith(() => _FakeInboxStore(state)),
      ],
    );
  }

  group('inboxTotalUnreadCountProvider', () {
    test('returns totalUnreadCount when loaded', () {
      final container = createContainer(
        const InboxState(
          status: InboxStatus.success,
          totalUnreadCount: 42,
        ),
      );
      addTearDown(container.dispose);

      expect(container.read(inboxTotalUnreadCountProvider), 42);
    });

    test('returns 0 when not loaded', () {
      final container = createContainer(
        const InboxState(status: InboxStatus.initial),
      );
      addTearDown(container.dispose);

      expect(container.read(inboxTotalUnreadCountProvider), 0);
    });
  });

  group('inboxChannelUnreadTotalProvider', () {
    test('sums only channel items', () {
      final container = createContainer(
        const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              unreadCount: 5,
            ),
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-2',
              unreadCount: 3,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-1',
              unreadCount: 10,
            ),
            InboxItem(
              kind: InboxItemKind.thread,
              channelId: 'th-1',
              unreadCount: 2,
            ),
          ],
        ),
      );
      addTearDown(container.dispose);

      expect(container.read(inboxChannelUnreadTotalProvider), 8);
    });

    test('returns 0 when not loaded', () {
      final container = createContainer(
        const InboxState(status: InboxStatus.loading),
      );
      addTearDown(container.dispose);

      expect(container.read(inboxChannelUnreadTotalProvider), 0);
    });
  });

  group('inboxDmUnreadTotalProvider', () {
    test('sums only dm items', () {
      final container = createContainer(
        const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              unreadCount: 5,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-1',
              unreadCount: 7,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-2',
              unreadCount: 4,
            ),
          ],
        ),
      );
      addTearDown(container.dispose);

      expect(container.read(inboxDmUnreadTotalProvider), 11);
    });

    test('returns 0 when not loaded', () {
      final container = createContainer(
        const InboxState(status: InboxStatus.failure),
      );
      addTearDown(container.dispose);

      expect(container.read(inboxDmUnreadTotalProvider), 0);
    });
  });
}

class _FakeInboxStore extends InboxStore {
  _FakeInboxStore(this._state);

  final InboxState _state;

  @override
  InboxState build() => _state;
}
