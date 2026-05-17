// ---------------------------------------------------------------------------
// #557: Error Handling Hardening — firstOrNull + Realtime Catch Narrowing
//
// Problem:
//   1. `member_list_store.dart:171` uses `firstWhere` without `orElse`,
//      throwing unhandled `StateError` on DM open race condition.
//   2. 14 silent `catch (_) {}` blocks across 5 realtime/push files swallow
//      ALL exceptions (including TypeError, FormatException) — should narrow
//      to `on StateError` and route the rest to crash reporter.
//
// Phase A: skip:true invariants locking the error handling contracts.
//          Tests exercise actual MemberListStore and MembersRealtimeBinding
//          seams with ProviderContainer + fake repository + recording crash
//          reporter.
//
// Invariants verified:
// INV-MEMBER-SAFE-1: openDirectMessage with missing member returns gracefully
// INV-MEMBER-SAFE-2: openDirectMessage with valid member still works
// INV-CATCH-NARROW-1: StateError from disposed provider is silently caught
// INV-CATCH-NARROW-2: TypeError in realtime binding reaches crash reporter
// INV-CATCH-NARROW-3: FormatException in realtime binding reaches crash reporter
// INV-CATCH-REPORT-1: crashReporter.captureException called with original exception
// ---------------------------------------------------------------------------
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/application/members_realtime_binding.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

