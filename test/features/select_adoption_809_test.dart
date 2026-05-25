// =============================================================================
// #809 — .select() Adoption A: AddMemberDialog + NewDmPage
//
// Invariant: INV-SELECT-809
//   AddMemberDialog and NewDmPage must only rebuild when consumed fields
//   change:
//   - memberListStoreProvider → (status, failure, members) only
//   - agentsStoreProvider → (status, failure, items) only
//
// Strategy:
// T1: memberList: isInvitingByEmail change must NOT fire select (skip:true).
// T2: memberList: updatingRoleMemberIds change must NOT fire select (skip:true).
// T3: memberList: members change DOES fire select (active).
// T4: memberList: status change DOES fire select (active).
// T5: agents: isRefreshing change must NOT fire select (skip:true).
// T6: agents: machines change must NOT fire select (skip:true).
// T7: agents: isCreating change must NOT fire select (skip:true).
// T8: agents: items change DOES fire select (active).
// T9: agents: status change DOES fire select (active).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableMemberListStore extends MemberListStore {
  @override
  MemberListState build() => MemberListState(
        status: MemberListStatus.success,
        members: const [
          MemberProfile(
            id: 'u1',
            displayName: 'Alice',
            type: MemberType.human,
            role: 'member',
          ),
        ],
      );

  void setIsInvitingByEmailDirect(bool value) {
    state = state.copyWith(isInvitingByEmail: value);
  }

  void setUpdatingRoleMemberIdsDirect(Set<String> ids) {
    state = state.copyWith(updatingRoleMemberIds: ids);
  }

  void setMembersDirect(List<MemberProfile> members) {
    state = state.copyWith(members: members);
  }

  void setStatusDirect(MemberListStatus status) {
    state = state.copyWith(status: status);
  }
}

class _ControllableAgentsStore extends AgentsStore {
  @override
  AgentsState build() => const AgentsState(
        status: AgentsStatus.success,
        items: [
          AgentItem(
            id: 'a1',
            name: 'bot1',
            displayName: 'Bot1',
            model: 'claude',
            runtime: 'slock',
            status: 'active',
            activity: 'idle',
          ),
        ],
      );

  void setIsRefreshingDirect(bool value) {
    state = state.copyWith(isRefreshing: value);
  }

  void setMachinesDirect(List<dynamic> machines) {
    state = state.copyWith(machines: []);
  }

  void setIsCreatingDirect(bool value) {
    state = state.copyWith(isCreating: value);
  }

  void setItemsDirect(List<AgentItem> items) {
    state = state.copyWith(items: items);
  }

  void setStatusDirect(AgentsStatus status) {
    state = state.copyWith(status: status);
  }
}

// ---------------------------------------------------------------------------
// Tests — MemberListStore select narrowing
// ---------------------------------------------------------------------------

