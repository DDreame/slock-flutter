// =============================================================================
// #663 — MembersPage memberListStoreProvider .select() narrow (widget-path)
//
// Invariant: INV-MEMBERS-663-SELECT-1
//   _MembersScreen.build() watches memberListStoreProvider narrowed to:
//     (status, canManageMembers, isInvitingByEmail, isEmpty)
//   Mutations to query, openingDirectMessageMemberId, updatingRoleMemberIds,
//   removingMemberIds, or individual member content must NOT trigger a scaffold
//   rebuild.
//
// Strategy (widget-path tests using pumpWidget + Consumer rebuild counters):
// T1: query change must NOT rebuild scaffold.
// T2: updatingRoleMemberIds change must NOT rebuild scaffold.
// T3: openingDirectMessageMemberId change must NOT rebuild scaffold.
// T4: status change DOES rebuild scaffold.
// T5: isInvitingByEmail change DOES rebuild scaffold.
// T6: isEmpty transition DOES rebuild scaffold.
// T7: compound mutations — only select-relevant changes trigger rebuild.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableMemberListStore extends AutoDisposeNotifier<MemberListState>
    implements MemberListStore {
  @override
  MemberListState build() => MemberListState(
        status: MemberListStatus.success,
        members: [_makeMember('m-1')],
      );

  void setQueryDirect(String query) {
    state = state.copyWith(query: query);
  }

  void setUpdatingRoleMemberIdsDirect(Set<String> ids) {
    state = state.copyWith(updatingRoleMemberIds: ids);
  }

  void setOpeningDirectMessageMemberIdDirect(String? id) {
    if (id == null) {
      state = state.copyWith(clearOpeningDirectMessage: true);
    } else {
      state = state.copyWith(openingDirectMessageMemberId: id);
    }
  }

  void setStatusDirect(MemberListStatus status) {
    state = state.copyWith(status: status);
  }

  void setIsInvitingByEmailDirect(bool value) {
    state = state.copyWith(isInvitingByEmail: value);
  }

  void setMembersDirect(List<MemberProfile> members) {
    state = state.copyWith(members: members);
  }

  // Stubs for MemberListStore interface — not needed for this test.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MemberProfile _makeMember(String id) => MemberProfile(
      id: id,
      displayName: 'User $id',
      role: 'member',
    );

// ---------------------------------------------------------------------------
// Widget-path test harness
//
// Renders a ConsumerWidget that uses the EXACT .select() expression from
// _MembersScreenState.build():
//   ref.watch(memberListStoreProvider.select((s) => (
//     status: s.status,
//     canManageMembers: s.canManageMembers,
//     isInvitingByEmail: s.isInvitingByEmail,
//     isEmpty: s.members.isEmpty,
//   )))
// ---------------------------------------------------------------------------

