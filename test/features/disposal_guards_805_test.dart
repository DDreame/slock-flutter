// =============================================================================
// #805 — PinnedMessagesStore + MemberListStore + ChannelMemberStore Disposal
//        Guards
//
// Verifies: Disposing the store during any async method does NOT throw
// StateError — the `_disposed` guard bails out silently.
//
// Load-bearing proof:
//   Reverting the `if (_disposed) return` guards in the 3 stores causes these
//   tests to fail (StateError from state assignment on a disposed notifier).
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/pinned_messages_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

void main() {
  // ---------------------------------------------------------------------------
  // PinnedMessagesStore disposal guards
  // ---------------------------------------------------------------------------
  group('#805 — PinnedMessagesStore disposal safety', () {
    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(serverId: ServerScopeId('srv-1'), value: 'ch-1'),
    );

    test('dispose during load() does not throw StateError', () async {
      final completer = Completer<List<ConversationMessageSummary>>();
      final repo = _DelayedConversationRepository(
        pinnedMessagesCompleter: completer,
      );

      final container = ProviderContainer(overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(pinnedMessagesStoreProvider, (_, __) {});
      final store = container.read(pinnedMessagesStoreProvider.notifier);
      final loadFuture = store.load();

      // Dispose before completer resolves — simulates navigation away.
      sub.close();
      container.dispose();

      completer.complete(const []);
      await loadFuture;
    });

    test('dispose during load() failure does not throw StateError', () async {
      final completer = Completer<List<ConversationMessageSummary>>();
      final repo = _DelayedConversationRepository(
        pinnedMessagesCompleter: completer,
      );

      final container = ProviderContainer(overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(pinnedMessagesStoreProvider, (_, __) {});
      final store = container.read(pinnedMessagesStoreProvider.notifier);
      final loadFuture = store.load();

      sub.close();
      container.dispose();

      completer.completeError(
        const NetworkFailure(message: 'timeout'),
      );
      await loadFuture;
    });
  });

  // ---------------------------------------------------------------------------
  // MemberListStore disposal guards
  // ---------------------------------------------------------------------------
  group('#805 — MemberListStore disposal safety', () {
    const serverId = ServerScopeId('srv-1');

    test('dispose during load() does not throw StateError', () async {
      final completer = Completer<List<MemberProfile>>();
      final repo = _DelayedMemberRepository(listCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentMembersServerIdProvider.overrideWithValue(serverId),
        memberRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(memberListStoreProvider, (_, __) {});
      final store = container.read(memberListStoreProvider.notifier);
      final loadFuture = store.load();

      sub.close();
      container.dispose();

      completer.complete(const []);
      await loadFuture;
    });

    test('dispose during inviteByEmail() does not throw StateError', () async {
      final completer = Completer<void>();
      final repo = _DelayedMemberRepository(inviteCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentMembersServerIdProvider.overrideWithValue(serverId),
        memberRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(memberListStoreProvider, (_, __) {});
      final store = container.read(memberListStoreProvider.notifier);
      final future = store.inviteByEmail('test@example.com');

      sub.close();
      container.dispose();

      completer.complete();
      await future;
    });

    test('dispose during createInvite() does not throw StateError', () async {
      final completer = Completer<String>();
      final repo = _DelayedMemberRepository(createInviteCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentMembersServerIdProvider.overrideWithValue(serverId),
        memberRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(memberListStoreProvider, (_, __) {});
      final store = container.read(memberListStoreProvider.notifier);
      final future = store.createInvite();

      sub.close();
      container.dispose();

      completer.complete('https://invite.link');
      await future;
    });

    test('dispose during updateMemberRole() does not throw StateError',
        () async {
      final completer = Completer<void>();
      final repo = _DelayedMemberRepository(updateRoleCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentMembersServerIdProvider.overrideWithValue(serverId),
        memberRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(memberListStoreProvider, (_, __) {});
      final store = container.read(memberListStoreProvider.notifier);
      final future = store.updateMemberRole('user-1', 'admin');

      sub.close();
      container.dispose();

      completer.complete();
      await future;
    });

    test('dispose during removeMember() does not throw StateError', () async {
      final completer = Completer<void>();
      final repo = _DelayedMemberRepository(removeCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentMembersServerIdProvider.overrideWithValue(serverId),
        memberRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(memberListStoreProvider, (_, __) {});
      final store = container.read(memberListStoreProvider.notifier);
      final future = store.removeMember('user-1');

      sub.close();
      container.dispose();

      completer.complete();
      await future;
    });
  });

  // ---------------------------------------------------------------------------
  // ChannelMemberStore disposal guards
  // ---------------------------------------------------------------------------
  group('#805 — ChannelMemberStore disposal safety', () {
    const serverId = ServerScopeId('srv-1');
    const channelId = 'ch-1';

    test('dispose during load() does not throw StateError', () async {
      final completer = Completer<List<ChannelMember>>();
      final repo = _DelayedChannelMemberRepository(listCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentChannelMemberServerIdProvider.overrideWithValue(serverId),
        currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
        channelMemberRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(channelMemberStoreProvider, (_, __) {});
      final store = container.read(channelMemberStoreProvider.notifier);
      final loadFuture = store.load();

      sub.close();
      container.dispose();

      completer.complete(const []);
      await loadFuture;
    });

    test('dispose during addHumanMember() does not throw StateError', () async {
      final completer = Completer<void>();
      final repo =
          _DelayedChannelMemberRepository(addHumanCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentChannelMemberServerIdProvider.overrideWithValue(serverId),
        currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
        channelMemberRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(channelMemberStoreProvider, (_, __) {});
      final store = container.read(channelMemberStoreProvider.notifier);
      final future = store.addHumanMember('user-1');

      sub.close();
      container.dispose();

      completer.complete();
      await future;
    });

    test('dispose during addAgentMember() does not throw StateError', () async {
      final completer = Completer<void>();
      final repo =
          _DelayedChannelMemberRepository(addAgentCompleter: completer);

      final container = ProviderContainer(overrides: [
        currentChannelMemberServerIdProvider.overrideWithValue(serverId),
        currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
        channelMemberRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(channelMemberStoreProvider, (_, __) {});
      final store = container.read(channelMemberStoreProvider.notifier);
      final future = store.addAgentMember('agent-1');

      sub.close();
      container.dispose();

      completer.complete();
      await future;
    });

    test('dispose during removeHumanMember() does not throw StateError',
        () async {
      final removeCompleter = Completer<void>();
      final repo = _DelayedChannelMemberRepository(
        removeHumanCompleter: removeCompleter,
      );
      // Pre-load items so remove has data to work with.
      repo.immediateListResult = const [
        ChannelMember(id: 'user-1', channelId: 'ch-1', userId: 'user-1'),
      ];

      final container = ProviderContainer(overrides: [
        currentChannelMemberServerIdProvider.overrideWithValue(serverId),
        currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
        channelMemberRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(channelMemberStoreProvider, (_, __) {});
      final store = container.read(channelMemberStoreProvider.notifier);
      await store.load();

      final future = store.removeHumanMember('user-1');

      sub.close();
      container.dispose();

      removeCompleter.complete();
      await future;
    });

    test('dispose during removeAgentMember() does not throw StateError',
        () async {
      final removeCompleter = Completer<void>();
      final repo = _DelayedChannelMemberRepository(
        removeAgentCompleter: removeCompleter,
      );
      // Pre-load items so remove has data to work with.
      repo.immediateListResult = const [
        ChannelMember(id: 'agent-1', channelId: 'ch-1', agentId: 'agent-1'),
      ];

      final container = ProviderContainer(overrides: [
        currentChannelMemberServerIdProvider.overrideWithValue(serverId),
        currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
        channelMemberRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(channelMemberStoreProvider, (_, __) {});
      final store = container.read(channelMemberStoreProvider.notifier);
      await store.load();

      final future = store.removeAgentMember('agent-1');

      sub.close();
      container.dispose();

      removeCompleter.complete();
      await future;
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _DelayedConversationRepository implements ConversationRepository {
  _DelayedConversationRepository({this.pinnedMessagesCompleter});

  Completer<List<ConversationMessageSummary>>? pinnedMessagesCompleter;

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) =>
      pinnedMessagesCompleter!.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _DelayedMemberRepository
    implements MemberRepository, MemberInviteMutationRepository {
  _DelayedMemberRepository({
    this.listCompleter,
    this.inviteCompleter,
    this.createInviteCompleter,
    this.updateRoleCompleter,
    this.removeCompleter,
  });

  Completer<List<MemberProfile>>? listCompleter;
  Completer<void>? inviteCompleter;
  Completer<String>? createInviteCompleter;
  Completer<void>? updateRoleCompleter;
  Completer<void>? removeCompleter;

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) =>
      listCompleter!.future;

  @override
  Future<void> inviteByEmail(
    ServerScopeId serverId, {
    required String email,
  }) =>
      inviteCompleter!.future;

  @override
  Future<String> createInvite(ServerScopeId serverId) =>
      createInviteCompleter!.future;

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) =>
      updateRoleCompleter!.future;

  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) =>
      removeCompleter!.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _DelayedChannelMemberRepository implements ChannelMemberRepository {
  _DelayedChannelMemberRepository({
    this.listCompleter,
    this.addHumanCompleter,
    this.addAgentCompleter,
    this.removeHumanCompleter,
    this.removeAgentCompleter,
  });

  Completer<List<ChannelMember>>? listCompleter;
  Completer<void>? addHumanCompleter;
  Completer<void>? addAgentCompleter;
  Completer<void>? removeHumanCompleter;
  Completer<void>? removeAgentCompleter;

  /// When non-null, listMembers returns this immediately instead of using
  /// listCompleter.
  List<ChannelMember>? immediateListResult;

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) {
    if (immediateListResult != null) {
      return Future.value(immediateListResult!);
    }
    return listCompleter!.future;
  }

  @override
  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) =>
      addHumanCompleter!.future;

  @override
  Future<void> addAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) =>
      addAgentCompleter!.future;

  @override
  Future<void> removeHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) =>
      removeHumanCompleter!.future;

  @override
  Future<void> removeAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) =>
      removeAgentCompleter!.future;
}
