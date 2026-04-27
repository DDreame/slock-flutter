import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/application/threads_inbox_state.dart';
import 'package:slock_app/features/threads/application/threads_inbox_store.dart';
import 'package:slock_app/features/threads/application/threads_realtime_binding.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/presentation/page/threads_page.dart';

void main() {
  testWidgets('keeps thread inbox visible while reloading', (tester) async {
    final store = _FakeThreadsInboxStore(
      initialState: ThreadsInboxState(
        serverId: const ServerScopeId('server-1'),
        status: ThreadsInboxStatus.loading,
        items: [_threadItem()],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          threadsInboxStoreProvider.overrideWith(() => store),
          threadsInboxRealtimeBindingProvider.overrideWith((ref) {}),
        ],
        child: const MaterialApp(home: ThreadsPage(serverId: 'server-1')),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('threads-success')), findsOneWidget);
    expect(find.text('Thread title'), findsOneWidget);
    expect(find.byKey(const ValueKey('threads-refresh-indicator')),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

ThreadInboxItem _threadItem() {
  return const ThreadInboxItem(
    routeTarget: ThreadRouteTarget(
      serverId: 'server-1',
      parentChannelId: 'channel-1',
      parentMessageId: 'message-1',
      threadChannelId: 'thread-1',
      isFollowed: true,
    ),
    title: 'Thread title',
    preview: 'Latest reply',
    senderName: 'Alice',
    replyCount: 3,
    unreadCount: 1,
    participantIds: ['user-1'],
  );
}

class _FakeThreadsInboxStore extends ThreadsInboxStore {
  _FakeThreadsInboxStore({required ThreadsInboxState initialState})
      : _initialState = initialState;

  final ThreadsInboxState _initialState;

  @override
  ThreadsInboxState build() => _initialState;

  @override
  Future<void> load() async {}
}
