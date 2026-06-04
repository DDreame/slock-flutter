import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/last_active_timestamp_provider.dart';
import 'package:slock_app/features/home/application/summary_card_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

// ---------------------------------------------------------------------------
// #861: Smart Summary Card — Unit Tests
//
// Tests for summaryCardStateProvider aggregation logic:
// - Threshold (< 5 min → null)
// - Edge cases (null timestamp, 999+ cap, no unreads)
// - Channel ranking (mentions first, then by unread count)
// - Task filtering (assigned since lastActive)
// ---------------------------------------------------------------------------

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Creates a container with all required overrides for the summary card.
  ProviderContainer createContainer({
    DateTime? lastActive,
    InboxState? inbox,
    HomeListState? homeState,
    String? userId,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Override lastActiveTimestamp directly.
        lastActiveTimestampProvider.overrideWith(() {
          return _FakeLastActiveNotifier(lastActive);
        }),
        // Override inbox state.
        inboxStoreProvider.overrideWith(
          () => _FakeInboxStore(
              inbox ?? const InboxState(status: InboxStatus.success)),
        ),
        // Override home list state.
        homeListStoreProvider.overrideWith(
          () => _FakeHomeListStore(
            homeState ?? HomeListState(status: HomeListStatus.success),
          ),
        ),
        // Override session for userId.
        sessionStoreProvider.overrideWith(
          () => _FakeSessionStore(userId ?? 'user-1'),
        ),
        // NotificationStore needed by lastActiveTimestamp lifecycle binding.
        notificationStoreProvider.overrideWith(() => _FakeNotificationStore()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('summaryCardStateProvider', () {
    test('returns null when lastActive is null (first install)', () {
      final container = createContainer(lastActive: null);
      expect(container.read(summaryCardStateProvider), isNull);
    });

    test('returns null when away < 5 minutes', () {
      final container = createContainer(
        lastActive:
            DateTime.now().subtract(const Duration(minutes: 4, seconds: 59)),
        inbox: const InboxState(
          status: InboxStatus.success,
          totalUnreadCount: 5,
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              channelName: 'general',
              unreadCount: 5,
            ),
          ],
        ),
        homeState: HomeListState(status: HomeListStatus.success),
      );
      expect(container.read(summaryCardStateProvider), isNull);
    });

    test('returns state when away >= 5 minutes with unreads', () {
      final container = createContainer(
        lastActive: DateTime.now().subtract(const Duration(minutes: 10)),
        inbox: const InboxState(
          status: InboxStatus.success,
          totalUnreadCount: 12,
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              channelName: 'engineering',
              unreadCount: 8,
              isMentioned: true,
            ),
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-2',
              channelName: 'random',
              unreadCount: 4,
            ),
          ],
        ),
        homeState: HomeListState(status: HomeListStatus.success),
      );

      final state = container.read(summaryCardStateProvider);
      expect(state, isNotNull);
      expect(state!.totalUnread, 12);
      expect(state.mentionCount, 1);
      expect(state.topChannels.length, 2);
      // Mentioned channel should be first.
      expect(state.topChannels[0].channelName, 'engineering');
      expect(state.topChannels[0].isMentioned, isTrue);
      expect(state.topChannels[1].channelName, 'random');
    });

    test('returns null when no unreads and no task changes', () {
      final container = createContainer(
        lastActive: DateTime.now().subtract(const Duration(hours: 1)),
        inbox: const InboxState(
          status: InboxStatus.success,
          totalUnreadCount: 0,
          items: [],
        ),
        homeState: HomeListState(status: HomeListStatus.success),
      );
      expect(container.read(summaryCardStateProvider), isNull);
    });

    test('returns null when inbox not yet loaded', () {
      final container = createContainer(
        lastActive: DateTime.now().subtract(const Duration(hours: 1)),
        inbox: const InboxState(status: InboxStatus.loading),
        homeState: HomeListState(status: HomeListStatus.success),
      );
      expect(container.read(summaryCardStateProvider), isNull);
    });

    test('caps channels at 5 and reports remaining count', () {
      final items = List.generate(
        8,
        (i) => InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-$i',
          channelName: 'channel-$i',
          unreadCount: 10 - i,
        ),
      );

      final container = createContainer(
        lastActive: DateTime.now().subtract(const Duration(hours: 2)),
        inbox: InboxState(
          status: InboxStatus.success,
          totalUnreadCount: 52,
          items: items,
        ),
        homeState: HomeListState(status: HomeListStatus.success),
      );

      final state = container.read(summaryCardStateProvider)!;
      expect(state.topChannels.length, 5);
      expect(state.remainingChannelCount, 3);
    });

    test('includes task changes assigned since lastActive', () {
      final lastActive = DateTime.now().subtract(const Duration(hours: 1));
      final container = createContainer(
        lastActive: lastActive,
        userId: 'user-1',
        inbox: const InboxState(
          status: InboxStatus.success,
          totalUnreadCount: 1,
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              channelName: 'general',
              unreadCount: 1,
            ),
          ],
        ),
        homeState: HomeListState(
          status: HomeListStatus.success,
          taskItems: [
            TaskItem(
              id: 't1',
              taskNumber: 100,
              title: 'Fix login bug',
              status: 'in_progress',
              channelId: 'ch-1',
              channelType: 'channel',
              claimedById: 'user-1',
              claimedByName: 'Me',
              claimedByType: 'human',
              claimedAt: DateTime.now().subtract(const Duration(minutes: 30)),
              createdById: 'user-2',
              createdByName: 'PM',
              createdByType: 'human',
              createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            ),
            TaskItem(
              id: 't2',
              taskNumber: 101,
              title: 'Old task',
              status: 'todo',
              channelId: 'ch-1',
              channelType: 'channel',
              claimedById: 'user-1',
              claimedByName: 'Me',
              claimedByType: 'human',
              claimedAt: DateTime.now().subtract(const Duration(hours: 5)),
              createdById: 'user-2',
              createdByName: 'PM',
              createdByType: 'human',
              createdAt: DateTime.now().subtract(const Duration(hours: 6)),
            ),
          ],
        ),
      );

      final state = container.read(summaryCardStateProvider)!;
      expect(state.newTaskCount, 1);
      expect(state.taskChanges[0].taskNumber, 100);
      expect(state.taskChanges[0].changeType, 'assigned');
    });

    test('shows card with only task changes (zero unreads)', () {
      final lastActive = DateTime.now().subtract(const Duration(hours: 1));
      final container = createContainer(
        lastActive: lastActive,
        userId: 'user-1',
        inbox: const InboxState(
          status: InboxStatus.success,
          totalUnreadCount: 0,
          items: [],
        ),
        homeState: HomeListState(
          status: HomeListStatus.success,
          taskItems: [
            TaskItem(
              id: 't1',
              taskNumber: 200,
              title: 'Deploy fix',
              status: 'done',
              channelId: 'ch-1',
              channelType: 'channel',
              claimedById: 'user-1',
              claimedByName: 'Me',
              claimedByType: 'human',
              claimedAt: DateTime.now().subtract(const Duration(hours: 2)),
              createdById: 'user-2',
              createdByName: 'PM',
              createdByType: 'human',
              createdAt: DateTime.now().subtract(const Duration(hours: 3)),
              completedAt: DateTime.now().subtract(const Duration(minutes: 20)),
            ),
          ],
        ),
      );

      final state = container.read(summaryCardStateProvider);
      expect(state, isNotNull);
      expect(state!.newTaskCount, 1);
      expect(state.taskChanges[0].changeType, 'statusChanged');
    });

    test('channel ranking: mentions first, then by unread desc', () {
      final container = createContainer(
        lastActive: DateTime.now().subtract(const Duration(hours: 1)),
        inbox: const InboxState(
          status: InboxStatus.success,
          totalUnreadCount: 30,
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-high',
              channelName: 'high-traffic',
              unreadCount: 20,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'ch-dm',
              channelName: 'DDreame',
              unreadCount: 2,
              isMentioned: true,
            ),
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-low',
              channelName: 'low-traffic',
              unreadCount: 8,
            ),
          ],
        ),
        homeState: HomeListState(status: HomeListStatus.success),
      );

      final state = container.read(summaryCardStateProvider)!;
      // DM with mention should be first despite lower unread count.
      expect(state.topChannels[0].channelId, 'ch-dm');
      expect(state.topChannels[0].isMentioned, isTrue);
      // Then sorted by unread count descending.
      expect(state.topChannels[1].channelId, 'ch-high');
      expect(state.topChannels[2].channelId, 'ch-low');
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeLastActiveNotifier extends LastActiveTimestampNotifier {
  _FakeLastActiveNotifier(this._value);
  final DateTime? _value;

  @override
  DateTime? build() => _value;
}

class _FakeInboxStore extends AutoDisposeNotifier<InboxState>
    implements InboxStore {
  _FakeInboxStore(this._state);
  final InboxState _state;

  @override
  InboxState build() => _state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHomeListStore extends Notifier<HomeListState>
    implements HomeListStore {
  _FakeHomeListStore(this._state);
  final HomeListState _state;

  @override
  HomeListState build() => _state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionStore extends Notifier<SessionState> implements SessionStore {
  _FakeSessionStore(this._userId);
  final String _userId;

  @override
  SessionState build() => SessionState(
        status: AuthStatus.authenticated,
        userId: _userId,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationStore extends Notifier<NotificationState>
    implements NotificationStore {
  @override
  NotificationState build() => const NotificationState(
        lifecycleStatus: AppLifecycleStatus.resumed,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
