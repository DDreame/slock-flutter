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
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

void main() {
  const serverId = ServerScopeId('server-1');

  test(
      'server:membership-removed reloads members and clears invalid active selection',
      () async {
    final memberRepository = _FakeMemberRepository();
    final serverLoader = _FakeServerListLoader();
    final ingress = RealtimeReductionIngress();
    memberRepository.members = const [
      MemberProfile(id: 'user-123', displayName: 'Alice'),
    ];
    serverLoader.responses = const [
      [ServerSummary(id: 'server-2', name: 'Other workspace')],
    ];
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        currentMembersServerIdProvider.overrideWithValue(serverId),
        memberRepositoryProvider.overrideWithValue(memberRepository),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        serverListLoaderProvider.overrideWithValue(serverLoader.call),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await ingress.dispose();
    });

    await container
        .read(serverSelectionStoreProvider.notifier)
        .selectServer(serverId.value);
    final stateSub = container.listen(memberListStoreProvider, (_, __) {});
    final bindingSub =
        container.listen(membersRealtimeBindingProvider, (_, __) {});
    addTearDown(() {
      bindingSub.close();
      stateSub.close();
    });

    await container.read(memberListStoreProvider.notifier).load();
    expect(memberRepository.listCalls, 1);

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'server:membership-removed',
        scopeKey: 'server:server-1',
        receivedAt: DateTime.now(),
        payload: const {'serverId': 'server-1'},
      ),
    );
    await _drainAsyncWork();

    expect(memberRepository.listCalls, 2);
    expect(serverLoader.callCount, 1);
    expect(
        container.read(serverSelectionStoreProvider).selectedServerId, isNull);
  });
}

Future<void> _drainAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeMemberRepository implements MemberRepository {
  List<MemberProfile> members = const [];
  int listCalls = 0;

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    listCalls += 1;
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
  }) async =>
      'dm-1';

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'dm-agent-$agentId';
}

class _FakeServerListLoader {
  List<List<ServerSummary>> responses = const [];
  int callCount = 0;

  Future<List<ServerSummary>> call() async {
    callCount += 1;
    if (responses.isEmpty) {
      return const [];
    }
    if (callCount <= responses.length) {
      return responses[callCount - 1];
    }
    return responses.last;
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