void main() {
  const serverId = ServerScopeId('server-1');

  // -----------------------------------------------------------------------
  // INV-MEMBER-SAFE-1: openDirectMessage with missing member
  // -----------------------------------------------------------------------
  group('INV-MEMBER-SAFE-1: missing member safety', () {
    test(
      'openDirectMessage with non-existent userId does not throw StateError',
      () async {
        final repo = _FakeMemberRepository();
        repo.members = const [
          MemberProfile(id: 'user-1', displayName: 'Alice'),
        ];
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            currentMembersServerIdProvider.overrideWithValue(serverId),
            memberRepositoryProvider.overrideWithValue(repo),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
        );
        addTearDown(container.dispose);

        // Load members so state.members is populated.
        await container.read(memberListStoreProvider.notifier).load();
        expect(
          container.read(memberListStoreProvider).members,
          isNotEmpty,
          reason: 'Members must be loaded before testing openDirectMessage',
        );

        // Call openDirectMessage with a userId that does NOT exist in the list.
        // On current code this throws StateError from firstWhere.
        // Phase B replaces firstWhere with firstOrNull + graceful handling.
        Object? caughtError;
        try {
          await container
              .read(memberListStoreProvider.notifier)
              .openDirectMessage('nonexistent-user');
        } catch (e) {
          caughtError = e;
        }

        // After Phase B fix, this must NOT be a StateError — it should be
        // an AppFailure (user-facing error) or null (handled gracefully).
        expect(caughtError, isNot(isA<StateError>()),
            reason: 'Missing member must not produce uncaught StateError');
      },
      skip: 'Phase A: invariant locked — Phase B adds firstOrNull',
    );

    test(
      'openDirectMessage returns AppFailure for missing member',
      () async {
        final repo = _FakeMemberRepository();
        repo.members = const [
          MemberProfile(id: 'user-1', displayName: 'Alice'),
        ];
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            currentMembersServerIdProvider.overrideWithValue(serverId),
            memberRepositoryProvider.overrideWithValue(repo),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(memberListStoreProvider.notifier).load();

        // Phase B: openDirectMessage('missing') should throw AppFailure.
        expect(
          () => container
              .read(memberListStoreProvider.notifier)
              .openDirectMessage('nonexistent-user'),
          throwsA(isA<AppFailure>()),
          reason: 'Missing member must produce AppFailure, not StateError',
        );
      },
      skip: 'Phase A: invariant locked — Phase B adds firstOrNull',
    );
  });

  // -----------------------------------------------------------------------
  // INV-MEMBER-SAFE-2: openDirectMessage with valid member
  // -----------------------------------------------------------------------
  group('INV-MEMBER-SAFE-2: valid member still works', () {
    test(
      'openDirectMessage with existing member returns channel ID',
      () async {
        final repo = _FakeMemberRepository();
        repo.members = const [
          MemberProfile(id: 'user-1', displayName: 'Alice'),
        ];
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            currentMembersServerIdProvider.overrideWithValue(serverId),
            memberRepositoryProvider.overrideWithValue(repo),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(memberListStoreProvider.notifier).load();

        // Happy path: member exists → DM opens normally.
        final channelId = await container
            .read(memberListStoreProvider.notifier)
            .openDirectMessage('user-1');
        expect(channelId, equals('dm-1'),
            reason: 'Valid member must resolve to DM channel ID');
        expect(repo.openRequests, [(serverId, 'user-1')],
            reason: 'Repository must receive the open request');
      },
      skip: 'Phase A: invariant locked — Phase B validates happy path',
    );
  });

  // -----------------------------------------------------------------------
  // INV-CATCH-NARROW-1: StateError silently caught
  // -----------------------------------------------------------------------
  group('INV-CATCH-NARROW-1: StateError still caught silently', () {
    test(
      'StateError from store load in realtime binding is silently swallowed',
      () async {
        final repo = _FakeMemberRepository();
        // Make listMembers throw StateError (simulates disposed provider).
        repo.loadFailure = StateError('Bad state: No element');
        final recorder = _RecordingCrashReporter();
        final ingress = RealtimeReductionIngress();
        final serverLoader = _FakeServerListLoader();

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            currentMembersServerIdProvider.overrideWithValue(serverId),
            memberRepositoryProvider.overrideWithValue(repo),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            crashReporterProvider.overrideWithValue(recorder),
            serverListLoaderProvider.overrideWithValue(serverLoader.call),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await ingress.dispose();
        });

        // Activate binding + keep store alive.
        final stateSub = container.listen(memberListStoreProvider, (_, __) {});
        final bindingSub =
            container.listen(membersRealtimeBindingProvider, (_, __) {});
        addTearDown(() {
          bindingSub.close();
          stateSub.close();
        });

        // Inject a membership-removed event that triggers the catch block.
        ingress.accept(
          RealtimeEventEnvelope(
            eventType: 'server:membership-removed',
            scopeKey: 'server:server-1',
            receivedAt: DateTime.now(),
            payload: const {'serverId': 'server-1'},
          ),
        );
        await _drainAsyncWork();

        // After Phase B narrowing, StateError is still silently caught
        // (existing behavior preserved) — crash reporter must NOT be called.
        expect(recorder.captured, isEmpty,
            reason: 'StateError must be silently swallowed, not reported');
      },
      skip: 'Phase A: invariant locked — Phase B narrows catch blocks',
    );
  });

  // -----------------------------------------------------------------------
  // INV-CATCH-NARROW-2: TypeError reaches crash reporter
  // -----------------------------------------------------------------------
  group('INV-CATCH-NARROW-2: TypeError not silently swallowed', () {
    test(
      'TypeError in realtime binding is forwarded to crash reporter',
      () async {
        final repo = _FakeMemberRepository();
        // Make listMembers throw TypeError (unexpected runtime error).
        repo.loadFailure = TypeError();
        final recorder = _RecordingCrashReporter();
        final ingress = RealtimeReductionIngress();
        final serverLoader = _FakeServerListLoader();

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            currentMembersServerIdProvider.overrideWithValue(serverId),
            memberRepositoryProvider.overrideWithValue(repo),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            crashReporterProvider.overrideWithValue(recorder),
            serverListLoaderProvider.overrideWithValue(serverLoader.call),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await ingress.dispose();
        });

        final stateSub = container.listen(memberListStoreProvider, (_, __) {});
        final bindingSub =
            container.listen(membersRealtimeBindingProvider, (_, __) {});
        addTearDown(() {
          bindingSub.close();
          stateSub.close();
        });

        ingress.accept(
          RealtimeEventEnvelope(
            eventType: 'server:membership-removed',
            scopeKey: 'server:server-1',
            receivedAt: DateTime.now(),
            payload: const {'serverId': 'server-1'},
          ),
        );
        await _drainAsyncWork();

        // After Phase B narrowing, TypeError falls through to the
        // catch-all and is forwarded to crash reporter.
        expect(recorder.captured, isNotEmpty,
            reason: 'TypeError must reach crash reporter');
        expect(recorder.captured.first.$1, isA<TypeError>(),
            reason: 'Captured exception must be the original TypeError');
      },
      skip: 'Phase A: invariant locked — Phase B narrows catch blocks',
    );
  });

  // -----------------------------------------------------------------------
  // INV-CATCH-NARROW-3: FormatException reaches crash reporter
  // -----------------------------------------------------------------------
  group('INV-CATCH-NARROW-3: FormatException not silently swallowed', () {
    test(
      'FormatException from malformed event payload reaches crash reporter',
      () async {
        final repo = _FakeMemberRepository();
        // Make listMembers throw FormatException (malformed data).
        repo.loadFailure = const FormatException('Unexpected end of input');
        final recorder = _RecordingCrashReporter();
        final ingress = RealtimeReductionIngress();
        final serverLoader = _FakeServerListLoader();

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            currentMembersServerIdProvider.overrideWithValue(serverId),
            memberRepositoryProvider.overrideWithValue(repo),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            crashReporterProvider.overrideWithValue(recorder),
            serverListLoaderProvider.overrideWithValue(serverLoader.call),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await ingress.dispose();
        });

        final stateSub = container.listen(memberListStoreProvider, (_, __) {});
        final bindingSub =
            container.listen(membersRealtimeBindingProvider, (_, __) {});
        addTearDown(() {
          bindingSub.close();
          stateSub.close();
        });

        ingress.accept(
          RealtimeEventEnvelope(
            eventType: 'server:membership-removed',
            scopeKey: 'server:server-1',
            receivedAt: DateTime.now(),
            payload: const {'serverId': 'server-1'},
          ),
        );
        await _drainAsyncWork();

        // After Phase B narrowing, FormatException reaches crash reporter.
        expect(recorder.captured, isNotEmpty,
            reason: 'FormatException must reach crash reporter');
        expect(recorder.captured.first.$1, isA<FormatException>(),
            reason: 'Captured exception must be the original FormatException');
      },
      skip: 'Phase A: invariant locked — Phase B narrows catch blocks',
    );
  });

  // -----------------------------------------------------------------------
  // INV-CATCH-REPORT-1: captureException called with original exception
  // -----------------------------------------------------------------------
  group('INV-CATCH-REPORT-1: crash reporter receives original exception', () {
    test(
      'captureException is called with the original exception and stack trace',
      () async {
        final originalError = ArgumentError('bad argument');
        final repo = _FakeMemberRepository();
        repo.loadFailure = originalError;
        final recorder = _RecordingCrashReporter();
        final ingress = RealtimeReductionIngress();
        final serverLoader = _FakeServerListLoader();

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            currentMembersServerIdProvider.overrideWithValue(serverId),
            memberRepositoryProvider.overrideWithValue(repo),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            crashReporterProvider.overrideWithValue(recorder),
            serverListLoaderProvider.overrideWithValue(serverLoader.call),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await ingress.dispose();
        });

        final stateSub = container.listen(memberListStoreProvider, (_, __) {});
        final bindingSub =
            container.listen(membersRealtimeBindingProvider, (_, __) {});
        addTearDown(() {
          bindingSub.close();
          stateSub.close();
        });

        ingress.accept(
          RealtimeEventEnvelope(
            eventType: 'server:membership-removed',
            scopeKey: 'server:server-1',
            receivedAt: DateTime.now(),
            payload: const {'serverId': 'server-1'},
          ),
        );
        await _drainAsyncWork();

        // After Phase B narrowing, captureException receives the exact
        // exception and a non-null stack trace.
        expect(recorder.captured, hasLength(1),
            reason: 'Exactly one exception must be captured');
        expect(identical(recorder.captured.first.$1, originalError), isTrue,
            reason: 'Captured exception must be the identical object');
        expect(recorder.captured.first.$2, isNotNull,
            reason: 'Stack trace must be provided');
      },
      skip: 'Phase A: invariant locked — Phase B narrows catch blocks',
    );
  });
}

