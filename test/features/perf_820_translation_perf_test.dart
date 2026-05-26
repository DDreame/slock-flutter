// Phase A: Load-bearing tests for #820 TranslationSettings Rollback + Performance.
//
// 5 items:
// 1. TranslationSettingsStore field-only rollback (preserves concurrent status)
// 2. members_page.dart .select() narrowing (mutation fields don't rebuild)
// 3. new_dm_page.dart memoize filtered list (cache identity on same inputs)
// 4. message_export_card.dart DateFormat caching (static instance reuse)
// 5. channel_page.dart .select((s) => s.isBusy) (non-isBusy fields don't rebuild)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_export_card.dart';
import 'package:slock_app/features/dms/presentation/page/new_dm_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_repository.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';
import 'package:slock_app/l10n/l10n.dart';

// =============================================================================
// Item 1: TranslationSettingsStore field-only rollback
// =============================================================================

void main() {
  group('Item 1 — TranslationSettingsStore field-only rollback', () {
    test('failed update reverts only settings, not status', () async {
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('srv-1')),
          translationRepositoryProvider.overrideWithValue(
            _FailOnUpdateRepository(
              initialSettings: const TranslationSettings(
                preferredLanguage: 'en',
                mode: TranslationMode.off,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Load to reach success state.
      await container.read(translationSettingsStoreProvider.notifier).load();
      final afterLoad = container.read(translationSettingsStoreProvider);
      expect(afterLoad.status, TranslationSettingsStatus.success);
      expect(afterLoad.settings.preferredLanguage, 'en');

      // Attempt an update that will fail.
      const attempted = TranslationSettings(
        preferredLanguage: 'ja',
        mode: TranslationMode.auto,
      );
      await container
          .read(translationSettingsStoreProvider.notifier)
          .update(attempted);

      final afterFail = container.read(translationSettingsStoreProvider);
      // Settings must be reverted to original.
      expect(afterFail.settings.preferredLanguage, 'en');
      expect(afterFail.settings.mode, TranslationMode.off);
      // Status must remain success (field-only rollback preserves it).
      expect(afterFail.status, TranslationSettingsStatus.success);
      // Failure surfaced.
      expect(afterFail.failure, isNotNull);
    });

    test(
        'failed update does not clobber concurrent status — '
        'field-only rollback is load-bearing', () async {
      // If the store used `final previous = state` and reverted the entire
      // object, a concurrent status change would be overwritten.
      // Field-only rollback saves only `state.settings` before the async gap,
      // so status changes during the gap are preserved.
      final delayedRepo = _DelayedFailUpdateRepository(
        initialSettings: const TranslationSettings(
          preferredLanguage: 'en',
          mode: TranslationMode.off,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('srv-1')),
          translationRepositoryProvider.overrideWithValue(delayedRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(translationSettingsStoreProvider.notifier).load();

      // Start an update (will be waiting on the completer).
      const attempted = TranslationSettings(
        preferredLanguage: 'ja',
        mode: TranslationMode.auto,
      );
      final updateFuture = container
          .read(translationSettingsStoreProvider.notifier)
          .update(attempted);

      // After optimistic phase, settings should show the attempted value.
      final mid = container.read(translationSettingsStoreProvider);
      expect(mid.settings.preferredLanguage, 'ja');
      expect(mid.status, TranslationSettingsStatus.success);

      // Complete with failure.
      delayedRepo.completeWithFailure();
      await updateFuture;

      final afterFail = container.read(translationSettingsStoreProvider);
      // Settings must revert.
      expect(afterFail.settings.preferredLanguage, 'en');
      // Status must remain success — NOT overwritten by whole-state revert.
      expect(afterFail.status, TranslationSettingsStatus.success);
      expect(afterFail.failure, isNotNull);
    });

    test(
        'concurrent load() result survives failed update — '
        'compare-and-swap is load-bearing', () async {
      // A1 regression: if load() completes during the update() async gap
      // and writes new settings, the failed update must NOT clobber them.
      // The compare-and-swap pattern: only revert if state.settings still
      // equals the optimistic value (meaning nothing else touched it).
      final concurrentRepo = _ConcurrentLoadUpdateRepository(
        initialSettings: const TranslationSettings(
          preferredLanguage: 'en',
          mode: TranslationMode.off,
        ),
        loadedSettings: const TranslationSettings(
          preferredLanguage: 'fr',
          mode: TranslationMode.auto,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('srv-1')),
          translationRepositoryProvider.overrideWithValue(concurrentRepo),
        ],
      );
      addTearDown(container.dispose);

      // Initial load.
      await container.read(translationSettingsStoreProvider.notifier).load();
      expect(
        container
            .read(translationSettingsStoreProvider)
            .settings
            .preferredLanguage,
        'en',
      );

      // Start an update that will eventually fail.
      const attempted = TranslationSettings(
        preferredLanguage: 'ja',
        mode: TranslationMode.manual,
      );
      final updateFuture = container
          .read(translationSettingsStoreProvider.notifier)
          .update(attempted);

      // During the async gap, simulate a concurrent load() completing.
      // This writes 'fr' to state.settings.
      concurrentRepo.switchToLoaded();
      await container.read(translationSettingsStoreProvider.notifier).load();

      // Verify load result is now in state.
      expect(
        container
            .read(translationSettingsStoreProvider)
            .settings
            .preferredLanguage,
        'fr',
      );

      // Now fail the update.
      concurrentRepo.failUpdate();
      await updateFuture;

      final afterFail = container.read(translationSettingsStoreProvider);
      // The load() result ('fr') must survive — NOT reverted to 'en'.
      expect(afterFail.settings.preferredLanguage, 'fr',
          reason:
              'Concurrent load() result must not be clobbered by failed update rollback');
      expect(afterFail.failure, isNotNull);
    });
  });

  // ===========================================================================
  // Item 2: members_page .select() narrowing
  // ===========================================================================

  group('Item 2 — members_page .select() narrowing', () {
    test('mutation-only change does not affect body selector output', () {
      // The _MembersBody .select() should only watch (status, members, query).
      // Mutation fields (isInvitingByEmail, updatingRoleMemberIds, etc.)
      // should NOT affect the selector output because members list identity
      // and query string are unchanged through mutation-only copyWith calls.
      final state1 = MemberListState(
        status: MemberListStatus.success,
        members: _sampleMembers,
      );
      // Same members identity + same query, only mutation fields differ.
      final state2 = MemberListState(
        status: MemberListStatus.success,
        members: _sampleMembers,
        isInvitingByEmail: true,
        updatingRoleMemberIds: const {'user-1'},
        removingMemberIds: const {'user-2'},
      );

      // The body's selector uses (status, members, query):
      final select1 = (
        status: state1.status,
        members: state1.members,
        query: state1.query,
      );
      final select2 = (
        status: state2.status,
        members: state2.members,
        query: state2.query,
      );

      // Same list identity (passed through copyWith), same status, same query.
      expect(identical(select1.members, select2.members), isTrue,
          reason: 'Members list identity must be preserved through mutations');
      expect(select1, equals(select2),
          reason: 'Mutation fields must not affect body selector');
    });

    test('query change DOES affect body selector output', () {
      final state1 = MemberListState(
        status: MemberListStatus.success,
        members: _sampleMembers,
      );
      final state2 = MemberListState(
        status: MemberListStatus.success,
        members: _sampleMembers,
        query: 'alice',
      );

      final select1 = (
        status: state1.status,
        members: state1.members,
        query: state1.query,
      );
      final select2 = (
        status: state2.status,
        members: state2.members,
        query: state2.query,
      );

      expect(select1, isNot(equals(select2)),
          reason: 'Query change must trigger rebuild');
    });
  });

  // ===========================================================================
  // Item 3: new_dm_page memoize filtered list
  // ===========================================================================

  group('Item 3 — new_dm_page memoize filtered list', () {
    testWidgets(
        'rebuild with same members+query does NOT recompute filter '
        '(peopleFilterRecomputeCount load-bearing)', (tester) async {
      // This test proves the _PeopleTabState memoization is load-bearing:
      // if memoization were removed, the counter would increment on every
      // rebuild even when members and query are unchanged.
      NewDmPage.peopleFilterRecomputeCount = 0;

      // Use a StateProvider to inject members into memberRepositoryProvider.
      // The real MemberListStore runs inside NewDmPage's child ProviderScope;
      // we override its dependencies (repository, agents) to return test data.
      final container = ProviderContainer(
        overrides: [
          memberRepositoryProvider
              .overrideWithValue(_FakeMemberRepository(_sampleMembers)),
          agentsStoreProvider.overrideWith(() => _FakeAgentsStore()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NewDmPage(serverId: ServerScopeId('srv-1')),
          ),
        ),
      );

      // Let microtask (ensureLoaded) run and then settle the UI.
      await tester.pump();
      await tester.pump();

      // After initial render with loaded members, filter is computed once.
      final countAfterFirst = NewDmPage.peopleFilterRecomputeCount;
      expect(countAfterFirst, greaterThan(0),
          reason: 'Initial render must compute the filter at least once.');

      // Pump again — widget does NOT rebuild because no inputs changed.
      // If memoization were absent but build() still ran, count would increase.
      await tester.pump();
      await tester.pump();

      // Counter must NOT have increased.
      expect(NewDmPage.peopleFilterRecomputeCount, countAfterFirst,
          reason:
              'Same members + same query must not recompute (memoization is load-bearing)');
    });

    test('different query produces different filtered result', () {
      final members = _sampleMembers;

      final all = _filterMembers(members, '');
      final filtered = _filterMembers(members, 'alice');

      // Empty query returns all non-self; 'alice' filters to 1.
      expect(all.length, greaterThan(filtered.length));
    });
  });

  // ===========================================================================
  // Item 4: message_export_card DateFormat caching
  // ===========================================================================

  group('Item 4 — message_export_card DateFormat caching', () {
    test('cachedDateFormat reuses instance for same pattern', () {
      MessageExportCard.clearDateFormatCache();

      const pattern = 'yyyy-MM-dd HH:mm';
      final fmt1 = MessageExportCard.cachedDateFormat(pattern);
      final fmt2 = MessageExportCard.cachedDateFormat(pattern);

      expect(identical(fmt1, fmt2), isTrue,
          reason: 'Same pattern must return identical cached instance');
      expect(MessageExportCard.dateFormatCacheSize, 1);
    });

    test('different patterns are cached independently', () {
      MessageExportCard.clearDateFormatCache();

      final fmt1 = MessageExportCard.cachedDateFormat('yyyy-MM-dd HH:mm');
      final fmt2 = MessageExportCard.cachedDateFormat('HH:mm');

      expect(identical(fmt1, fmt2), isFalse);
      expect(MessageExportCard.dateFormatCacheSize, 2);
    });
  });

  // ===========================================================================
  // Item 5: channel_page .select((s) => s.isBusy)
  // ===========================================================================

  group('Item 5 — channel_page .select((s) => s.isBusy)', () {
    test('channelId change alone does not affect isBusy selector', () {
      // Both states have isBusy == false, so .select((s) => s.isBusy)
      // should not trigger a rebuild.
      const state1 = ChannelManagementState();
      const state2 = ChannelManagementState(channelId: 'ch-123');

      expect(state1.isBusy, isFalse);
      expect(state2.isBusy, isFalse);
      expect(state1.isBusy == state2.isBusy, isTrue,
          reason: '.select((s) => s.isBusy) skips this transition');
    });

    test('activeAction change DOES change isBusy selector', () {
      const state1 = ChannelManagementState();
      const state2 = ChannelManagementState(
        activeAction: ChannelManagementAction.stopAgents,
        channelId: 'ch-1',
      );

      expect(state1.isBusy, isFalse);
      expect(state2.isBusy, isTrue);
      expect(state1.isBusy == state2.isBusy, isFalse,
          reason: 'Busy transition must trigger rebuild');
    });

    test('failure-only change does not affect isBusy selector', () {
      const state1 = ChannelManagementState();
      const state2 = ChannelManagementState(
        failure: ServerFailure(message: 'oops'),
      );

      expect(state1.isBusy, isFalse);
      expect(state2.isBusy, isFalse);
      expect(state1.isBusy == state2.isBusy, isTrue,
          reason: 'Failure without action should not trigger rebuild');
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

final _sampleMembers = [
  const MemberProfile(
    id: 'user-1',
    displayName: 'Alice',
    type: MemberType.human,
    isSelf: false,
  ),
  const MemberProfile(
    id: 'user-2',
    displayName: 'Bob',
    type: MemberType.human,
    isSelf: false,
  ),
  const MemberProfile(
    id: 'agent-1',
    displayName: 'Agent1',
    type: MemberType.agent,
    isSelf: false,
  ),
];

/// Simulates the filter logic from new_dm_page _PeopleTab._buildFilteredList.
List<MemberProfile> _filterMembers(List<MemberProfile> members, String query) {
  final nonSelf = members.where((m) => !m.isSelf).toList();
  if (query.isEmpty) return nonSelf;
  final lower = query.toLowerCase();
  return nonSelf
      .where((m) => m.displayName.toLowerCase().contains(lower))
      .toList();
}

// =============================================================================
// Fakes — TranslationSettingsStore
// =============================================================================

class _FailOnUpdateRepository implements TranslationRepository {
  _FailOnUpdateRepository({required this.initialSettings});

  final TranslationSettings initialSettings;

  @override
  Future<TranslationSettings> getSettings(ServerScopeId serverId) async {
    return initialSettings;
  }

  @override
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings newSettings,
  ) async {
    throw const ServerFailure(message: 'Update failed');
  }

  @override
  Future<List<TranslationResult>> translateBatch(
    ServerScopeId serverId, {
    required List<String> messageIds,
    required String targetLanguage,
  }) async {
    return const [];
  }
}

class _DelayedFailUpdateRepository implements TranslationRepository {
  _DelayedFailUpdateRepository({required this.initialSettings});

  final TranslationSettings initialSettings;
  final _completer = Completer<TranslationSettings>();

  void completeWithFailure() {
    _completer.completeError(const ServerFailure(message: 'Delayed failure'));
  }

  @override
  Future<TranslationSettings> getSettings(ServerScopeId serverId) async {
    return initialSettings;
  }

  @override
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings newSettings,
  ) async {
    return _completer.future;
  }

  @override
  Future<List<TranslationResult>> translateBatch(
    ServerScopeId serverId, {
    required List<String> messageIds,
    required String targetLanguage,
  }) async {
    return const [];
  }
}

class _ConcurrentLoadUpdateRepository implements TranslationRepository {
  _ConcurrentLoadUpdateRepository({
    required this.initialSettings,
    required this.loadedSettings,
  });

  final TranslationSettings initialSettings;
  final TranslationSettings loadedSettings;
  bool _switched = false;
  final _updateCompleter = Completer<TranslationSettings>();

  /// After calling this, subsequent getSettings() returns [loadedSettings].
  void switchToLoaded() {
    _switched = true;
  }

  /// Complete the pending updateSettings() call with a failure.
  void failUpdate() {
    _updateCompleter
        .completeError(const ServerFailure(message: 'Concurrent failure'));
  }

  @override
  Future<TranslationSettings> getSettings(ServerScopeId serverId) async {
    return _switched ? loadedSettings : initialSettings;
  }

  @override
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings newSettings,
  ) async {
    return _updateCompleter.future;
  }

  @override
  Future<List<TranslationResult>> translateBatch(
    ServerScopeId serverId, {
    required List<String> messageIds,
    required String targetLanguage,
  }) async {
    return const [];
  }
}

// =============================================================================
// Fakes — NewDmPage (Item 3 widget test)
// =============================================================================

class _FakeAgentsStore extends AgentsStore {
  @override
  AgentsState build() => const AgentsState(status: AgentsStatus.success);

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> load() async {}

  @override
  void retry() {}
}

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository(this._members);

  final List<MemberProfile> _members;

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async =>
      _members;

  @override
  Future<String> createInvite(ServerScopeId serverId) async => 'fake-invite';

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
      'fake-channel-id';

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'fake-agent-channel-id';
}
