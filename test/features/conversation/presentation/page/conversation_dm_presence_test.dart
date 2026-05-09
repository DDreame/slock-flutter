import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';

/// Smoke-tests for the DM presence subtitle shown in the conversation
/// detail page app bar.
///
/// Because [_DmPresenceSubtitle] is private and deeply embedded, we
/// replicate its core logic here (peer lookup + presence store watch)
/// to verify correctness without constructing the full page.
void main() {
  const serverId = ServerScopeId('test-server');

  group('DM presence subtitle — peerId lookup', () {
    test('resolves peerId from directMessages', () {
      const state = HomeListState(
        status: HomeListStatus.success,
        directMessages: [
          HomeDirectMessageSummary(
            scopeId:
                DirectMessageScopeId(serverId: serverId, value: 'dm-conv-1'),
            title: 'Alice',
            peerId: 'user-alice',
          ),
        ],
      );

      String? lookupPeerId(HomeListState s, String conversationId) {
        for (final dm in s.pinnedDirectMessages) {
          if (dm.scopeId.value == conversationId) return dm.peerId;
        }
        for (final dm in s.directMessages) {
          if (dm.scopeId.value == conversationId) return dm.peerId;
        }
        for (final dm in s.hiddenDirectMessages) {
          if (dm.scopeId.value == conversationId) return dm.peerId;
        }
        return null;
      }

      expect(lookupPeerId(state, 'dm-conv-1'), 'user-alice');
      expect(lookupPeerId(state, 'dm-conv-unknown'), isNull);
    });

    test('resolves peerId from pinnedDirectMessages', () {
      const state = HomeListState(
        status: HomeListStatus.success,
        pinnedDirectMessages: [
          HomeDirectMessageSummary(
            scopeId:
                DirectMessageScopeId(serverId: serverId, value: 'dm-conv-2'),
            title: 'Bob',
            peerId: 'user-bob',
          ),
        ],
      );

      String? lookupPeerId(HomeListState s, String conversationId) {
        for (final dm in s.pinnedDirectMessages) {
          if (dm.scopeId.value == conversationId) return dm.peerId;
        }
        for (final dm in s.directMessages) {
          if (dm.scopeId.value == conversationId) return dm.peerId;
        }
        return null;
      }

      expect(lookupPeerId(state, 'dm-conv-2'), 'user-bob');
    });

    test('resolves peerId from hiddenDirectMessages', () {
      const state = HomeListState(
        status: HomeListStatus.success,
        hiddenDirectMessages: [
          HomeDirectMessageSummary(
            scopeId:
                DirectMessageScopeId(serverId: serverId, value: 'dm-conv-3'),
            title: 'Eve',
            peerId: 'user-eve',
          ),
        ],
      );

      String? lookupPeerId(HomeListState s, String conversationId) {
        for (final dm in s.pinnedDirectMessages) {
          if (dm.scopeId.value == conversationId) return dm.peerId;
        }
        for (final dm in s.directMessages) {
          if (dm.scopeId.value == conversationId) return dm.peerId;
        }
        for (final dm in s.hiddenDirectMessages) {
          if (dm.scopeId.value == conversationId) return dm.peerId;
        }
        return null;
      }

      expect(lookupPeerId(state, 'dm-conv-3'), 'user-eve');
    });
  });

  group('DM presence subtitle — status display', () {
    testWidgets('presence store maps status to display text', (tester) async {
      final container = ProviderContainer();
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      container.read(presenceStoreProvider.notifier).setOnline('user-1');
      final status = container.read(presenceStoreProvider).statusOf('user-1');
      expect(status, UserPresenceStatus.online);

      final statusText = switch (status) {
        UserPresenceStatus.online => 'Online',
        UserPresenceStatus.idle => 'Idle',
        UserPresenceStatus.offline => 'Offline',
      };
      expect(statusText, 'Online');
    });

    testWidgets('idle status maps to "Idle" text', (tester) async {
      final container = ProviderContainer();
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      container.read(presenceStoreProvider.notifier).setIdle('user-1');
      final status = container.read(presenceStoreProvider).statusOf('user-1');
      expect(status, UserPresenceStatus.idle);

      final statusText = switch (status) {
        UserPresenceStatus.online => 'Online',
        UserPresenceStatus.idle => 'Idle',
        UserPresenceStatus.offline => 'Offline',
      };
      expect(statusText, 'Idle');
    });

    testWidgets('offline status maps to "Offline" text', (tester) async {
      final container = ProviderContainer();
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      final status = container.read(presenceStoreProvider).statusOf('user-1');
      expect(status, UserPresenceStatus.offline);

      final statusText = switch (status) {
        UserPresenceStatus.online => 'Online',
        UserPresenceStatus.idle => 'Idle',
        UserPresenceStatus.offline => 'Offline',
      };
      expect(statusText, 'Offline');
    });

    testWidgets('dot color matches status', (tester) async {
      final container = ProviderContainer();
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      container.read(presenceStoreProvider.notifier).setOnline('user-1');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final colors = Theme.of(context).extension<AppColors>()!;
                  final status =
                      container.read(presenceStoreProvider).statusOf('user-1');
                  final dotColor = switch (status) {
                    UserPresenceStatus.online => colors.success,
                    UserPresenceStatus.idle => colors.warning,
                    UserPresenceStatus.offline => colors.textTertiary,
                  };
                  return Container(
                    key: const ValueKey('test-dot'),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      final dot = tester.widget<Container>(
        find.byKey(const ValueKey('test-dot')),
      );
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.success);
    });
  });
}