// -- Helpers -----------------------------------------------------------------

Future<void> _drainAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeMemberRepository implements MemberRepository {
  List<MemberProfile> members = const [];
  Object? loadFailure;
  final List<(ServerScopeId, String)> openRequests = [];

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    if (loadFailure != null) throw loadFailure!;
    return members;
  }

  @override
  Future<String> createInvite(ServerScopeId serverId) async => 'invite';

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) async {}

  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) async {}

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    openRequests.add((serverId, userId));
    return 'dm-1';
  }

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'dm-agent-$agentId';
}

class _FakeServerListLoader {
  int callCount = 0;

  Future<List<ServerSummary>> call() async {
    callCount += 1;
    return const [];
  }
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-123',
        displayName: 'Alice',
        token: 'test-token',
      );
}

/// Records all `captureException` calls for test assertion.
class _RecordingCrashReporter implements CrashReporter {
  final List<(Object, StackTrace?)> captured = [];

  @override
  Future<void> init() async {}

  @override
  void captureException(Object error,
      {StackTrace? stackTrace, Map<String, dynamic>? extra}) {
    captured.add((error, stackTrace));
  }

  @override
  void captureFlutterError(FlutterErrorDetails details) {}

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {}

  @override
  void setUser(String? userId, {String? displayName}) {}
}