void main() {
  group('INV-SELECT-809: AddMemberDialog / NewDmPage — memberListStore select',
      () {
    // -------------------------------------------------------------------------
    // T1: isInvitingByEmail change must NOT fire members select.
    // -------------------------------------------------------------------------
    test(
      'isInvitingByEmail change does NOT notify (status, failure, members) select',
      () {
        final container = ProviderContainer(
          overrides: [
            memberListStoreProvider
                .overrideWith(() => _ControllableMemberListStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(memberListStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          memberListStoreProvider.select(
            (s) => (status: s.status, failure: s.failure, members: s.members),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(memberListStoreProvider.notifier)
            as _ControllableMemberListStore;
        store.setIsInvitingByEmailDirect(true);

        expect(
          selectNotifyCount,
          0,
          reason: 'isInvitingByEmail change must not notify consumed fields '
              '(INV-SELECT-809)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T2: updatingRoleMemberIds change must NOT fire members select.
    // -------------------------------------------------------------------------
    test(
      'updatingRoleMemberIds change does NOT notify (status, failure, members) select',
      () {
        final container = ProviderContainer(
          overrides: [
            memberListStoreProvider
                .overrideWith(() => _ControllableMemberListStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(memberListStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          memberListStoreProvider.select(
            (s) => (status: s.status, failure: s.failure, members: s.members),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(memberListStoreProvider.notifier)
            as _ControllableMemberListStore;
        store.setUpdatingRoleMemberIdsDirect({'u1'});

        expect(
          selectNotifyCount,
          0,
          reason:
              'updatingRoleMemberIds change must not notify consumed fields '
              '(INV-SELECT-809)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T3: members change DOES fire select.
    // -------------------------------------------------------------------------
    test(
      'members change DOES notify (status, failure, members) select',
      () {
        final container = ProviderContainer(
          overrides: [
            memberListStoreProvider
                .overrideWith(() => _ControllableMemberListStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(memberListStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          memberListStoreProvider.select(
            (s) => (status: s.status, failure: s.failure, members: s.members),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(memberListStoreProvider.notifier)
            as _ControllableMemberListStore;
        store.setMembersDirect(const [
          MemberProfile(
            id: 'u1',
            displayName: 'Alice',
            type: MemberType.human,
            role: 'member',
          ),
          MemberProfile(
            id: 'u2',
            displayName: 'Bob',
            type: MemberType.human,
            role: 'member',
          ),
        ]);

        expect(
          selectNotifyCount,
          1,
          reason: 'members change must notify consumed fields',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T4: status change DOES fire select.
    // -------------------------------------------------------------------------
    test(
      'status change DOES notify (status, failure, members) select',
      () {
        final container = ProviderContainer(
          overrides: [
            memberListStoreProvider
                .overrideWith(() => _ControllableMemberListStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(memberListStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          memberListStoreProvider.select(
            (s) => (status: s.status, failure: s.failure, members: s.members),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(memberListStoreProvider.notifier)
            as _ControllableMemberListStore;
        store.setStatusDirect(MemberListStatus.loading);

        expect(
          selectNotifyCount,
          1,
          reason: 'status change must notify consumed fields',
        );
      },
    );
  });

  group('INV-SELECT-809: AddMemberDialog / NewDmPage — agentsStore select', () {
    // -------------------------------------------------------------------------
    // T5: isRefreshing change must NOT fire select.
    // -------------------------------------------------------------------------
    test(
      'isRefreshing change does NOT notify (status, failure, items) select',
      () {
        final container = ProviderContainer(
          overrides: [
            agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(agentsStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          agentsStoreProvider.select(
            (s) => (status: s.status, failure: s.failure, items: s.items),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(agentsStoreProvider.notifier)
            as _ControllableAgentsStore;
        store.setIsRefreshingDirect(true);

        expect(
          selectNotifyCount,
          0,
          reason: 'isRefreshing change must not notify consumed fields '
              '(INV-SELECT-809)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T6: machines change must NOT fire select.
    // -------------------------------------------------------------------------
    test(
      'machines change does NOT notify (status, failure, items) select',
      () {
        final container = ProviderContainer(
          overrides: [
            agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(agentsStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          agentsStoreProvider.select(
            (s) => (status: s.status, failure: s.failure, items: s.items),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(agentsStoreProvider.notifier)
            as _ControllableAgentsStore;
        store.setMachinesDirect([]);

        expect(
          selectNotifyCount,
          0,
          reason: 'machines change must not notify consumed fields '
              '(INV-SELECT-809)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T7: isCreating change must NOT fire select.
    // -------------------------------------------------------------------------
    test(
      'isCreating change does NOT notify (status, failure, items) select',
      () {
        final container = ProviderContainer(
          overrides: [
            agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(agentsStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          agentsStoreProvider.select(
            (s) => (status: s.status, failure: s.failure, items: s.items),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(agentsStoreProvider.notifier)
            as _ControllableAgentsStore;
        store.setIsCreatingDirect(true);

        expect(
          selectNotifyCount,
          0,
          reason: 'isCreating change must not notify consumed fields '
              '(INV-SELECT-809)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T8: items change DOES fire select.
    // -------------------------------------------------------------------------
    test(
      'items change DOES notify (status, failure, items) select',
      () {
        final container = ProviderContainer(
          overrides: [
            agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(agentsStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          agentsStoreProvider.select(
            (s) => (status: s.status, failure: s.failure, items: s.items),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(agentsStoreProvider.notifier)
            as _ControllableAgentsStore;
        store.setItemsDirect(const [
          AgentItem(
            id: 'a1',
            name: 'bot1',
            displayName: 'Bot1',
            model: 'claude',
            runtime: 'slock',
            status: 'active',
            activity: 'idle',
          ),
          AgentItem(
            id: 'a2',
            name: 'bot2',
            displayName: 'Bot2',
            model: 'gpt4',
            runtime: 'slock',
            status: 'active',
            activity: 'idle',
          ),
        ]);

        expect(
          selectNotifyCount,
          1,
          reason: 'items change must notify consumed fields',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T9: status change DOES fire select.
    // -------------------------------------------------------------------------
    test(
      'status change DOES notify (status, failure, items) select',
      () {
        final container = ProviderContainer(
          overrides: [
            agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(agentsStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          agentsStoreProvider.select(
            (s) => (status: s.status, failure: s.failure, items: s.items),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(agentsStoreProvider.notifier)
            as _ControllableAgentsStore;
        store.setStatusDirect(AgentsStatus.loading);

        expect(
          selectNotifyCount,
          1,
          reason: 'status change must notify consumed fields',
        );
      },
    );
  });
}
