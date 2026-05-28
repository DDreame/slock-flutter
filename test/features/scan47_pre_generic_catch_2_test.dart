// =============================================================================
// Scan #47 PR E — Load-bearing tests for generic catch pass 2 (7 stores).
//
// Each test throws a non-AppFailure (FormatException) from the repository layer
// and verifies that:
//   1. The store does NOT crash (no unhandled exception propagates).
//   2. State transitions to failure (not stuck in loading/pending).
//
// Removing any `catch (error)` / `catch (_)` block from the production code
// causes the corresponding test to FAIL (go RED):
//   - For non-rethrowing methods: FormatException propagates → unhandled → RED.
//   - For rethrowing methods: UnknownFailure wrapping is missing → wrong type → RED.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/application/profile_detail_store.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/threads_inbox_state.dart';
import 'package:slock_app/features/threads/application/threads_inbox_store.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/features/translation/application/translation_cache_store.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_repository.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  // ===========================================================================
  // InboxStore — load()
  // ===========================================================================

  group('InboxStore generic catch (load)', () {
    test(
      'PRE-T1: InboxStore.load() catches non-AppFailure, sets failure status',
      () async {
        final repo = _ThrowingInboxRepo();
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            inboxRepositoryProvider.overrideWithValue(repo),
          ],
        );
        final sub = container.listen(inboxStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        // Wait for auto-load to succeed.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(inboxStoreProvider).status,
          InboxStatus.success,
        );

        // Now make repo throw FormatException on next load.
        repo.shouldThrow = true;
        await container.read(inboxStoreProvider.notifier).load();

        final state = container.read(inboxStoreProvider);
        expect(
          state.status,
          InboxStatus.failure,
          reason: 'PRE-T1: non-AppFailure in load() must set failure status. '
              'Removing catch (error) leaves FormatException unhandled → RED.',
        );
        expect(state.failure, isA<UnknownFailure>());
        expect(state.isRefreshing, isFalse);
      },
    );
  });

  // ===========================================================================
  // InboxStore — loadMore()
  // ===========================================================================

  group('InboxStore generic catch (loadMore)', () {
    test(
      'PRE-T2: InboxStore.loadMore() catches non-AppFailure, sets failure',
      () async {
        final repo = _ThrowingInboxRepo(hasMore: true);
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            inboxRepositoryProvider.overrideWithValue(repo),
          ],
        );
        final sub = container.listen(inboxStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        // Wait for auto-load to succeed (hasMore=true for pagination).
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(inboxStoreProvider).status,
          InboxStatus.success,
        );
        expect(container.read(inboxStoreProvider).hasMore, isTrue);

        // Now make repo throw FormatException on next fetch (loadMore).
        repo.shouldThrow = true;
        await container.read(inboxStoreProvider.notifier).loadMore();

        final state = container.read(inboxStoreProvider);
        expect(
          state.failure,
          isA<UnknownFailure>(),
          reason: 'PRE-T2: non-AppFailure in loadMore() must set failure. '
              'Removing catch (error) leaves FormatException unhandled → RED.',
        );

        // Verify _isLoadingMore was cleared (can call loadMore again).
        repo.shouldThrow = false;
        await container.read(inboxStoreProvider.notifier).loadMore();
        // If _isLoadingMore was stuck true, this second call would be a no-op
        // and the failure would remain. Since we cleared shouldThrow, success
        // clears the failure.
        expect(
          container.read(inboxStoreProvider).failure,
          isNull,
          reason: 'PRE-T2: _isLoadingMore must be cleared in finally block.',
        );
      },
    );
  });

  // ===========================================================================
  // ThreadsInboxStore — load()
  // ===========================================================================

  group('ThreadsInboxStore generic catch', () {
    test(
      'PRE-T3: ThreadsInboxStore.load() catches non-AppFailure, sets failure',
      () async {
        final repo = _ThrowingThreadRepo();
        final container = ProviderContainer(
          overrides: [
            currentThreadsServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            threadRepositoryProvider.overrideWithValue(repo),
          ],
        );
        final sub = container.listen(threadsInboxStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        // Wait for auto-load to succeed.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(threadsInboxStoreProvider).status,
          ThreadsInboxStatus.success,
        );

        // Make repo throw FormatException.
        repo.shouldThrow = true;
        await container.read(threadsInboxStoreProvider.notifier).load();

        final state = container.read(threadsInboxStoreProvider);
        expect(
          state.status,
          ThreadsInboxStatus.failure,
          reason: 'PRE-T3: non-AppFailure in load() must set failure status. '
              'Removing catch (error) leaves FormatException unhandled → RED.',
        );
        expect(state.failure, isA<UnknownFailure>());
      },
    );
  });

  // ===========================================================================
  // TasksStore — createTasks()
  // ===========================================================================

  group('TasksStore generic catch (createTasks)', () {
    test(
      'PRE-T4: TasksStore.createTasks() catches non-AppFailure, '
      'throws UnknownFailure',
      () async {
        final repo = _ThrowingTasksRepo();
        final container = ProviderContainer(
          overrides: [
            currentTasksServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            tasksRepositoryProvider.overrideWithValue(repo),
          ],
        );
        final sub = container.listen(tasksStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        // Load initial (empty) tasks.
        await container.read(tasksStoreProvider.notifier).load();
        expect(
          container.read(tasksStoreProvider).status,
          TasksStatus.success,
        );

        // Make createTasks throw FormatException.
        repo.throwOnCreate = true;
        await expectLater(
          () => container
              .read(tasksStoreProvider.notifier)
              .createTasks(channelId: 'ch-1', titles: ['Test task']),
          throwsA(isA<UnknownFailure>()),
        );
      },
    );
  });

  // ===========================================================================
  // TasksStore — convertMessageToTask()
  // ===========================================================================

  group('TasksStore generic catch (convertMessageToTask)', () {
    test(
      'PRE-T5: TasksStore.convertMessageToTask() catches non-AppFailure, '
      'throws UnknownFailure',
      () async {
        final repo = _ThrowingTasksRepo();
        final container = ProviderContainer(
          overrides: [
            currentTasksServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            tasksRepositoryProvider.overrideWithValue(repo),
          ],
        );
        final sub = container.listen(tasksStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        // Load initial (empty) tasks.
        await container.read(tasksStoreProvider.notifier).load();
        expect(
          container.read(tasksStoreProvider).status,
          TasksStatus.success,
        );

        // Make convertMessageToTask throw FormatException.
        repo.throwOnConvert = true;
        await expectLater(
          () => container
              .read(tasksStoreProvider.notifier)
              .convertMessageToTask(messageId: 'msg-1'),
          throwsA(isA<UnknownFailure>()),
        );
      },
    );
  });

  // ===========================================================================
  // ProfileDetailStore — openDirectMessage()
  // ===========================================================================

  group('ProfileDetailStore generic catch (openDirectMessage)', () {
    test(
      'PRE-T6: ProfileDetailStore.openDirectMessage() catches non-AppFailure, '
      'sets failure + clears isOpeningDirectMessage',
      () async {
        final profileRepo = _FakeProfileRepo();
        final memberRepo = _ThrowingMemberRepo();
        final container = ProviderContainer(
          overrides: [
            currentProfileTargetProvider.overrideWithValue(
              const ProfileTarget(
                userId: 'other-user',
                serverId: ServerScopeId('s1'),
              ),
            ),
            profileRepositoryProvider.overrideWithValue(profileRepo),
            memberRepositoryProvider.overrideWithValue(memberRepo),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
        );
        final sub = container.listen(profileDetailStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        // Wait for profile load to complete (scheduleMicrotask in build).
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(profileDetailStoreProvider).status,
          ProfileDetailStatus.success,
        );

        // Make openDirectMessage throw FormatException.
        memberRepo.shouldThrow = true;
        await expectLater(
          () => container
              .read(profileDetailStoreProvider.notifier)
              .openDirectMessage(),
          throwsA(isA<FormatException>()),
        );

        final state = container.read(profileDetailStoreProvider);
        expect(
          state.isOpeningDirectMessage,
          isFalse,
          reason: 'PRE-T6: non-AppFailure in openDirectMessage must clear '
              'isOpeningDirectMessage. Removing catch (error) leaves it '
              'stuck true → RED.',
        );
        expect(
          state.failure,
          isA<UnknownFailure>(),
          reason: 'PRE-T6: non-AppFailure must be wrapped in UnknownFailure '
              'and stored in state.failure.',
        );
      },
    );
  });

  // ===========================================================================
  // TranslationCacheStore — translateMessages()
  // ===========================================================================

  group('TranslationCacheStore generic catch', () {
    test(
      'PRE-T7: TranslationCacheStore.translateMessages() catches '
      'non-AppFailure, marks entries as failed',
      () async {
        final repo = _ThrowingTranslationRepo();
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            translationRepositoryProvider.overrideWithValue(repo),
            translationSettingsStoreProvider.overrideWith(
              () => _FakeTranslationSettingsStore(),
            ),
          ],
        );
        final sub = container.listen(translationCacheStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        // Make repo throw FormatException on translateBatch.
        repo.shouldThrow = true;
        await container
            .read(translationCacheStoreProvider.notifier)
            .translateMessages(['msg-1', 'msg-2']);

        final state = container.read(translationCacheStoreProvider);
        final entry1 = state.translations['msg-1'];
        final entry2 = state.translations['msg-2'];
        expect(
          entry1?.status,
          TranslationEntryStatus.failed,
          reason: 'PRE-T7: non-AppFailure in translateMessages must mark '
              'entries as failed. Removing catch (_) leaves them pending or '
              'propagates → RED.',
        );
        expect(
          entry2?.status,
          TranslationEntryStatus.failed,
          reason: 'PRE-T7: both entries must be marked failed.',
        );
      },
    );
  });
}

// =============================================================================
// Fakes — InboxStore
// =============================================================================

class _ThrowingInboxRepo implements InboxRepository {
  _ThrowingInboxRepo({this.hasMore = false});

  final bool hasMore;
  bool shouldThrow = false;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    if (shouldThrow) throw const FormatException('simulated non-AppFailure');
    return InboxResponse(
      items: const [
        InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          channelName: 'general',
          unreadCount: 2,
        ),
      ],
      totalCount: 1,
      totalUnreadCount: 2,
      hasMore: hasMore,
    );
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

// =============================================================================
// Fakes — ThreadsInboxStore
// =============================================================================

class _ThrowingThreadRepo implements ThreadRepository {
  bool shouldThrow = false;

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async {
    if (shouldThrow) throw const FormatException('simulated non-AppFailure');
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// =============================================================================
// Fakes — TasksStore
// =============================================================================

class _ThrowingTasksRepo implements TasksRepository {
  bool throwOnCreate = false;
  bool throwOnConvert = false;

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async => [];

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async {
    if (throwOnCreate) throw const FormatException('simulated non-AppFailure');
    return titles
        .map(
          (title) => TaskItem(
            id: 'task-${title.hashCode}',
            taskNumber: 1,
            title: title,
            status: 'todo',
            channelId: channelId,
            channelType: 'channel',
            createdById: 'user-1',
            createdByName: 'Tester',
            createdByType: 'human',
            createdAt: DateTime.utc(2026, 5, 20),
          ),
        )
        .toList();
  }

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async {
    if (throwOnConvert) {
      throw const FormatException('simulated non-AppFailure');
    }
    return TaskItem(
      id: 'task-converted',
      taskNumber: 1,
      title: 'Converted task',
      status: 'todo',
      channelId: 'ch-1',
      channelType: 'channel',
      createdById: 'user-1',
      createdByName: 'Tester',
      createdByType: 'human',
      createdAt: DateTime.utc(2026, 5, 20),
      messageId: messageId,
    );
  }

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {}

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw UnimplementedError();
}

// =============================================================================
// Fakes — ProfileDetailStore
// =============================================================================

class _FakeProfileRepo implements ProfileRepository {
  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) async =>
      MemberProfile(id: userId, displayName: 'Other User');
}

class _ThrowingMemberRepo implements MemberRepository {
  bool shouldThrow = false;

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    if (shouldThrow) throw const FormatException('simulated non-AppFailure');
    return 'dm-channel-id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// =============================================================================
// Fakes — TranslationCacheStore
// =============================================================================

class _ThrowingTranslationRepo implements TranslationRepository {
  bool shouldThrow = false;

  @override
  Future<List<TranslationResult>> translateBatch(
    ServerScopeId serverId, {
    required List<String> messageIds,
    required String targetLanguage,
  }) async {
    if (shouldThrow) throw const FormatException('simulated non-AppFailure');
    return messageIds
        .map(
          (id) => TranslationResult(
            messageId: id,
            translatedContent: 'translated-$id',
            sourceLanguage: 'zh',
            targetLanguage: targetLanguage,
            status: TranslationStatus.translated,
          ),
        )
        .toList();
  }

  @override
  Future<TranslationSettings> getSettings(ServerScopeId serverId) async =>
      const TranslationSettings();

  @override
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings settings,
  ) async =>
      settings;
}

class _FakeTranslationSettingsStore
    extends AutoDisposeNotifier<TranslationSettingsState>
    implements TranslationSettingsStore {
  @override
  TranslationSettingsState build() => const TranslationSettingsState(
        status: TranslationSettingsStatus.success,
        settings: TranslationSettings(preferredLanguage: 'en'),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// =============================================================================
// Fakes — Session
// =============================================================================

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Test User',
        token: 'fake-token',
      );
}