class _MembersScaffoldSelectConsumer extends ConsumerWidget {
  const _MembersScaffoldSelectConsumer({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      memberListStoreProvider.select(
        (s) => (
          status: s.status,
          canManageMembers: s.canManageMembers,
          isInvitingByEmail: s.isInvitingByEmail,
          isEmpty: s.members.isEmpty,
        ),
      ),
    );
    onBuild();
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: query change must NOT rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-MEMBERS-663-SELECT-1: query change does NOT rebuild scaffold widget',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMembersServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            memberListStoreProvider
                .overrideWith(() => _ControllableMemberListStore()),
          ],
          child: MaterialApp(
            home: _MembersScaffoldSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element =
          tester.element(find.byType(_MembersScaffoldSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(memberListStoreProvider.notifier)
          as _ControllableMemberListStore;

      store.setQueryDirect('alice');
      await tester.pump();

      expect(
        buildCount,
        1,
        reason: 'query change must NOT rebuild scaffold '
            '(INV-MEMBERS-663-SELECT-1)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T2: updatingRoleMemberIds change must NOT rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-MEMBERS-663-SELECT-1: updatingRoleMemberIds change does NOT rebuild '
    'scaffold widget',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMembersServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            memberListStoreProvider
                .overrideWith(() => _ControllableMemberListStore()),
          ],
          child: MaterialApp(
            home: _MembersScaffoldSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element =
          tester.element(find.byType(_MembersScaffoldSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(memberListStoreProvider.notifier)
          as _ControllableMemberListStore;

      store.setUpdatingRoleMemberIdsDirect({'m-1'});
      await tester.pump();

      expect(
        buildCount,
        1,
        reason: 'updatingRoleMemberIds change must NOT rebuild scaffold '
            '(INV-MEMBERS-663-SELECT-1)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T3: openingDirectMessageMemberId change must NOT rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-MEMBERS-663-SELECT-1: openingDirectMessageMemberId change does NOT '
    'rebuild scaffold widget',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMembersServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            memberListStoreProvider
                .overrideWith(() => _ControllableMemberListStore()),
          ],
          child: MaterialApp(
            home: _MembersScaffoldSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element =
          tester.element(find.byType(_MembersScaffoldSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(memberListStoreProvider.notifier)
          as _ControllableMemberListStore;

      store.setOpeningDirectMessageMemberIdDirect('m-1');
      await tester.pump();

      expect(
        buildCount,
        1,
        reason: 'openingDirectMessageMemberId change must NOT rebuild scaffold '
            '(INV-MEMBERS-663-SELECT-1)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T4: status change DOES rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-MEMBERS-663-SELECT-1: status change DOES rebuild scaffold widget',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMembersServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            memberListStoreProvider
                .overrideWith(() => _ControllableMemberListStore()),
          ],
          child: MaterialApp(
            home: _MembersScaffoldSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element =
          tester.element(find.byType(_MembersScaffoldSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(memberListStoreProvider.notifier)
          as _ControllableMemberListStore;

      store.setStatusDirect(MemberListStatus.loading);
      await tester.pump();

      expect(buildCount, 2, reason: 'status change must rebuild scaffold');
    },
  );

  // -------------------------------------------------------------------------
  // T5: isInvitingByEmail change DOES rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-MEMBERS-663-SELECT-1: isInvitingByEmail change DOES rebuild '
    'scaffold widget',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMembersServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            memberListStoreProvider
                .overrideWith(() => _ControllableMemberListStore()),
          ],
          child: MaterialApp(
            home: _MembersScaffoldSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element =
          tester.element(find.byType(_MembersScaffoldSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(memberListStoreProvider.notifier)
          as _ControllableMemberListStore;

      store.setIsInvitingByEmailDirect(true);
      await tester.pump();

      expect(buildCount, 2,
          reason: 'isInvitingByEmail change must rebuild scaffold');
    },
  );

  // -------------------------------------------------------------------------
  // T6: isEmpty transition DOES rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-MEMBERS-663-SELECT-1: isEmpty transition DOES rebuild scaffold widget',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMembersServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            memberListStoreProvider
                .overrideWith(() => _ControllableMemberListStore()),
          ],
          child: MaterialApp(
            home: _MembersScaffoldSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element =
          tester.element(find.byType(_MembersScaffoldSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(memberListStoreProvider.notifier)
          as _ControllableMemberListStore;

      // Transition from non-empty to empty.
      store.setMembersDirect([]);
      await tester.pump();

      expect(buildCount, 2,
          reason: 'isEmpty transition (non-empty -> empty) must rebuild');
    },
  );

  // -------------------------------------------------------------------------
  // T7: compound mutations — only select-relevant changes trigger rebuild.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-MEMBERS-663-SELECT-1: compound mutations — only scaffold-relevant '
    'changes trigger widget rebuild',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentMembersServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            memberListStoreProvider
                .overrideWith(() => _ControllableMemberListStore()),
          ],
          child: MaterialApp(
            home: _MembersScaffoldSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element =
          tester.element(find.byType(_MembersScaffoldSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(memberListStoreProvider.notifier)
          as _ControllableMemberListStore;

      // 1. query change — no rebuild.
      store.setQueryDirect('test');
      await tester.pump();
      expect(buildCount, 1);

      // 2. updatingRoleMemberIds change — no rebuild.
      store.setUpdatingRoleMemberIdsDirect({'m-1', 'm-2'});
      await tester.pump();
      expect(buildCount, 1);

      // 3. openingDirectMessageMemberId change — no rebuild.
      store.setOpeningDirectMessageMemberIdDirect('m-1');
      await tester.pump();
      expect(buildCount, 1);

      // 4. status change — rebuild.
      store.setStatusDirect(MemberListStatus.loading);
      await tester.pump();
      expect(buildCount, 2);

      // 5. isInvitingByEmail change — rebuild.
      store.setIsInvitingByEmailDirect(true);
      await tester.pump();
      expect(buildCount, 3);
    },
  );
}
